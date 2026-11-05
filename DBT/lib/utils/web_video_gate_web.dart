import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

/// Warm the HTTP cache without opening a decoder.
Future<void> prefetchAsset(String assetPath) async {
  try {
    final url = ui_web.assetManager.getAssetUrl(assetPath);
    await web.window.fetch(url.toJS).toDart;
  } catch (_) {}
}

/// `canplay` (what video_player's initialize() waits for) means "playback can
/// start", which on a slow connection is often the audio ahead of the
/// picture. `canplaythrough` means the browser expects to play the whole
/// clip without a rebuffer stall.
Future<void> waitUntilCanPlayThrough(String fileName) async {
  final element = _element(fileName);
  if (element == null || element.readyState >= 4) return;
  final ready = Completer<void>();
  late final web.EventListener listener;
  listener = ((web.Event _) {
    if (!ready.isCompleted) ready.complete();
  }).toJS;
  element.addEventListener('canplaythrough', listener);
  try {
    await ready.future.timeout(const Duration(seconds: 8));
  } on TimeoutException {
    // Play anyway rather than leaving the owl on a spinner.
  } finally {
    element.removeEventListener('canplaythrough', listener);
  }
}

/// The platform view has no box until Flutter lays it out. Starting playback
/// before that makes the audio audible while the element is still 0×0.
Future<void> waitUntilVisible(String fileName) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (DateTime.now().isBefore(deadline)) {
    final element = _element(fileName);
    if (element != null && element.getBoundingClientRect().width > 2) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 32));
  }
}

Future<void> waitUntilFramePresented(String fileName) async {
  final start = presentedFrameCount(fileName, 0);
  final deadline = DateTime.now().add(const Duration(milliseconds: 800));
  while (DateTime.now().isBefore(deadline)) {
    if (presentedFrameCount(fileName, 0) > start) return;
    await Future<void>.delayed(const Duration(milliseconds: 32));
  }
}

String? claimClipElement(String fileName) {
  final nodes = web.document.querySelectorAll('video');
  web.HTMLVideoElement? match;
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes.item(i);
    if (node == null) continue;
    final element = node as web.HTMLVideoElement;
    final src = element.currentSrc.isNotEmpty ? element.currentSrc : element.src;
    if (!src.contains(fileName)) continue;
    if ((element.getAttribute('data-owl') ?? '').isNotEmpty) continue;
    match = element;
  }
  if (match == null) return null;
  final id = 'owl${DateTime.now().microsecondsSinceEpoch}';
  match.setAttribute('data-owl', id);
  return id;
}

void setOwnedOpacity(String id, double opacity, {bool circular = false}) {
  final element = _byId(id);
  if (element == null) return;
  // A partly transparent <video> is a hole through to the page background.
  // Keep every clip fully opaque and stack them instead.
  element.style.opacity = '1';
  _clipCircle(element, circular);
  final host = element.parentElement;
  if (host != null) {
    (host as web.HTMLElement).style.zIndex = opacity <= 0 ? '1' : '4';
  }
}

void _clipCircle(web.HTMLElement element, bool circular) {
  if (!circular) return;
  element.style.borderRadius = '50%';
  element.style.clipPath = 'circle(50% at 50% 50%)';
}

int ownedFrameCount(String id) {
  final element = _byId(id);
  if (element == null) return 0;
  return _frameCount(element);
}

int presentedFrameCount(String fileName, double mediaSeconds) {
  final element = _element(fileName, mediaSeconds);
  if (element == null) return 0;
  return _frameCount(element);
}

int _frameCount(web.HTMLVideoElement element) {
  final decoded = _decodedFrames(element);
  try {
    final quality = element.getVideoPlaybackQuality();
    final presented = quality.totalVideoFrames - quality.droppedVideoFrames;
    if (presented > decoded) return presented;
  } catch (_) {}
  return decoded;
}

web.HTMLVideoElement? _byId(String id) {
  final nodes = web.document.querySelectorAll('video');
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes.item(i);
    if (node == null) continue;
    final element = node as web.HTMLVideoElement;
    if (element.getAttribute('data-owl') == id) return element;
  }
  return null;
}

int _decodedFrames(web.HTMLVideoElement element) {
  final value = element.getProperty<JSNumber?>('webkitDecodedFrameCount'.toJS);
  if (value == null) return 0;
  final count = value.toDartInt;
  return count < 0 ? 0 : count;
}

web.HTMLCanvasElement? _still;

