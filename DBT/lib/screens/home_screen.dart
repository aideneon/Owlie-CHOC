import 'package:flutter/material.dart';

import '../data/owllie_clips.dart';
import '../theme/app_theme.dart';
import '../utils/fade_page_route.dart';
import '../utils/media_cache.dart';
import '../widgets/app_shell.dart';
import '../widgets/emotion_controls.dart';
import '../widgets/owl_placeholder.dart';
import 'emotion_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Dialectical Behavioral Therapy',
      titleColor: const Color(0xFF424242),
      backgroundColor: AppTheme.homeBackground,
      showBottomControls: true,
      bottomControls: EmotionBottomControls(
        selectedEmotionId: null,
        selectedIntensity: null,
        onEmotionSelected: (emotion) async {
          await VideoCache.pauseAll();
          if (!context.mounted) return;
          Navigator.of(context).push(
            FadePageRoute<void>(
              duration: Duration.zero,
              builder: (_) => EmotionScreen(emotionId: emotion.id),
            ),
          );
        },
        onIntensitySelected: (_) {},
      ),
      body: const OwlPlaceholder(
        speechAssets: [OwllieClips.whatEmotion],
        restartWithHome: true,
      ),
    );
  }
}
