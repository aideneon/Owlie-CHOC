import 'package:flutter/material.dart';

import '../data/content_repository.dart';
import '../data/owllie_clips.dart';
import '../models/emotion.dart';
import '../theme/app_theme.dart';
import '../utils/fade_page_route.dart';
import '../utils/media_cache.dart';
import '../widgets/app_shell.dart';
import '../widgets/emotion_controls.dart';
import '../widgets/owl_placeholder.dart';
import 'session_screen.dart';

class EmotionScreen extends StatefulWidget {
  const EmotionScreen({super.key, required this.emotionId});

  final EmotionId emotionId;

  @override
  State<EmotionScreen> createState() => _EmotionScreenState();
}

class _EmotionScreenState extends State<EmotionScreen> {
  late EmotionId _selectedEmotionId;
  int? _selectedIntensity;

  Emotion get _emotion => ContentRepository.emotionById(_selectedEmotionId);

  @override
  void initState() {
    super.initState();
    _selectedEmotionId = widget.emotionId;
  }

  void _onIntensitySelected(int intensity) {
    setState(() => _selectedIntensity = intensity);
    VideoCache.pauseAll();
    Navigator.of(context).push(
      FadePageRoute<void>(
        duration: Duration.zero,
        builder: (_) =>
            SessionScreen(emotionId: _selectedEmotionId, intensity: intensity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: _emotion.label,
      titleColor: const Color(0xFF424242),
      backgroundColor: AppTheme.homeBackground,
      showBottomControls: true,
      bottomControls: EmotionBottomControls(
        selectedEmotionId: _selectedEmotionId,
        selectedIntensity: _selectedIntensity,
        onEmotionSelected: (emotion) {
          if (emotion.id == _selectedEmotionId) return;
          setState(() {
            _selectedEmotionId = emotion.id;
            _selectedIntensity = null;
          });
        },
        onIntensitySelected: _onIntensitySelected,
      ),
      body: OwlPlaceholder(
        key: ValueKey<EmotionId>(_selectedEmotionId),
        speechAssets: const [OwllieClips.gotcha],
      ),
    );
  }
}