/// Blend [fromId] into [toId] on a canvas that sits in the exact box of the
/// visible clip. Both frames are drawn with the same object-fit as the video
/// element, so the first and last frame of the blend match the live picture.
/// The videos stay fully opaque underneath; only the canvas fades between them.
Future<void> dissolveUnderStill({
  required String fromId,
  required String toId,
  required Future<void> Function() swapUnderStill,
  bool circular = false,
  int milliseconds = 420,
}) async {
  final from = _byId(fromId);
  final to = _byId(toId);
  if (from == null || to == null) {
    await swapUnderStill();
    return;
  }

  _still?.remove();
  final canvas = web.HTMLCanvasElement();
  final style = canvas.style;
  style.position = 'fixed';
  style.margin = '0';
  style.padding = '0';
  style.border = '0';
  style.pointerEvents = 'none';
  style.zIndex = '2147483646';
  style.opacity = '1';
  style.backgroundColor = 'transparent';
  if (circular) {
    style.borderRadius = '50%';
    style.clipPath = 'circle(50% at 50% 50%)';
  }
  _still = canvas;

  final context = canvas.getContext('2d');
  if (context == null || !context.isA<web.CanvasRenderingContext2D>()) {
    canvas.remove();
    _still = null;
    await swapUnderStill();
    return;
  }
  final ctx = context as web.CanvasRenderingContext2D;
  final started = DateTime.now().millisecondsSinceEpoch;
  double? lockLeft;
  double? lockTop;
  double? lockWidth;
  double? lockHeight;

  void paint(double blend) {
    final live = from.getBoundingClientRect();
    if (lockWidth == null && live.width > 2 && live.height > 2) {
      lockLeft = live.left;
      lockTop = live.top;
      lockWidth = live.width;
      lockHeight = live.height;
    }
    final left = lockLeft;
    final top = lockTop;
    final width = lockWidth;
    final height = lockHeight;
    if (left == null || top == null || width == null || height == null) {
      return;
    }
    final style = canvas.style;
    style.position = 'fixed';
    style.left = '${left}px';
    style.top = '${top}px';
    style.width = '${width}px';
    style.height = '${height}px';
    final scale = web.window.devicePixelRatio;
    final bw = (width * scale).round().clamp(1, 4096);
    final bh = (height * scale).round().clamp(1, 4096);
    if (canvas.width != bw) canvas.width = bw;
    if (canvas.height != bh) canvas.height = bh;
    if (canvas.parentElement != web.document.body) {
      web.document.body!.appendChild(canvas);
    }
    ctx.clearRect(0, 0, bw, bh);
    ctx.globalAlpha = 1;
    _drawContain(ctx, from, bw, bh);
    if (blend > 0 && to.videoWidth > 0) {
      ctx.globalAlpha = blend;
      _drawContain(ctx, to, bw, bh);
      ctx.globalAlpha = 1;
    }
  }

  final done = Completer<void>();
  void tick(JSAny _) {
    final elapsed = DateTime.now().millisecondsSinceEpoch - started;
    final t = (elapsed / milliseconds).clamp(0.0, 1.0);
    final blend = t * t * (3 - 2 * t);
    paint(blend);
    if (t < 1) {
      web.window.requestAnimationFrame(tick.toJS);
    } else if (!done.isCompleted) {
      done.complete();
    }
  }

  paint(0);
  web.window.requestAnimationFrame(tick.toJS);
  await done.future;
  await swapUnderStill();
  await _frame();
  if (identical(_still, canvas)) {
    canvas.remove();
    _still = null;
  }
}

void _drawContain(
  web.CanvasRenderingContext2D ctx,
  web.HTMLVideoElement video,
  int dw,
  int dh,
) {
  final vw = video.videoWidth;
  final vh = video.videoHeight;
  if (vw == 0 || vh == 0 || dw == 0 || dh == 0) return;
  final scale = dw / vw < dh / vh ? dw / vw : dh / vh;
  final w = vw * scale;
  final h = vh * scale;
  final x = (dw - w) / 2;
  final y = (dh - h) / 2;
  ctx.drawImage(video, x, y, w, h);
}

Future<void> _frame() {
  final done = Completer<void>();
  web.window.requestAnimationFrame((JSAny _) {
    if (!done.isCompleted) done.complete();
  }.toJS);
  return done.future;
}

void setClipOpacity(
  String fileName,
  double opacity,
  double mediaSeconds, {
  bool circular = false,
}) {
  final element = _element(fileName, mediaSeconds);
  if (element == null) return;
  element.style.opacity = '1';
  _clipCircle(element, circular);
  final host = element.parentElement;
  if (host != null) {
    (host as web.HTMLElement).style.zIndex = opacity <= 0 ? '1' : '4';
  }
}

web.HTMLVideoElement? _element(String fileName, [double? nearSeconds]) {
  final nodes = web.document.querySelectorAll('video');
  web.HTMLVideoElement? match;
  var bestDelta = double.infinity;
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes.item(i);
    if (node == null) continue;
    final element = node as web.HTMLVideoElement;
    final src = element.currentSrc.isNotEmpty ? element.currentSrc : element.src;
    if (!src.contains(fileName)) continue;
    if (nearSeconds == null) {
      match = element;
      continue;
    }
    final delta = (element.currentTime - nearSeconds).abs();
    if (delta < bestDelta) {
      bestDelta = delta;
      match = element;
    }
  }
  return match;
}
