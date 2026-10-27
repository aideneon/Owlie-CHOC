import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen branded splash shown while the app finishes loading.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const assetPath = 'assets/images/splash.png';
  static const minVisibleDuration = Duration(seconds: 2);
  static const backgroundColor = Color(0xFFC9BBA8);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: const Scaffold(
        backgroundColor: backgroundColor,
        body: SizedBox.expand(
          child: Image(
            image: AssetImage(assetPath),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}
