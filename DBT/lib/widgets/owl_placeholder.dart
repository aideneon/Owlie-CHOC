import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/owllie_clips.dart';
import '../utils/app_route_observer.dart';
import '../utils/media_cache.dart';

/// Plays [speechAssets] once each, then loops a randomly chosen ambient clip.
///
/// Every clip is initialized up front and stays mounted in an [IndexedStack],
/// so advancing is a texture swap instead of a dispose/create/initialize cycle.
/// That is what keeps the hand-off between clips seamless.
class OwlPlaceholder extends StatefulWidget {
  const OwlPlaceholder({
    super.key,
    required this.speechAssets,
    this.restartWithHome = false,
  });

  final List<String> speechAssets;

  /// Home is the only screen that should rewind when the header Home button
  /// is pressed. Other Owllie players ignore that signal.
  final bool restartWithHome;

  static final ValueNotifier<int> _restartToken = ValueNotifier<int>(0);

  /// Rewind the home Owllie to the first speech clip.
  static void requestRestart() {
    _restartToken.value++;
  }

  @override
  State<OwlPlaceholder> createState() => _OwlPlaceholderState();
}

class _OwlPlaceholderState extends State<OwlPlaceholder> with RouteAware {
  final List<VideoPlayerController?> _controllers = <VideoPlayerController?>[];
  final Map<int, VoidCallback> _listeners = <int, VoidCallback>{};

  late String _ambientPath;

  int _index = 0;
  int _generation = 0;
  bool _advancing = false;
  bool _covered = false;
  bool _pendingRestart = false;
  bool _recovering = false;
  String? _error;

  List<String> get _sequence => <String>[...widget.speechAssets, _ambientPath];

  int get _lastIndex => _sequence.length - 1;

  @override
  void initState() {
    super.initState();
    _ambientPath = OwllieClips.randomAmbient();
    if (widget.restartWithHome) {
      OwlPlaceholder._restartToken.addListener(_onRestartRequested);
    }
    _start();
  }

  @override
  void didUpdateWidget(OwlPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_samePaths(oldWidget.speechAssets, widget.speechAssets)) {
      _rebuildPlayers();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    _covered = true;
    _pauseAll();
  }

  @override
  void didPopNext() {
    _covered = false;
    if (_pendingRestart) {
      _pendingRestart = false;
      _restartFromBeginning();
      return;
    }
    _resumeActive();
  }

  void _onRestartRequested() {
    if (_covered) {
      _pendingRestart = true;
      return;
    }
    _restartFromBeginning();
  }

  Future<void> _start() async {
    final generation = _generation;
    try {
      final first = await _prepare(0, generation);
      if (first == null || !mounted || generation != _generation) return;
      if (!_covered) await VideoCache.playSafely(first);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Owl video unavailable.');
      }
      return;
    }

