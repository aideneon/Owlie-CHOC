/// How long the next clip fades in over the one already on screen.
///
/// The clip underneath stays fully opaque for this whole interval, so the
/// backdrop never shows through a gap between the two pictures.
const playbackFade = Duration(milliseconds: 420);

/// Start the fade this long before it needs to finish, so the old clip is
/// still showing a real frame when the new one has fully covered it.
const handoffLead = Duration(milliseconds: 180);

/// Media-clock movement that counts as "audio is still going".
const stallAdvance = Duration(milliseconds: 350);

String clipFileName(String assetPath) {
  final slash = assetPath.lastIndexOf('/');
  return slash < 0 ? assetPath : assetPath.substring(slash + 1);
}

/// True when the picture has stopped advancing but playback time has not.
///
/// [presentedFrames] below 0 means this platform cannot report frames, and
/// the caller should not treat that as a freeze.
bool pictureStalled({
  required bool playing,
  required bool seenFrame,
  required int framesBefore,
  required int framesAfter,
  required Duration positionAdvance,
}) {
  if (!playing || !seenFrame || framesBefore < 0) return false;
  if (framesAfter > framesBefore) return false;
  return positionAdvance >= stallAdvance;
}

/// Tracks presented frames across ticks and fires once a freeze is real,
/// not on the first late sample.
class StallWatch {
  bool seenFrame = false;
  int frames = 0;
  Duration anchor = Duration.zero;
  int stuckTicks = 0;
  bool unsupported = false;
  bool fired = false;

  bool sample({
    required bool playing,
    required Duration position,
    required int presentedFrames,
  }) {
    if (fired) return false;
    if (presentedFrames < 0) {
      unsupported = true;
      return false;
    }
    if (!playing) return false;

    if (!seenFrame) {
      if (presentedFrames > 0) {
        seenFrame = true;
        frames = presentedFrames;
        anchor = position;
      } else if (position >= const Duration(milliseconds: 700)) {
        // The clock moved and no frame was ever shown.
        fired = true;
        return true;
      }
      return false;
    }

    if (presentedFrames > frames) {
      frames = presentedFrames;
      anchor = position;
      stuckTicks = 0;
      return false;
    }

    if (position - anchor < stallAdvance) return false;
    stuckTicks++;
    if (stuckTicks < 2) return false;
    fired = true;
    return true;
  }
}
