import 'package:flutter/material.dart';

enum EmotionId {
  angry,
  happy,
  scaredAnxious,
  guiltShame,
  sad,
  dontKnow,
}

class Emotion {
  const Emotion({
    required this.id,
    required this.label,
    required this.backgroundColor,
    required this.accentColor,
    required this.icon,
    this.imageAssetPath,
    this.buttonAssetPath,
    this.introVideoAssetPath,
  });

  final EmotionId id;
  final String label;
  final Color backgroundColor;
  final Color accentColor;
  final IconData icon;
  final String? imageAssetPath;
  final String? buttonAssetPath;
  final String? introVideoAssetPath;
}
