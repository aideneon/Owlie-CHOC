import 'package:flutter/material.dart';

import '../screens/favorites_screen.dart';
import '../theme/app_theme.dart';
import '../utils/fade_page_route.dart';
import '../utils/media_cache.dart';
import 'owl_placeholder.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    this.title,
    this.titleColor,
  });

  final String? title;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _HeaderButton(
            icon: Icons.home_rounded,
            tooltip: 'Home',
            onTap: () async {
              await VideoCache.pauseAll();
              OwlPlaceholder.requestRestart();
              if (!context.mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: title == null
                  ? const SizedBox.shrink()
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title!,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: titleColor ?? Colors.white,
                            ),
                      ),
                    ),
            ),
          ),
          _HeaderButton(
            icon: Icons.star_rounded,
            tooltip: 'Favorites',
            onTap: () async {
              // Stop any in-flight favorites (or session) playback first.
              await VideoCache.pauseAll();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                FadePageRoute<void>(
                  duration: Duration.zero,
                  builder: (_) => const FavoritesScreen(),
                ),
                (route) => route.isFirst,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: AppTheme.headerIconColor, size: 28),
          ),
        ),
      ),
    );
  }
}
