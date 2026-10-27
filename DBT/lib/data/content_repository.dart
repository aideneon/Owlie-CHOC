import 'package:flutter/material.dart';

import '../models/emotion.dart';
import '../models/exercise.dart';
import '../theme/intensity_colors.dart';

/// Central content catalog. Exercise sets are the same for every emotion and
/// differ only by intensity band (see [assets/exercises.txt]).
class ContentRepository {
  ContentRepository._();

  static final exercises = <Exercise>[
    // 9–10
    const Exercise(
      id: 'cold_shock',
      name: 'Cold Shock',
      description:
          '- Help the brain reset: ice pack on face or dunk head in cold water',
      videoAssetPath: 'assets/videos/level_9_10/cold_shock.mp4',
    ),
    const Exercise(
      id: 'burst_of_exercise',
      name: 'Burst of Exercise',
      description: '- One minute to get your heart beating!',
      videoAssetPath: 'assets/videos/level_9_10/burst_of_exercise.mp4',
    ),
    const Exercise(
      id: 'counting_breaths',
      name: 'Counting Breaths',
      description:
          '- Breathing OUT longer than IN helps our brain switch to relax mode ',
      videoAssetPath: 'assets/videos/level_9_10/counting_breaths.mp4',
    ),
    const Exercise(
      id: 'tense_and_release',
      name: 'Tense & Release',
      description:
          '- Squeeze then relax different muscle groups to calm our body',
      videoAssetPath: 'assets/videos/level_9_10/tense_and_release.mp4',
    ),

    // 7–8
    const Exercise(
      id: 'distract_yourself',
      name: 'Distract Yourself',
      description:
          '- Do something that grabs your attention away from stress',
      videoAssetPath: 'assets/videos/level_7_8/distract_yourself.mp4',
    ),
    const Exercise(
      id: 'help_out_someone_else',
      name: 'Help Out Someone Else',
      description:
          '- You’ll focus more on their situation than your own',
      videoAssetPath: 'assets/videos/level_7_8/help_someone_else.mp4',
    ),
    const Exercise(
      id: 'imagine_calm_safe_place',
      name: 'Imagine a Calm or Safe Place',
      description: '- Think of a real or pretend place that feels calm',
      videoAssetPath: 'assets/videos/level_7_8/a_calm_place.mp4',
    ),
    const Exercise(
      id: 'use_your_5_senses',
      name: 'Use Your 5 Senses',
      description:
          '- Comforting (ex: blanket) or intense things (ex: sour candy), or just name objects in the room',
      videoAssetPath: 'assets/videos/level_7_8/5_senses.mp4',
    ),
    const Exercise(
      id: 'one_thing_at_a_time',
      name: 'One Thing at a Time',
      description:
          '- Focus only on what you must do RIGHT NOW, not your whole to-do list',
      videoAssetPath: 'assets/videos/level_7_8/one_thing_at_a_time.mp4',
    ),
    const Exercise(
      id: 'take_a_break_walk_away',
      name: 'Take a Break / Walk Away',
      description:
          '- Step away from the stressful situation for a few minutes',
      videoAssetPath: 'assets/videos/level_7_8/take_a_break.mp4',
    ),

    // 4–6
    const Exercise(
      id: 'check_thoughts_feelings',
      name: 'Check Your Thoughts and Feelings',
      description:
          '- Thoughts and feelings can lie, check to see if they really match the situation',
      videoAssetPath: 'assets/videos/level_4_6/check_your_thoughts.mp4',
    ),
    const Exercise(
      id: 'let_emotions_flow',
      name: 'Let Your Emotions Flow',
      description:
          '- Don’t try to push away or hold onto your emotions, just allow them to be',
      videoAssetPath: 'assets/videos/level_4_6/let_your_emotions_flow.mp4',
    ),
    const Exercise(
      id: 'compare_options',
      name: 'Compare Your Options',
      description:
          '- Consider what will lead to the least trouble, even if it’s not what you feel like doing',
      videoAssetPath: 'assets/videos/level_4_6/compare_your_options.mp4',
    ),
    const Exercise(
      id: 'problem_solve',
      name: 'Problem Solve',
      description:
          '- Brainstorm as many ideas as you can before you try one',
      videoAssetPath: 'assets/videos/level_4_6/try_problem_solving.mp4',
    ),
    const Exercise(
      id: 'recognize_feelings',
      name: 'Recognize Feelings',
      description:
          '- Tell yourself (or someone else) why your (or their) emotions make sense',
      videoAssetPath: 'assets/videos/level_4_6/recognize_your_feelings.mp4',
    ),
    const Exercise(
      id: 'consider_others_pov',
      name: 'Consider Others’ Point of View',
      description:
          '- Imagine what thoughts/feelings are behind someone else’s words/actions',
      videoAssetPath: 'assets/videos/level_4_6/others_point_of_view.mp4',
    ),

    // 1–3
    const Exercise(
      id: 'label_what_you_notice',
      name: 'Label What You Notice',
      description:
          '- Say in your thoughts (or out loud) things you notice inside and out',
      videoAssetPath: 'assets/videos/level_1_3/label_what_you_notice.mp4',
    ),
    const Exercise(
      id: 'get_in_the_zone',
      name: 'Get in the Zone!',
      description: '- Try to fully participate in whatever you are doing',
      videoAssetPath: 'assets/videos/level_1_3/get_in_the_zone.mp4',
    ),
    const Exercise(
      id: 'do_something_fun',
      name: 'Do Something Fun',
      description: '- Build up your tank of wanted emotions',
      videoAssetPath: 'assets/videos/level_1_3/do_something_fun.mp4',
    ),
    const Exercise(
      id: 'take_care_of_your_body',
      name: 'Take Care of Your Body',
      description: '- Make sure you eat and sleep enough to have energy',
      videoAssetPath: 'assets/videos/level_1_3/take_care_of_your_body.mp4',
    ),
  ];

