import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'owlie_sequence_player.dart';

/// Companion clips shown above the exercise list.
///
/// Plays each path in [leadAssetPaths] once, then eases into a random idle clip.
/// Speech clips must not loop.
class ExerciseHeaderVideo extends StatelessWidget {
  const ExerciseHeaderVideo({
    super.key,
    required this.leadAssetPaths,
    this.revision = 0,
  });

  final List<String> leadAssetPaths;

  /// Bump to replay [leadAssetPaths] even when the paths themselves did not change.
  final int revision;

  @override
  Widget build(BuildContext context) {
    if (leadAssetPaths.isEmpty) {
      return const Center(
        child: Text(
          'Video unavailable.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF5D4037),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.biggest.shortestSide;
        final diameter = (available - 24).clamp(0.0, double.infinity);
        return Center(
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.homeBackground,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: OwlieSequencePlayer(
                speechAssets: leadAssetPaths,
                replayToken: revision,
                fit: BoxFit.contain,
                circular: true,
              ),
            ),
          ),
        );
      },
    );
  }
}
