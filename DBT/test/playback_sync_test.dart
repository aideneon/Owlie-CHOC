import 'package:flutter_test/flutter_test.dart';

import 'package:dbt_app/utils/playback_sync.dart';

void main() {
  test('a moving clock with a stuck picture is a stall', () {
    expect(
      pictureStalled(
        playing: true,
        seenFrame: true,
        framesBefore: 12,
        framesAfter: 12,
        positionAdvance: const Duration(milliseconds: 400),
      ),
      isTrue,
    );
  });

  test('frames that keep arriving are not a stall', () {
    expect(
      pictureStalled(
        playing: true,
        seenFrame: true,
        framesBefore: 12,
        framesAfter: 20,
        positionAdvance: const Duration(milliseconds: 400),
      ),
      isFalse,
    );
  });

  test('a platform that cannot report frames is not treated as frozen', () {
    expect(
      pictureStalled(
        playing: true,
        seenFrame: true,
        framesBefore: -1,
        framesAfter: -1,
        positionAdvance: const Duration(seconds: 2),
      ),
      isFalse,
    );
  });

  test('stall watch waits for a second stuck sample', () {
    final watch = StallWatch();
    expect(
      watch.sample(
        playing: true,
        position: const Duration(milliseconds: 400),
        presentedFrames: 4,
      ),
      isFalse,
    );
    expect(
      watch.sample(
        playing: true,
        position: const Duration(milliseconds: 800),
        presentedFrames: 4,
      ),
      isFalse,
    );
    expect(
      watch.sample(
        playing: true,
        position: const Duration(milliseconds: 1200),
        presentedFrames: 4,
      ),
      isTrue,
    );
  });

  test('no presented frame after the clock has moved is a stall', () {
    final watch = StallWatch();
    expect(
      watch.sample(
        playing: true,
        position: const Duration(milliseconds: 700),
        presentedFrames: 0,
      ),
      isTrue,
    );
  });
}
