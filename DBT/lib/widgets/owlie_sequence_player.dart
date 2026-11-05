import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/owllie_clips.dart';
import '../utils/app_route_observer.dart';
import '../utils/media_cache.dart';
import '../utils/playback_sync.dart';
import '../utils/web_video_gate.dart';

/// Plays [speechAssets] one after another, then an idle clip.
///
/// Audio stays silent until the first frame has been presented, then the
/// picture eases in. Later clips crossfade instead of cutting. If the picture
/// stops while the clock keeps moving, a looping idle pose takes over the
/// picture and the original audio is left running underneath.
class OwlieSequencePlayer extends StatefulWidget {
  const OwlieSequencePlayer({
    super.key,
    required this.speechAssets,
    this.replayToken = 0,
    this.deferReplayWhileCovered = false,
    this.fit = BoxFit.contain,
  });

  final List<String> speechAssets;

  /// Bump to crossfade back to the first speech clip.
  final int replayToken;

  /// Home defers that replay until it is the visible route again.
  final bool deferReplayWhileCovered;

  final BoxFit fit;

  @override
  State<OwlieSequencePlayer> createState() => _OwlieSequencePlayerState();
}

class _Slot {
  _Slot(this.controller, this.path);
  final VideoPlayerController controller;
  final String path;
  String? elementId;
  double appliedVolume = -1;
  bool released = false;
  VoidCallback? listener;
}

