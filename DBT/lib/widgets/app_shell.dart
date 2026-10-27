import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_header.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.backgroundColor,
    required this.body,
    this.background,
    this.showBottomControls = false,
    this.bottomControls,
    this.overlayColor,
    this.titleColor,
    this.blurBackground = false,
  });

  final String? title;
  final Color backgroundColor;
  final Widget body;
  final Widget? background;
  final bool showBottomControls;
  final Widget? bottomControls;
  final Color? overlayColor;
  final Color? titleColor;

  /// When true, blurs [background] under the UI. Header controls (Home /
  /// Favorites) stay sharp because they are painted above the blur layer.
  final bool blurBackground;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          background ?? ColoredBox(color: backgroundColor),
          if (blurBackground)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.18),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                AppHeader(title: title, titleColor: titleColor),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      body,
                      if (overlayColor != null)
                        IgnorePointer(
                          child: ColoredBox(color: overlayColor!),
                        ),
                    ],
                  ),
                ),
                if (showBottomControls && bottomControls != null) bottomControls!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color shellBackgroundForHome() => AppTheme.homeBackground;
