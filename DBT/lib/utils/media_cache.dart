import 'dart:async';

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

  static bool get webAudioUnlocked => _webAudioUnlocked;

  static final List<VoidCallback> _unlockListeners = [];

  static void addUnlockListener(VoidCallback listener) {
    _unlockListeners.add(listener);
  }

  static void removeUnlockListener(VoidCallback listener) {
    _unlockListeners.remove(listener);
  }

  static void attach(VideoPlayerController controller) {
    _controllers.add(controller);
  }

  static void detach(VideoPlayerController controller) {
    _controllers.remove(controller);
    _desiredVolume.remove(controller);
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

  static final Map<VideoPlayerController, double> _desiredVolume = {};
  static final Set<VideoPlayerController> _volumeDraining = {};

  /// Queues a mix change so an older [setVolume] cannot finish after a newer
  /// one and leave the clip muted.
  static void requestMixVolume(
    VideoPlayerController controller,
    double weight,
  ) {
    _desiredVolume[controller] = weight;
    if (!_volumeDraining.add(controller)) return;
    unawaited(_drainVolume(controller));
  }

  static Future<void> _drainVolume(VideoPlayerController controller) async {
    try {
      while (_desiredVolume.containsKey(controller)) {
        final target = _desiredVolume.remove(controller)!;
        await setMixVolume(controller, target);
      }
    } finally {
      _volumeDraining.remove(controller);
      if (_desiredVolume.containsKey(controller)) {
        _volumeDraining.add(controller);
        unawaited(_drainVolume(controller));
      }
    }
  }

  /// Applies [weight] as the clip's volume, keeping web playback muted until
  /// the first tap. Toggling mute can pause a clip, so playback is resumed.
  static Future<void> setMixVolume(
    VideoPlayerController controller,
    double weight,
  ) async {
    if (!isUsable(controller)) return;
    final target = _webAudioUnlocked ? weight.clamp(0.0, 1.0) : 0.0;
    final wasPlaying = controller.value.isPlaying;
    try {
      await controller.setVolume(target);
      if (target > 0 &&
          wasPlaying &&
          !controller.value.isCompleted &&
          !controller.value.isPlaying) {
        await playSafely(controller);
      }
    } catch (_) {}
  }

  /// Call from the first pointer event so clips that are already on screen
  /// can play with sound.
  ///
  /// This must not call play() on every attached controller. Speech clips are
  /// opened one at a time and left paused at the first frame; starting all of
  /// them would play hidden audio over the visible animation.
  static Future<void> unlockWebAudio() async {
    if (!kIsWeb || _webAudioUnlocked) return;
    _webAudioUnlocked = true;
    final listeners = List<VoidCallback>.of(_unlockListeners);
    for (final listener in listeners) {
      listener();
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