class _OwlieSequencePlayerState extends State<OwlieSequencePlayer>
    with RouteAware, TickerProviderStateMixin {
  final StallWatch _stall = StallWatch();

  late final AnimationController _fade;
  late String _ambientPath;

  _Slot? _current;
  _Slot? _incoming;
  _Slot? _held;

  int _generation = 0;
  int _index = 0;
  int? _heldSpeechIndex;
  bool _playingAmbient = false;
  bool _transitioning = false;
  bool _keepOutgoingAudio = false;
  bool _silentIncoming = false;
  bool _covered = false;
  bool _pendingReplay = false;
  bool _recovering = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: playbackFade);
    _ambientPath = OwllieClips.randomAmbient();
    VideoCache.addUnlockListener(_onAudioUnlocked);
    _prefetch();
    unawaited(_boot());
  }

  @override
  void didUpdateWidget(OwlieSequencePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pathsChanged = !_samePaths(
      oldWidget.speechAssets,
      widget.speechAssets,
    );
    final tokenChanged = oldWidget.replayToken != widget.replayToken;
    if (!pathsChanged && !tokenChanged) return;
    if (_covered && widget.deferReplayWhileCovered) {
      _pendingReplay = true;
      return;
    }
    unawaited(_restart());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    _covered = true;
    unawaited(_pauseAll());
  }

  @override
  void didPopNext() {
    _covered = false;
    if (_pendingReplay) {
      _pendingReplay = false;
      unawaited(_restart());
      return;
    }
    unawaited(_resume());
  }

  void _onAudioUnlocked() {
    if (!mounted) return;
    for (final slot in <_Slot?>[_current, _incoming, _held]) {
      if (slot == null) continue;
      slot.appliedVolume = -1;
    }
    _applyMix();
  }

  void _prefetch() {
    for (final path in widget.speechAssets) {
      unawaited(prefetchAsset(path));
    }
    unawaited(prefetchAsset(_ambientPath));
  }

  Future<void> _boot() async {
    if (widget.speechAssets.isEmpty) {
      if (mounted) setState(() => _error = 'Owl video unavailable.');
      return;
    }
    await _runFade(widget.speechAssets.first, gen: _generation);
  }

  Future<void> _restart() async {
    final gen = ++_generation;
    _transitioning = false;
    _index = 0;
    _playingAmbient = false;
    _pendingReplay = false;
    _heldSpeechIndex = null;
    _stall.fired = false;
    _stall.seenFrame = false;
    _stall.stuckTicks = 0;
    if (mounted) setState(() => _error = null);

    final orphan = _incoming;
    _incoming = null;
    await _releaseSlot(orphan);
    final held = _held;
    _held = null;
    await _releaseSlot(held);
    if (!mounted || gen != _generation) return;

    _ambientPath = OwllieClips.randomAmbient(except: _ambientPath);
    _prefetch();
    await _runFade(widget.speechAssets.first, gen: gen);
  }

  String _nextPath() {
    if (!_playingAmbient && _index < widget.speechAssets.length - 1) {
      return widget.speechAssets[_index + 1];
    }
    return _ambientPath;
  }

  void _commitArrived(String path) {
    if (path == _ambientPath) {
      _playingAmbient = true;
      return;
    }
    final index = widget.speechAssets.indexOf(path);
    if (index >= 0) _index = index;
    _playingAmbient = false;
  }

  void _onSlotTick(_Slot slot) {
    if (!mounted || slot.released) return;
    final value = slot.controller.value;
    if (slot == _current &&
        value.hasError &&
        !_covered &&
        !_recovering &&
        !_transitioning) {
      _recovering = true;
      unawaited(_restart());
      return;
    }
    if (slot == _held && value.isInitialized && value.isCompleted) {
      unawaited(_finishHold());
      return;
    }
    if (slot != _current || _transitioning || _covered) return;
    if (_watchStall(slot)) return;
    _maybeAdvance(slot);
  }

  bool _watchStall(_Slot slot) {
    if (_held != null || _playingAmbient) return false;
    final value = slot.controller.value;
    if (!value.isInitialized) return false;
    final frames = slot.elementId == null
        ? presentedFrameCount(
            clipFileName(slot.path),
            value.position.inMilliseconds / 1000,
          )
        : ownedFrameCount(slot.elementId!);
    final stalled = _stall.sample(
      playing: value.isPlaying,
      position: value.position,
      presentedFrames: frames,
    );
    if (!stalled) return false;
    unawaited(_holdWithIdle());
    return true;
  }

  void _maybeAdvance(_Slot slot) {
    // A held speech clip keeps its audio under the idle picture. The idle
    // clip itself still has to loop, so only block advance for the speech.
    if (_transitioning || _covered) return;
    if (_held != null && !_playingAmbient) return;
    final value = slot.controller.value;
    if (!value.isInitialized || value.duration == Duration.zero) return;
    final remaining = value.duration - value.position;
    final due =
        value.isCompleted ||
        (value.position > Duration.zero && remaining <= playbackFade);
    if (!due) return;
    _transitioning = true;
    unawaited(_runFade(_nextPath(), gen: _generation, alreadyMarked: true));
  }

  Future<void> _holdWithIdle() async {
    if (_held != null || _transitioning) return;
    _heldSpeechIndex = _index;
    _stall.fired = true;
    await _runFade(
      _ambientPath,
      gen: _generation,
      keepOutgoingAudio: true,
      silentIncoming: true,
    );
  }

  Future<void> _finishHold() async {
    final held = _held;
    final nextIndex = (_heldSpeechIndex ?? _index) + 1;
    _held = null;
    _heldSpeechIndex = null;
    await _releaseSlot(held);
    if (!mounted) return;
    if (nextIndex < widget.speechAssets.length) {
      _playingAmbient = false;
      _stall
        ..fired = false
        ..seenFrame = false
        ..stuckTicks = 0
        ..frames = 0;
      await _runFade(widget.speechAssets[nextIndex], gen: _generation);
      return;
    }
    await _fadeIdleAudioIn();
  }

  Future<void> _fadeIdleAudioIn() async {
    final idle = _current;
    if (idle == null || idle.released) return;
    for (var step = 1; step <= 8; step++) {
      if (!mounted || idle.released) return;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await VideoCache.setMixVolume(idle.controller, step / 8);
      idle.appliedVolume = step / 8;
    }
  }

  Future<void> _runFade(
    String path, {
    required int gen,
    bool keepOutgoingAudio = false,
    bool silentIncoming = false,
    bool alreadyMarked = false,
  }) async {
    if (gen != _generation) return;
    if (_transitioning && !alreadyMarked) return;
    _transitioning = true;
    _Slot? next;
    try {
      if (!mounted || gen != _generation) return;
      next = await _open(path, gen);
      if (next == null || gen != _generation || !mounted) {
        await _releaseSlot(next);
        next = null;
        return;
      }

      setState(() => _incoming = next);
      await WidgetsBinding.instance.endOfFrame;
      if (gen != _generation || !mounted) return;
      next.elementId ??= claimClipElement(clipFileName(path));

      final fileName = clipFileName(path);
      await waitUntilCanPlayThrough(fileName);
      await waitUntilVisible(fileName);
      if (gen != _generation || !mounted) return;

      await _primeFirstFrame(next);
      if (gen != _generation || !mounted) return;

      _keepOutgoingAudio = keepOutgoingAudio;
      _silentIncoming = silentIncoming;
      _fade.removeListener(_applyMix);
      _fade.addListener(_applyMix);
      try {
        await next.controller.play();
        await _fade.forward(from: 0);
      } finally {
        if (gen == _generation) _fade.removeListener(_applyMix);
      }
      if (gen != _generation || !mounted) return;

      final outgoing = _current;
      setState(() {
        _current = next;
        _incoming = null;
      });
      if (keepOutgoingAudio) _heldSpeechIndex = _index;
      _commitArrived(path);
      _stall
        ..fired = false
        ..seenFrame = false
        ..stuckTicks = 0
        ..frames = 0
        ..anchor = Duration.zero;

      if (keepOutgoingAudio && outgoing != null) {
        _held = outgoing;
        outgoing.appliedVolume = -1;
        await VideoCache.setMixVolume(outgoing.controller, 1);
        outgoing.appliedVolume = 1;
      } else {
        await _releaseSlot(outgoing);
      }
      final audible = _held == null ? 1.0 : 0.0;
      next.appliedVolume = audible;
      VideoCache.requestMixVolume(next.controller, audible);
      next = null;
    } catch (_) {
      if (mounted && gen == _generation && _current == null) {
        setState(() => _error = 'Owl video unavailable.');
      }
    } finally {
      if (gen == _generation) _transitioning = false;
      if (next != null &&
          next != _current &&
          next != _incoming &&
          next != _held) {
        await _releaseSlot(next);
      }
    }
  }

  Future<_Slot?> _open(String path, int gen) async {
    final controller = VideoPlayerController.asset(path);
    VideoCache.attach(controller);
    try {
      await controller.initialize();
      if (!mounted || gen != _generation) {
        await _drop(controller);
        return null;
      }
      await controller.setLooping(false);
      await controller.setVolume(0);
      await controller.seekTo(Duration.zero);
    } catch (_) {
      await _drop(controller);
      rethrow;
    }

    final slot = _Slot(controller, path);
    void listener() => _onSlotTick(slot);
    slot.listener = listener;
    controller.addListener(listener);
    return slot;
  }

  /// Decode the first frame while silent, then rewind so audible playback
  /// and the fade start on that same frame.
  Future<void> _primeFirstFrame(_Slot slot) async {
    await slot.controller.setVolume(0);
    slot.appliedVolume = 0;
    await VideoCache.playSafely(slot.controller);
    await waitUntilFramePresented(clipFileName(slot.path));
    if (!mounted || slot.released) return;
    try {
      await slot.controller.pause();
      await slot.controller.seekTo(Duration.zero);
    } catch (_) {}
  }

  void _applyMix() {
    if (!mounted) return;
    final fading = _incoming != null;
    final t = fading ? Curves.easeInOutCubic.transform(_fade.value) : 1.0;
    final currentWeight = !fading
        ? (_held != null ? 0.0 : 1.0)
        : (_keepOutgoingAudio ? 1.0 : (1 - t));
    final incomingWeight = !fading || _silentIncoming ? 0.0 : t;
    _setVol(_current, currentWeight);
    _setVol(_incoming, incomingWeight);
    _setVol(_held, _held == null ? 0 : 1);
    setState(() {});
  }

  void _setVol(_Slot? slot, double weight) {
    if (slot == null || slot.released) return;
    if ((slot.appliedVolume - weight).abs() < 0.04) return;
    slot.appliedVolume = weight;
    VideoCache.requestMixVolume(slot.controller, weight);
  }

  Future<void> _pauseAll() async {
    for (final slot in <_Slot?>[_current, _incoming, _held]) {
      final controller = slot?.controller;
      if (controller == null || slot!.released) continue;
      try {
        if (controller.value.isInitialized) await controller.pause();
      } catch (_) {}
    }
  }

  Future<void> _resume() async {
    if (_covered) return;
    final current = _current;
    if (current != null &&
        !current.released &&
        !current.controller.value.isCompleted) {
      await VideoCache.playSafely(current.controller);
    }
    final held = _held;
    if (held != null && !held.released && !held.controller.value.isCompleted) {
      await VideoCache.playSafely(held.controller);
    }
    _applyMix();
  }

  Future<void> _releaseSlot(_Slot? slot) async {
    if (slot == null || slot.released) return;
    slot.released = true;
    final elementId = slot.elementId;
    if (elementId != null) setOwnedOpacity(elementId, 0);
    if (identical(_current, slot)) _current = null;
    if (identical(_incoming, slot)) _incoming = null;
    if (identical(_held, slot)) _held = null;
    final listener = slot.listener;
    if (listener != null) slot.controller.removeListener(listener);
    await _drop(slot.controller);
  }

  Future<void> _drop(VideoPlayerController controller) async {
    VideoCache.detach(controller);
    try {
      if (controller.value.isInitialized) await controller.pause();
    } catch (_) {}
    try {
      await controller.dispose();
    } catch (_) {}
  }

  bool _samePaths(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    VideoCache.removeUnlockListener(_onAudioUnlocked);
    _generation++;
    _fade.dispose();
    for (final slot in <_Slot?>[_current, _incoming, _held]) {
      if (slot == null || slot.released) continue;
      slot.released = true;
      final listener = slot.listener;
      if (listener != null) slot.controller.removeListener(listener);
      VideoCache.detach(slot.controller);
      // ignore: discarded_futures
      slot.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF5D4037),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final picture = _current ?? _incoming;
    if (picture == null || !picture.controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF5D4E37)),
      );
    }

    final fading = _incoming != null;
    final t = fading ? Curves.easeInOutCubic.transform(_fade.value) : 1.0;
    final currentOpacity = fading ? (1 - t) : 1.0;
    final incomingOpacity = fading ? t : 0.0;

    Widget layer(_Slot slot, double opacity) {
      final shown = identical(slot, _held) ? 0.02 : opacity.clamp(0.0, 1.0);
      // The platform view is created a frame after the widget, so claim is
      // retried until the element exists. Each clip gets its own id so a
      // same-file crossfade (idle looping) does not restyle the wrong video.
      slot.elementId ??= claimClipElement(clipFileName(slot.path));
      final elementId = slot.elementId;
      if (elementId != null) {
        setOwnedOpacity(elementId, shown);
      } else {
        final seconds = slot.controller.value.isInitialized
            ? slot.controller.value.position.inMilliseconds / 1000
            : 0.0;
        setClipOpacity(clipFileName(slot.path), shown, seconds);
      }
      if (kIsWeb) return _surface(slot);
      return Opacity(opacity: shown, child: _surface(slot));
    }

    final stack = Stack(
      fit: StackFit.expand,
      children: [
        if (_held != null) layer(_held!, 0.02),
        if (_current != null) layer(_current!, currentOpacity),
        if (_incoming != null) layer(_incoming!, incomingOpacity),
      ],
    );

    if (widget.fit == BoxFit.cover) {
      return stack;
    }

    final ratio = picture.controller.value.aspectRatio == 0
        ? 1.0
        : picture.controller.value.aspectRatio;
    return Center(
      child: AspectRatio(aspectRatio: ratio, child: stack),
    );
  }

  Widget _surface(_Slot slot) {
    final controller = slot.controller;
    if (!controller.value.isInitialized) return const SizedBox.expand();
    if (widget.fit != BoxFit.cover) return VideoPlayer(controller);
    final size = controller.value.size;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.width == 0 ? 4 : size.width,
        height: size.height == 0 ? 3 : size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}
