import 'package:flutter/material.dart';

/// A fade instead of the platform's default slide-in transition.
/// Pass [duration] as [Duration.zero] for an instant switch.
class FadePageRoute<T> extends PageRouteBuilder<T> {
  FadePageRoute({
    required WidgetBuilder builder,
    super.settings,
    Duration duration = const Duration(milliseconds: 120),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (duration == Duration.zero) return child;
            return FadeTransition(opacity: animation, child: child);
          },
        );
}
