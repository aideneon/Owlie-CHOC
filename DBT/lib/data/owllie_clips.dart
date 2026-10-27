import 'dart:math';

import '../models/emotion.dart';

/// Bundled Owllie dialogue and idle clips.
///
/// Paths are snake_case on purpose: a space in an asset path is percent-encoded
/// on iOS, and video_player then hangs in initialize().
class OwllieClips {
  OwllieClips._();

  static const whatEmotion =
      'assets/videos/owllie/what_emotion_are_you_feeling.mp4';
  static const gotcha = 'assets/videos/owllie/gotcha_feeling_some_emotions.mp4';
  static const usingASkillCanBeTough =
      'assets/videos/owllie/using_a_skill_can_be_tough.mp4';
  static const emotionWentDown = 'assets/videos/owllie/emotion_went_down.mp4';
  static const emotionSimilar =
      'assets/videos/owllie/emotion_similar_level.mp4';
  static const skillsWerentRightFit =
      'assets/videos/owllie/skills_werent_right_fit.mp4';

  static const ambients = <String>[
    'assets/videos/owllie/ambient/awakening_phoenix.mp4',
    'assets/videos/owllie/ambient/squatting_jumping.mp4',
    'assets/videos/owllie/ambient/restless_wings.mp4',
    'assets/videos/owllie/ambient/looking_around.mp4',
  ];

  static const _exerciseIntros = <EmotionId, List<String>>{
    EmotionId.angry: [
      'assets/videos/owllie/your_feeling_angry.mp4',
      'assets/videos/owllie/practice_angry_skills.mp4',
    ],
    EmotionId.happy: [
      'assets/videos/owllie/your_feeling_happy.mp4',
      'assets/videos/owllie/practice_happy_skills.mp4',
    ],
    EmotionId.scaredAnxious: [
      'assets/videos/owllie/your_feeling_scared.mp4',
      'assets/videos/owllie/practice_scared_skills.mp4',
    ],
    EmotionId.guiltShame: [
      'assets/videos/owllie/your_feeling_guilt.mp4',
      'assets/videos/owllie/practice_guilt_skills.mp4',
    ],
    EmotionId.sad: [
      'assets/videos/owllie/your_feeling_sad.mp4',
      'assets/videos/owllie/practice_sad_skills.mp4',
    ],
    EmotionId.dontKnow: [
      'assets/videos/owllie/your_feeling_dont_know.mp4',
      'assets/videos/owllie/practice_challenging_skills.mp4',
    ],
  };

  static final _random = Random();

  /// Feeling clip, then the matching practice clip.
  static List<String> exerciseIntro(EmotionId id) {
    return List<String>.from(_exerciseIntros[id]!);
  }

  /// Compares a newly chosen intensity band with the one already in effect.
  static String outcomeFor({required int previous, required int next}) {
    if (next < previous) return emotionWentDown;
    if (next > previous) return skillsWerentRightFit;
    return emotionSimilar;
  }

  /// Picks an idle clip. [except] is skipped so a replay does not repeat.
  static String randomAmbient({String? except}) {
    final pool = except == null
        ? ambients
        : ambients.where((path) => path != except).toList();
    final choices = pool.isEmpty ? ambients : pool;
    return choices[_random.nextInt(choices.length)];
  }

  static List<String> get allAssets => <String>[
    whatEmotion,
    gotcha,
    usingASkillCanBeTough,
    emotionWentDown,
    emotionSimilar,
    skillsWerentRightFit,
    for (final clips in _exerciseIntros.values) ...clips,
    ...ambients,
  ];
}