  static final emotions = <Emotion>[
    Emotion(
      id: EmotionId.angry,
      label: 'Angry',
      backgroundColor: const Color(0xFFE53935),
      accentColor: const Color(0xFFFFCDD2),
      icon: Icons.sentiment_very_dissatisfied,
      imageAssetPath: 'assets/images/emotion_angry.png',
      buttonAssetPath: 'assets/images/button_angry.png',
      introVideoAssetPath: 'assets/videos/intro.mp4',
    ),
    Emotion(
      id: EmotionId.happy,
      label: 'Happy',
      backgroundColor: const Color(0xFFFFB300),
      accentColor: const Color(0xFFFFF9C4),
      icon: Icons.sentiment_very_satisfied,
      imageAssetPath: 'assets/images/emotion_happy.png',
      buttonAssetPath: 'assets/images/button_happy.png',
      introVideoAssetPath: 'assets/videos/intro.mp4',
    ),
    Emotion(
      id: EmotionId.scaredAnxious,
      label: 'Scared/Anxious',
      backgroundColor: const Color(0xFF7E57C2),
      accentColor: const Color(0xFFD1C4E9),
      icon: Icons.sentiment_dissatisfied,
      imageAssetPath: 'assets/images/emotion_scared_anxious.png',
      buttonAssetPath: 'assets/images/button_scared_anxious.png',
      introVideoAssetPath: 'assets/videos/intro.mp4',
    ),
    Emotion(
      id: EmotionId.guiltShame,
      label: 'Guilt/Shame',
      backgroundColor: const Color(0xFF6D4C41),
      accentColor: const Color(0xFFD7CCC8),
      icon: Icons.sentiment_neutral,
      imageAssetPath: 'assets/images/emotion_guilt_shame.png',
      buttonAssetPath: 'assets/images/button_guilt_shame.png',
      introVideoAssetPath: 'assets/videos/intro.mp4',
    ),
    Emotion(
      id: EmotionId.sad,
      label: 'Sad',
      backgroundColor: const Color(0xFF42A5F5),
      accentColor: const Color(0xFFBBDEFB),
      icon: Icons.sentiment_dissatisfied_outlined,
      imageAssetPath: 'assets/images/emotion_sad.png',
      buttonAssetPath: 'assets/images/button_sad.png',
      introVideoAssetPath: 'assets/videos/intro.mp4',
    ),
    Emotion(
      id: EmotionId.dontKnow,
      label: "Don't Know",
      backgroundColor: const Color(0xFF78909C),
      accentColor: const Color(0xFFCFD8DC),
      icon: Icons.help_outline,
      imageAssetPath: 'assets/images/emotion_dont_know.png',
      buttonAssetPath: 'assets/images/button_dont_know.png',
      introVideoAssetPath: 'assets/videos/intro.mp4',
    ),
  ];

  static const _exercisesByIntensityBand = <IntensityBand, List<String>>{
    IntensityBand.crisis: [
      'cold_shock',
      'burst_of_exercise',
      'counting_breaths',
      'tense_and_release',
    ],
    IntensityBand.high: [
      'distract_yourself',
      'help_out_someone_else',
      'imagine_calm_safe_place',
      'use_your_5_senses',
      'one_thing_at_a_time',
      'take_a_break_walk_away',
    ],
    IntensityBand.medium: [
      'check_thoughts_feelings',
      'let_emotions_flow',
      'compare_options',
      'problem_solve',
      'recognize_feelings',
      'consider_others_pov',
    ],
    IntensityBand.low: [
      'label_what_you_notice',
      'get_in_the_zone',
      'do_something_fun',
      'take_care_of_your_body',
    ],
  };

  static Emotion emotionById(EmotionId id) {
    return emotions.firstWhere((e) => e.id == id);
  }

  static Exercise exerciseById(String id) {
    return exercises.firstWhere((e) => e.id == id);
  }

  static List<Exercise> exercisesForIntensity(int intensity) {
    final band = IntensityColors.bandForLevel(intensity);
    final ids = _exercisesByIntensityBand[band] ?? [];
    return ids.map(exerciseById).toList();
  }

  /// Same exercise set for every emotion; selection depends on intensity only.
  static List<Exercise> exercisesForEmotionAndIntensity(
    EmotionId emotionId,
    int intensity,
  ) {
    assert(intensity >= 1 && intensity <= 10);
    return exercisesForIntensity(intensity);
  }
}
