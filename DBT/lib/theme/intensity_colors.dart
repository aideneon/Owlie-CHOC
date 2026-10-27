import 'package:flutter/material.dart';

enum IntensityBand {
  low,
  medium,
  high,
  crisis,
}

class IntensityColors {
  static const green = Color(0xFF4CAF50);
  static const yellow = Color(0xFFFFC107);
  static const orange = Color(0xFFFF9800);
  static const red = Color(0xFFE53935);

  static Color forLevel(int level) {
    if (level <= 3) return green;
    if (level <= 6) return yellow;
    if (level <= 8) return orange;
    return red;
  }

  static IntensityBand bandForLevel(int level) {
    if (level <= 3) return IntensityBand.low;
    if (level <= 6) return IntensityBand.medium;
    if (level <= 8) return IntensityBand.high;
    return IntensityBand.crisis;
  }

  static String bandLabel(IntensityBand band) {
    switch (band) {
      case IntensityBand.low:
        return '1 – 3';
      case IntensityBand.medium:
        return '4 – 6';
      case IntensityBand.high:
        return '7 – 8';
      case IntensityBand.crisis:
        return '9 – 10';
    }
  }

  static Color bandColor(IntensityBand band) {
    switch (band) {
      case IntensityBand.low:
        return green;
      case IntensityBand.medium:
        return yellow;
      case IntensityBand.high:
        return orange;
      case IntensityBand.crisis:
        return red;
    }
  }
}
