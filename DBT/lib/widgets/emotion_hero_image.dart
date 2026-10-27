import 'package:flutter/material.dart';

import '../models/emotion.dart';

class EmotionHeroImage extends StatelessWidget {
  const EmotionHeroImage({super.key, required this.emotion});

  final Emotion emotion;

  @override
  Widget build(BuildContext context) {
    if (emotion.imageAssetPath != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: Image.asset(
              emotion.imageAssetPath!,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Container(
        decoration: BoxDecoration(
          color: emotion.accentColor.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white54, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emotion.icon, size: 120, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              emotion.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Image placeholder',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
