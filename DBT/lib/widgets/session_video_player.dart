import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../utils/media_cache.dart';

/// Plays a bundled offline video, then calls [onFinished].
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

class _SessionVideoPlayerState extends State<SessionVideoPlayer> {
  VideoPlayerController? _controller;
  bool _finished = false;
  bool _startedPlaying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final path = widget.assetPath;
    if (path == null || path.isEmpty) {
      setState(() => _error = 'No video for this exercise.');
      return;
    }

    final controller = VideoPlayerController.asset(path);
    _controller = controller;
    VideoCache.attach(controller);

    try {
      await controller.initialize();
      await controller.setLooping(false);
      controller.addListener(_onVideoUpdate);
      if (!mounted || _finished) {
        await _disposeController(controller);
        return;
      }
      setState(() {});
      await VideoCache.playSafely(controller);
      _startedPlaying = true;
    } catch (e) {
      await _disposeController(controller);
      if (_controller == controller) _controller = null;
      if (mounted) {
        setState(() => _error = 'Video unavailable.');
      }
    }
  }

  void _onVideoUpdate() {
    final controller = _controller;
    if (controller == null || _finished) return;
    final value = controller.value;
    if (!value.isInitialized) return;
    if (value.isPlaying) _startedPlaying = true;
    if (_startedPlaying && value.isCompleted) {
      _handleFinished();
    }
  }

  Future<void> _disposeController(VideoPlayerController controller) async {
    controller.removeListener(_onVideoUpdate);
    VideoCache.detach(controller);
    try {
      if (controller.value.isInitialized) {
        await controller.pause();
      }
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
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      // ignore: discarded_futures
      _disposeController(controller);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null &&
        controller.value.isInitialized &&
        _error == null;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final actionReserve = 72.0 + bottomInset;

    return Stack(
      fit: StackFit.expand,
      children: [
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
                    child: ColoredBox(
                      color: Colors.black,
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: VideoPlayer(controller),
                      ),
                    ),
                  );
                },
              ),
            ),
          )
        else
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_error == null)
                  const CircularProgressIndicator(color: Colors.white)
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                    ),
                  ),
              ],
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