    for (var i = 1; i < _sequence.length; i++) {
      if (!mounted || generation != _generation) return;
      try {
        await _prepare(i, generation);
      } catch (_) {
        // Retried on demand in _advance if this clip is reached.
      }
    }
  }

  /// Initializes [index] once and leaves it paused on its first frame.
  ///
  /// Returns null when [generation] is no longer current, so a restart cannot
  /// mount a clip that was already being opened.
  Future<VideoPlayerController?> _prepare(int index, int generation) async {
    while (_controllers.length <= index) {
      _controllers.add(null);
    }
    final existing = _controllers[index];
    if (VideoCache.isUsable(existing)) return existing!;
    if (existing != null) {
      await _disposeIndex(index);
    }

    final controller = VideoPlayerController.asset(_sequence[index]);
    try {
      await controller.initialize();
      await controller.setLooping(index == _lastIndex);
      await controller.seekTo(Duration.zero);
    } catch (_) {
      await controller.dispose();
      rethrow;
    }

    if (!mounted || generation != _generation) {
      await controller.dispose();
      return null;
    }

    void listener() => _onUpdate(index);
    _listeners[index] = listener;
    controller.addListener(listener);
    VideoCache.attach(controller);

    setState(() => _controllers[index] = controller);
    return controller;
  }

  void _onUpdate(int index) {
    final controller = index < _controllers.length ? _controllers[index] : null;
    if (index == _index &&
        controller != null &&
        controller.value.hasError &&
        !_covered &&
        !_recovering) {
      _rebuildPlayers();
      return;
    }
    if (index != _index || index == _lastIndex || _advancing) return;
    if (controller == null || !controller.value.isInitialized) return;
    if (!controller.value.isCompleted) return;
    _advance();
  }

  Future<void> _advance() async {
    if (_advancing || _pendingRestart) return;
    _advancing = true;
    final generation = _generation;

    final previous = _index;
    final next = previous + 1;

    try {
      final controller =
          _controllerAt(next) ?? await _prepare(next, generation);
      if (controller == null || !mounted || generation != _generation) return;

      await controller.seekTo(Duration.zero);
      if (!_covered && generation == _generation) {
        await VideoCache.playSafely(controller);
      }
      if (!mounted || generation != _generation) return;
      setState(() => _index = next);

      final finished = _controllerAt(previous);
      if (finished != null) {
        await finished.pause();
        await finished.seekTo(Duration.zero);
      }
    } catch (_) {
      // Stay on the current clip rather than interrupting the sequence.
    } finally {
      if (generation == _generation) _advancing = false;
    }
  }

  Future<void> _restartFromBeginning() async {
    if (!VideoCache.isUsable(_controllerAt(0))) {
      await _rebuildPlayers();
      return;
    }

    final generation = ++_generation;
    _advancing = false;
    _error = null;
    await _pauseAll();
    if (!mounted || generation != _generation) return;

    await _disposeIndex(_lastIndex);
    if (!mounted || generation != _generation) return;
    _ambientPath = OwllieClips.randomAmbient(except: _ambientPath);

    for (var i = 0; i < _lastIndex; i++) {
      final controller = _controllerAt(i);
      if (!VideoCache.isUsable(controller)) continue;
      try {
        await controller!.seekTo(Duration.zero);
      } catch (_) {}
    }
    if (!mounted || generation != _generation) return;

    setState(() => _index = 0);
    final first = _controllerAt(0);
    if (!VideoCache.isUsable(first)) {
      await _rebuildPlayers();
      return;
    }
    if (!_covered) {
      await VideoCache.playSafely(first!);
    }

    for (var i = 1; i < _sequence.length; i++) {
      if (!mounted || generation != _generation) return;
      try {
        await _prepare(i, generation);
      } catch (_) {}
    }
  }

  Future<void> _rebuildPlayers() async {
    if (_recovering) return;
    _recovering = true;
    final generation = ++_generation;
    _advancing = false;
    _pendingRestart = false;
    _ambientPath = OwllieClips.randomAmbient();
    if (mounted) {
      setState(() {
        _error = null;
        _index = 0;
      });
    }
    await _disposePlayers();
    if (!mounted || generation != _generation) {
      _recovering = false;
      return;
    }
    _recovering = false;
    await _start();
  }

  VideoPlayerController? _controllerAt(int index) {
    if (index < 0 || index >= _controllers.length) return null;
    return _controllers[index];
  }

  Future<void> _disposeIndex(int index) async {
    if (index < 0 || index >= _controllers.length) return;
    final controller = _controllers[index];
    if (controller == null) return;
    final listener = _listeners.remove(index);
    if (listener != null) controller.removeListener(listener);
    VideoCache.detach(controller);
    _controllers[index] = null;
    try {
      await controller.dispose();
    } catch (_) {}
  }

  Future<void> _disposePlayers() async {
    for (var i = 0; i < _controllers.length; i++) {
      await _disposeIndex(i);
    }
    _controllers.clear();
    _listeners.clear();
    if (mounted) setState(() {});
  }

  Future<void> _pauseAll() async {
    for (final controller in _controllers) {
      if (controller == null) continue;
      try {
        if (controller.value.isInitialized) {
          await controller.pause();
        }
      } catch (_) {}
    }
  }

  Future<void> _resumeActive() async {
    if (_covered) return;
    final controller = _controllerAt(_index);
    if (!VideoCache.isUsable(controller)) {
      await _rebuildPlayers();
      return;
    }
    if (_index != _lastIndex && controller!.value.isCompleted) return;
    await VideoCache.playSafely(controller!);
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
    if (widget.restartWithHome) {
      OwlPlaceholder._restartToken.removeListener(_onRestartRequested);
    }
    for (var i = 0; i < _controllers.length; i++) {
      final controller = _controllers[i];
      if (controller == null) continue;
      final listener = _listeners[i];
      if (listener != null) controller.removeListener(listener);
      VideoCache.detach(controller);
      // ignore: discarded_futures
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(
            color: Color(0xFF5D4037),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final active = _controllerAt(_index);
    if (!VideoCache.isUsable(active)) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF5D4E37)),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: active!.value.aspectRatio,
        child: IndexedStack(
          index: _index,
          alignment: Alignment.center,
          children: <Widget>[
            for (var i = 0; i < _sequence.length; i++)
              _surfaceFor(i < _controllers.length ? _controllers[i] : null),
          ],
        ),
      ),
    );
  }

  Widget _surfaceFor(VideoPlayerController? controller) {
    if (!VideoCache.isUsable(controller)) {
      return const SizedBox.shrink();
    }
    return VideoPlayer(controller!);
  }
}
