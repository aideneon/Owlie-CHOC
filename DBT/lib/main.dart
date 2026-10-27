import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/content_repository.dart';
import 'data/persistence_service.dart';
import 'screens/favorites_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'utils/app_route_observer.dart';
import 'utils/fade_page_route.dart';
import 'utils/media_cache.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DbtApp());
}

class DbtApp extends StatelessWidget {
  const DbtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(PersistenceService())..load(),
      child: MaterialApp(
        title: 'DBT Support',
        theme: AppTheme.build(),
        navigatorObservers: [appRouteObserver],
        builder: _webPhoneSafeArea,
        home: const _AppBootstrap(),
        onGenerateRoute: (settings) {
          if (settings.name == '/favorites') {
            return FadePageRoute<void>(
              settings: settings,
              duration: Duration.zero,
              builder: (_) => const FavoritesScreen(),
            );
          }
          return null;
        },
      ),
    );
  }
}

/// Insets the web demo so header / home-indicator chrome in index.html
/// does not cover tappable UI. Native builds keep the platform safe area.
Widget _webPhoneSafeArea(BuildContext context, Widget? child) {
  Widget content = child ?? const SizedBox.shrink();
  if (!kIsWeb) return content;

  final media = MediaQuery.of(context);
  const islandTop = 54.0;
  const homeIndicator = 22.0;
  return Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) {
      // ignore: discarded_futures
      VideoCache.unlockWebAudio();
    },
    child: MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(
          top: media.padding.top > islandTop ? media.padding.top : islandTop,
          bottom: media.padding.bottom > homeIndicator
              ? media.padding.bottom
              : homeIndicator,
        ),
        viewPadding: media.viewPadding.copyWith(
          top: media.viewPadding.top > islandTop
              ? media.viewPadding.top
              : islandTop,
          bottom: media.viewPadding.bottom > homeIndicator
              ? media.viewPadding.bottom
              : homeIndicator,
        ),
      ),
      child: content,
    ),
  );
}

/// Shows [SplashScreen] until preferences and emotion backgrounds are ready,
/// and the splash has been visible for [SplashScreen.minVisibleDuration].
class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  bool _mediaReady = false;
  bool _started = false;
  bool _minTimeElapsed = false;
  Timer? _minTimeTimer;

  @override
  void initState() {
    super.initState();
    _minTimeTimer = Timer(SplashScreen.minVisibleDuration, () {
      if (mounted) setState(() => _minTimeElapsed = true);
    });
  }

  @override
  void dispose() {
    _minTimeTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _prepareMedia();
  }

  Future<void> _prepareMedia() async {
    try {
      final imageFutures = <Future<void>>[];
      for (final emotion in ContentRepository.emotions) {
        final path = emotion.imageAssetPath;
        if (path == null) continue;
        imageFutures.add(
          precacheImage(emotionBackgroundProvider(context, path), context),
        );
      }
      await Future.wait(imageFutures);
    } catch (_) {
      // Still leave the splash; a missing image should not block the app.
    }

    if (!mounted) return;
    setState(() => _mediaReady = true);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final ready = appState.isLoaded && _mediaReady && _minTimeElapsed;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: ready
          ? const HomeScreen(key: ValueKey<String>('home'))
          : const SplashScreen(key: ValueKey<String>('splash')),
    );
  }
}
