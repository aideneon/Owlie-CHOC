import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dbt_app/data/content_repository.dart';
import 'package:dbt_app/data/owllie_clips.dart';
import 'package:dbt_app/models/emotion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every exercise has a loadable video asset', () async {
    final problems = <String>[];

    for (final exercise in ContentRepository.exercises) {
      final path = exercise.videoAssetPath;
      if (path == null) {
        problems.add('${exercise.id}: no video linked');
        continue;
      }
      try {
        final data = await rootBundle.load(path);
        if (data.lengthInBytes < 100000) {
          problems.add(
            '${exercise.id}: $path is only ${data.lengthInBytes} bytes',
          );
        }
      } catch (e) {
        problems.add('${exercise.id}: $path failed to load ($e)');
      }
    }

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  // iOS video_player cannot open an asset whose bundled path is
  // percent-encoded: initialize() hangs forever instead of throwing.
  // See https://github.com/flutter/flutter/issues/51031
  test('no video asset path contains whitespace', () {
    final paths = <String>{
      ...ContentRepository.exercises
          .map((e) => e.videoAssetPath)
          .whereType<String>(),
      ...OwllieClips.allAssets,
    };

    final offenders = paths.where((p) => p.contains(' ')).toList();
    expect(
      offenders,
      isEmpty,
      reason:
          'These paths would hang video_player on iOS:\n'
          '${offenders.join('\n')}',
    );
  });

  test('owllie speech and ambient videos are loadable', () async {
    for (final path in OwllieClips.allAssets) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(10000), reason: path);
    }
  });

  test('each emotion plays a feeling clip then a practice clip', () {
    expect(OwllieClips.exerciseIntro(EmotionId.angry), [
      'assets/videos/owllie/your_feeling_angry.mp4',
      'assets/videos/owllie/practice_angry_skills.mp4',
    ]);
    expect(
      OwllieClips.exerciseIntro(EmotionId.dontKnow).last,
      'assets/videos/owllie/practice_challenging_skills.mp4',
    );
    for (final emotion in ContentRepository.emotions) {
      expect(OwllieClips.exerciseIntro(emotion.id), hasLength(2));
    }
  });

  test('outcome clip follows the rating change', () {
    expect(
      OwllieClips.outcomeFor(previous: 7, next: 4),
      OwllieClips.emotionWentDown,
    );
    expect(
      OwllieClips.outcomeFor(previous: 4, next: 4),
      OwllieClips.emotionSimilar,
    );
    expect(
      OwllieClips.outcomeFor(previous: 4, next: 9),
      OwllieClips.skillsWerentRightFit,
    );
  });
}
