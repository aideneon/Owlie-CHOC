import 'package:flutter/material.dart';

import '../data/content_repository.dart';
import '../models/emotion.dart';
import '../theme/intensity_colors.dart';

class EmotionGrid extends StatelessWidget {
  const EmotionGrid({
    super.key,
    required this.selectedEmotionId,
    required this.onEmotionSelected,
  });

  final EmotionId? selectedEmotionId;
  final ValueChanged<Emotion> onEmotionSelected;

  @override
  Widget build(BuildContext context) {
    final emotions = ContentRepository.emotions;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: emotions.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          final emotion = emotions[index];
          final selected = selectedEmotionId == emotion.id;
          final buttonPath = emotion.buttonAssetPath!;

          return Opacity(
            opacity: selectedEmotionId == null || selected ? 1 : 0.55,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onEmotionSelected(emotion),
                borderRadius: BorderRadius.circular(20),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        offset: const Offset(2, 3),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    buttonPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class EmotionBottomControls extends StatelessWidget {
  const EmotionBottomControls({
    super.key,
    required this.selectedEmotionId,
    required this.selectedIntensity,
    required this.onEmotionSelected,
    required this.onIntensitySelected,
  });

  final EmotionId? selectedEmotionId;
  final int? selectedIntensity;
  final ValueChanged<Emotion> onEmotionSelected;
  final ValueChanged<int> onIntensitySelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EmotionGrid(
          selectedEmotionId: selectedEmotionId,
          onEmotionSelected: onEmotionSelected,
        ),
        IntensityScale(
          selectedIntensity: selectedIntensity,
          onIntensitySelected: onIntensitySelected,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class IntensityScale extends StatelessWidget {
  const IntensityScale({
    super.key,
    required this.selectedIntensity,
    required this.onIntensitySelected,
  });

  final int? selectedIntensity;
  final ValueChanged<int> onIntensitySelected;

  static const _groups = <({List<int> levels, String asset})>[
    (levels: [1, 2, 3], asset: 'assets/images/intensity_123.png'),
    (levels: [4, 5, 6], asset: 'assets/images/intensity_456.png'),
    (levels: [7, 8], asset: 'assets/images/intensity_78.png'),
    (levels: [9, 10], asset: 'assets/images/intensity_910.png'),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedBand = selectedIntensity == null
        ? null
        : IntensityColors.bandForLevel(selectedIntensity!);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var groupIndex = 0; groupIndex < _groups.length; groupIndex++) ...[
            if (groupIndex > 0) const SizedBox(width: 10),
            Expanded(
              flex: _groups[groupIndex].levels.length,
              child: _IntensityGroup(
                key: ValueKey<int>(_groups[groupIndex].levels.first),
                assetPath: _groups[groupIndex].asset,
                dimmed: selectedBand != null &&
                    selectedBand !=
                        IntensityColors.bandForLevel(
                          _groups[groupIndex].levels.first,
                        ),
                onTap: () =>
                    onIntensitySelected(_groups[groupIndex].levels.first),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IntensityGroup extends StatelessWidget {
  const _IntensityGroup({
    super.key,
    required this.assetPath,
    required this.dimmed,
    required this.onTap,
  });

  final String assetPath;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.35 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  offset: const Offset(1.5, 2),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}
