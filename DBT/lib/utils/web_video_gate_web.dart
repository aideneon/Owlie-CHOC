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

void setOwnedOpacity(String id, double opacity) {
  final element = _byId(id);
  if (element == null) return;
  element.style.opacity = opacity.clamp(0.0, 1.0).toString();
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

void setClipOpacity(String fileName, double opacity, double mediaSeconds) {
  final element = _element(fileName, mediaSeconds);
  if (element == null) return;
  element.style.opacity = opacity.clamp(0.0, 1.0).toString();
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
