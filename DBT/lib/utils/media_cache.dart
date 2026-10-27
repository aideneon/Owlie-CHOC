import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Tracks every on-screen player so Home / Favorites (and route changes)
/// can pause them immediately.
class VideoCache {
  VideoCache._();

  static final Set<VideoPlayerController> _controllers = {};

  /// Browsers only allow unmuted playback after a tap / click. Until then,
  /// web players stay muted so autoplay is allowed.
  static bool _webAudioUnlocked = !kIsWeb;

  static void attach(VideoPlayerController controller) {
    _controllers.add(controller);
  }

  static void detach(VideoPlayerController controller) {
    _controllers.remove(controller);
  }

  static bool isUsable(VideoPlayerController? controller) {
    return controller != null &&
        controller.value.isInitialized &&
        !controller.value.hasError;
  }

  /// Starts playback without letting a web autoplay rejection kill the player.
  ///
  /// On web, `play()` without a user gesture fails for videos with audio. The
  /// video_player plugin then reports that as an error and sets
  /// [VideoPlayerValue.isInitialized] to false, which leaves the UI stuck on
  /// its loading spinner. Muting is allowed by browsers. Do **not** unmute
  /// until [unlockWebAudio] — restoring volume immediately pauses the clip.
  static Future<void> playSafely(VideoPlayerController controller) async {
    if (!isUsable(controller)) return;
    final muteForAutoplay = kIsWeb && !_webAudioUnlocked;
    try {
      if (muteForAutoplay) {
        await controller.setVolume(0);
      }
      await controller.play();
    } catch (_) {
      try {
        await controller.setVolume(0);
        await controller.play();
      } catch (_) {}
    }
  }

  /// Call from the first pointer event so later clips can play with sound.
  static Future<void> unlockWebAudio() async {
    if (!kIsWeb || _webAudioUnlocked) return;
    _webAudioUnlocked = true;
    final snapshot = List<VideoPlayerController>.from(_controllers);
    for (final controller in snapshot) {
      if (!isUsable(controller)) continue;
      try {
        await controller.setVolume(1);
        if (!controller.value.isCompleted && !controller.value.isPlaying) {
          await controller.play();
        }
      } catch (_) {}
    }
  }

  static Future<void> pauseAll() async {
    final snapshot = List<VideoPlayerController>.from(_controllers);
    for (final controller in snapshot) {
      try {
        if (controller.value.isInitialized) {
          await controller.pause();
        }
      } catch (_) {}
    }
  }
}

/// Same pixel size as a full-screen [BoxFit.cover] emotion background.
ImageProvider emotionBackgroundProvider(
  BuildContext context,
  String assetPath,
) {
  final size = MediaQuery.sizeOf(context);
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return ResizeImage(
    AssetImage(assetPath),
    width: (size.width * dpr).round(),
    height: (size.height * dpr).round(),
    policy: ResizeImagePolicy.fit,
    allowUpscaling: false,
  );
}
