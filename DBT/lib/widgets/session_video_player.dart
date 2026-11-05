import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/owllie_clips.dart';
import '../theme/app_theme.dart';
import '../utils/media_cache.dart';
import '../utils/playback_sync.dart';
import '../utils/web_video_gate.dart';

/// Plays a bundled exercise clip, then calls [onFinished].
///
/// Sound starts only once a frame is on screen, and the clip fades in. If the
/// picture later freezes while the clock keeps moving, an idle pose covers it
/// and the original audio continues.
class SessionVideoPlayer extends StatefulWidget {
  const SessionVideoPlayer({
    super.key,
    this.assetPath,
    required this.label,
    required this.onFinished,
    this.actionLabel = 'Skip',
    this.actionIcon = Icons.skip_next_rounded,
    this.accentColor = const Color(0xFFCE93D8),
    this.borderRadius = 20,
  });

  final String? assetPath;
  final String label;
  final VoidCallback onFinished;
  final String actionLabel;
  final IconData actionIcon;
  final Color accentColor;
  final double borderRadius;

  @override
  State<SessionVideoPlayer> createState() => _SessionVideoPlayerState();
}

class _SessionVideoPlayerState extends State<SessionVideoPlayer>
    with SingleTickerProviderStateMixin {
  final StallWatch _stall = StallWatch();

  late final AnimationController _fade;
  VideoPlayerController? _controller;
  VideoPlayerController? _idle;
  String? _idlePath;
  bool _finished = false;
  bool _holdingIdle = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: playbackFade)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    VideoCache.addUnlockListener(_onAudioUnlocked);
    unawaited(_initialize());
  }

  void _onAudioUnlocked() {
    final controller = _controller;
    if (!mounted || controller == null || _finished) return;
    if (_holdingIdle) {
      unawaited(VideoCache.setMixVolume(controller, 1));
      final idle = _idle;
      if (idle != null) unawaited(VideoCache.setMixVolume(idle, 0));
      return;
    }
    if (_fade.value > 0) {
      unawaited(VideoCache.setMixVolume(controller, 1));
    }
  }

  Future<void> _initialize() async {
    final path = widget.assetPath;
    if (path == null || path.isEmpty) {
      setState(() => _error = 'No video for this exercise.');
      return;
    }

    unawaited(prefetchAsset(path));
    final controller = VideoPlayerController.asset(path);
    _controller = controller;
    VideoCache.attach(controller);

    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0);
      await controller.seekTo(Duration.zero);
      controller.addListener(_onVideoUpdate);
      if (!mounted || _finished) {
        await _disposeController(controller);
        return;
      }
      setState(() {});
      await WidgetsBinding.instance.endOfFrame;
      final fileName = clipFileName(path);
      await waitUntilCanPlayThrough(fileName);
      await waitUntilVisible(fileName);
      if (!mounted || _finished) return;

      await VideoCache.playSafely(controller);
      await waitUntilFramePresented(fileName);
      if (!mounted || _finished) return;
      try {
        await controller.pause();
        await controller.seekTo(Duration.zero);
      } catch (_) {}

      await controller.play();
      await VideoCache.setMixVolume(controller, 1);
      await _fade.forward(from: 0);
    } catch (_) {
      await _disposeController(controller);
      if (identical(_controller, controller)) _controller = null;
      if (mounted && !_finished) {
        setState(() => _error = 'Video unavailable.');
      }
    }
  }

  void _onVideoUpdate() {
    final controller = _controller;
    if (controller == null || _finished) return;
    final value = controller.value;
    if (!value.isInitialized) return;
    if (_startedAndDone(value)) {
      _handleFinished();
      return;
    }
    if (_holdingIdle || !value.isPlaying) return;
    final frames = presentedFrameCount(
      clipFileName(widget.assetPath ?? ''),
      value.position.inMilliseconds / 1000,
    );
    if (_stall.sample(
      playing: true,
      position: value.position,
      presentedFrames: frames,
    )) {
      unawaited(_holdIdle());
    }
  }

  bool _startedAndDone(VideoPlayerValue value) {
    return value.isCompleted && value.position > Duration.zero;
  }

  Future<void> _holdIdle() async {
    if (_holdingIdle || _finished || !mounted) return;
    _holdingIdle = true;
    final path = OwllieClips.randomAmbient();
    _idlePath = path;
    final idle = VideoPlayerController.asset(path);
    VideoCache.attach(idle);
    try {
      await idle.initialize();
      await idle.setLooping(true);
      await idle.setVolume(0);
      await idle.seekTo(Duration.zero);
      if (!mounted || _finished) {
        await _disposeController(idle);
        return;
      }
      setState(() => _idle = idle);
      _fade.value = 0;
      await VideoCache.playSafely(idle);
      await _fade.forward(from: 0);
    } catch (_) {
      await _disposeController(idle);
      if (identical(_idle, idle)) _idle = null;
    }
  }

  Future<void> _disposeController(VideoPlayerController controller) async {
    controller.removeListener(_onVideoUpdate);
    VideoCache.detach(controller);
    try {
      if (controller.value.isInitialized) await controller.pause();
    } catch (_) {}
    try {
      await controller.dispose();
    } catch (_) {}
  }

  Future<void> _onActionPressed() async {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.pause();
      } catch (_) {}
    }
    _handleFinished();
  }

  void _handleFinished() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    VideoCache.removeUnlockListener(_onAudioUnlocked);
    _fade.dispose();
    final controller = _controller;
    final idle = _idle;
    _controller = null;
    _idle = null;
    if (controller != null) {
      // ignore: discarded_futures
      _disposeController(controller);
    }
    if (idle != null) {
      // ignore: discarded_futures
      _disposeController(idle);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready =
        controller != null && controller.value.isInitialized && _error == null;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final actionReserve = 72.0 + bottomInset;
    final reveal = Curves.easeInOutCubic.transform(_fade.value);
    final exerciseOpacity = _holdingIdle
        ? (1 - reveal).clamp(0.02, 1.0)
        : reveal;
    final idleOpacity = _holdingIdle ? reveal : 0.0;
    if (kIsWeb && ready && widget.assetPath != null) {
      setClipOpacity(
        clipFileName(widget.assetPath!),
        exerciseOpacity,
        controller.value.position.inMilliseconds / 1000,
      );
      final idle = _idle;
      final idlePath = _idlePath;
      if (idle != null && idlePath != null && idle.value.isInitialized) {
        setClipOpacity(
          clipFileName(idlePath),
          idleOpacity,
          idle.value.position.inMilliseconds / 1000,
        );
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppTheme.homeBackground),
        if (ready)
          Positioned.fill(
            bottom: actionReserve,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final aspect = controller.value.aspectRatio == 0
                      ? 9 / 16
                      : controller.value.aspectRatio;
                  var width = constraints.maxWidth;
                  var height = width / aspect;
                  if (height > constraints.maxHeight) {
                    height = constraints.maxHeight;
                    width = height * aspect;
                  }

                  return Center(
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Opacity(
                            opacity: kIsWeb ? 1 : exerciseOpacity,
                            child: VideoPlayer(controller),
                          ),
                          if (_idle != null && _idle!.value.isInitialized)
                            Opacity(
                              opacity: kIsWeb ? 1 : idleOpacity,
                              child: VideoPlayer(_idle!),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          )
        else
          Center(
            child: _error == null
                ? const CircularProgressIndicator(color: Color(0xFF5D4E37))
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF5D4037),
                        fontSize: 16,
                      ),
                    ),
                  ),
          ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16 + bottomInset,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: _onActionPressed,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.actionLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(widget.actionIcon, color: Colors.white, size: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
