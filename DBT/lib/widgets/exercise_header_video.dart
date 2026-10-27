import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/owllie_clips.dart';
import '../theme/app_theme.dart';
import '../utils/media_cache.dart';

/// Companion clips shown above the exercise list.
///
/// Plays each path in [leadAssetPaths] once, then loops a random ambient clip.
/// Speech clips must not loop.
class ExerciseHeaderVideo extends StatefulWidget {
  const ExerciseHeaderVideo({super.key, required this.leadAssetPaths});

  final List<String> leadAssetPaths;

  /// Scales the clip past the oval so a baked-in circular edge is cropped out.
  static const overscan = 1.12;

  @override
  State<ExerciseHeaderVideo> createState() => _ExerciseHeaderVideoState();
}

class _ExerciseHeaderVideoState extends State<ExerciseHeaderVideo> {
  final Map<int, VoidCallback> _leadListeners = <int, VoidCallback>{};

  List<VideoPlayerController?> _leads = <VideoPlayerController?>[];
  VideoPlayerController? _ambient;
  late String _ambientPath;

  int _leadIndex = 0;
  int _generation = 0;
  bool _showingAmbient = false;
  bool _advancing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ambientPath = OwllieClips.randomAmbient();
    _start();
  }

  @override
  void didUpdateWidget(ExerciseHeaderVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_samePaths(oldWidget.leadAssetPaths, widget.leadAssetPaths)) return;
    _generation++;
    _tearDown();
    _showingAmbient = false;
    _leadIndex = 0;
    _advancing = false;
    _error = null;
    _ambientPath = OwllieClips.randomAmbient(except: _ambientPath);
    _start();
  }

  Future<void> _start() async {
    final generation = _generation;
    final count = widget.leadAssetPaths.length;
    if (count == 0) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Video unavailable.');
      }
      return;
    }

    _leads = List<VideoPlayerController?>.filled(count, null);

    try {
      final lead = await _prepareLead(0);
      if (!mounted || generation != _generation) {
        await _release(lead, 0);
        return;
      }
      setState(() => _leads[0] = lead);
      await VideoCache.playSafely(lead);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Video unavailable.');
      }
      return;
    }

    for (var i = 1; i < count; i++) {
      if (!mounted || generation != _generation) return;
      try {
        await _prepareLead(i);
      } catch (_) {
        // Retried when this clip is reached.
      }
    }

    if (!mounted || generation != _generation) return;
    try {
      final ambient = await _prepareAmbient();
      if (!mounted || generation != _generation) {
        await _release(ambient, null);
        return;
      }
      setState(() => _ambient = ambient);
    } catch (_) {
      // Leads still play; ambient is retried when the last lead finishes.
    }
  }

  Future<VideoPlayerController> _prepareLead(int index) async {
    final existing = index < _leads.length ? _leads[index] : null;
    if (VideoCache.isUsable(existing)) return existing!;
    if (existing != null) await _release(existing, index);

    final controller = await _prepare(
      widget.leadAssetPaths[index],
      looping: false,
    );
    void listener() => _onLeadUpdate(index);
    _leadListeners[index] = listener;
    controller.addListener(listener);
    if (index < _leads.length) _leads[index] = controller;
    return controller;
  }

  Future<VideoPlayerController> _prepareAmbient() async {
    final existing = _ambient;
    if (VideoCache.isUsable(existing)) return existing!;
    if (existing != null) await _release(existing, null);
    final controller = await _prepare(_ambientPath, looping: true);
    _ambient = controller;
    return controller;
  }

  Future<VideoPlayerController> _prepare(
    String assetPath, {
    required bool looping,
  }) async {
    final controller = VideoPlayerController.asset(assetPath);
    try {
      await controller.initialize();
      await controller.setLooping(looping);
      await controller.seekTo(Duration.zero);
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
    VideoCache.attach(controller);
    return controller;
  }

  void _onLeadUpdate(int index) {
    final lead = index < _leads.length ? _leads[index] : null;
    if (lead == null || _showingAmbient || _advancing) return;
    if (index != _leadIndex) return;
    if (!lead.value.isInitialized || !lead.value.isCompleted) return;
    _advance();
  }

  Future<void> _advance() async {
    if (_advancing || _showingAmbient) return;
    _advancing = true;
    final generation = _generation;
    final previous = _leadIndex;

    try {
      final hasAnotherLead = previous + 1 < widget.leadAssetPaths.length;
      if (hasAnotherLead) {
        final next = previous + 1;
        final controller =
            (next < _leads.length ? _leads[next] : null) ??
            await _prepareLead(next);
        if (!mounted || generation != _generation) return;
        await controller.seekTo(Duration.zero);
        await VideoCache.playSafely(controller);
        if (!mounted || generation != _generation) return;
        setState(() => _leadIndex = next);
        await _rewind(_leads[previous]);
      } else {
        final ambient = _ambient ?? await _prepareAmbient();
        if (!mounted || generation != _generation) {
          if (!identical(ambient, _ambient)) await _release(ambient, null);
          return;
        }
        _ambient = ambient;
        await ambient.seekTo(Duration.zero);
        await VideoCache.playSafely(ambient);
        if (!mounted || generation != _generation) return;
        setState(() => _showingAmbient = true);
        await _rewind(previous < _leads.length ? _leads[previous] : null);
      }
    } catch (_) {
      // Stay on the current frame rather than interrupting.
    } finally {
      if (generation == _generation) _advancing = false;
    }
  }

  Future<void> _rewind(VideoPlayerController? controller) async {
    if (controller == null) return;
    try {
      await controller.pause();
      await controller.seekTo(Duration.zero);
    } catch (_) {}
  }

  Future<void> _release(
    VideoPlayerController controller,
    int? leadIndex,
  ) async {
    if (leadIndex != null) {
      final listener = _leadListeners.remove(leadIndex);
      if (listener != null) controller.removeListener(listener);
      if (leadIndex < _leads.length &&
          identical(_leads[leadIndex], controller)) {
        _leads[leadIndex] = null;
      }
    } else if (identical(_ambient, controller)) {
      _ambient = null;
    }
    VideoCache.detach(controller);
    try {
      if (controller.value.isInitialized) await controller.pause();
    } catch (_) {}
    try {
      await controller.dispose();
    } catch (_) {}
  }

  void _tearDown() {
    final leads = List<VideoPlayerController?>.from(_leads);
    final ambient = _ambient;
    _leads = <VideoPlayerController?>[];
    _ambient = null;
    for (var i = 0; i < leads.length; i++) {
      final lead = leads[i];
      if (lead == null) continue;
      // ignore: discarded_futures
      _release(lead, i);
    }
    _leadListeners.clear();
    if (ambient != null) {
      // ignore: discarded_futures
      _release(ambient, null);
    }
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
    _generation++;
    _tearDown();
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

    final active = _showingAmbient ? _ambient : _leadAt(_leadIndex);
    if (active == null || !active.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF5D4E37)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.biggest.shortestSide;
        final diameter = (available - 24).clamp(0.0, double.infinity);
        final stackIndex = _showingAmbient ? _leads.length : _leadIndex;

        return Center(
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.homeBackground,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: Transform.scale(
                scale: ExerciseHeaderVideo.overscan,
                child: IndexedStack(
                  index: stackIndex,
                  sizing: StackFit.expand,
                  alignment: Alignment.center,
                  children: <Widget>[
                    for (final lead in _leads) _surfaceFor(lead),
                    _surfaceFor(_ambient),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  VideoPlayerController? _leadAt(int index) {
    if (index < 0 || index >= _leads.length) return null;
    return _leads[index];
  }

  Widget _surfaceFor(VideoPlayerController? controller) {
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.expand();
    }
    final size = controller.value.size;
    final width = size.width == 0 ? 4.0 : size.width;
    final height = size.height == 0 ? 3.0 : size.height;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: width,
        height: height,
        child: VideoPlayer(controller),
      ),
    );
  }
}
