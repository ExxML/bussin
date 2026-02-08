import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bussin/core/theme/app_theme.dart';
import 'package:bussin/core/theme/theme_provider.dart';
import 'package:bussin/navigation/app_router.dart';
import 'package:bussin/navigation/bottom_nav_bar.dart';

/// ---------------------------------------------------------------------------
/// BussinApp - Root application widget
/// ---------------------------------------------------------------------------
/// The top-level [ConsumerWidget] that configures the [MaterialApp].
///
/// Responsibilities:
/// - Watches [themeProvider] to apply light/dark theme dynamically
/// - Registers all named routes from [AppRouter]
/// - Sets [MainScaffold] (bottom tab bar with Map/Favorites/Settings) as home
///
/// Uses [MaterialApp] for a consistent Material 3 UI across all screens.
/// ---------------------------------------------------------------------------
class BussinApp extends ConsumerWidget {
  const BussinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the theme brightness to rebuild when user toggles light/dark mode
    final brightness = ref.watch(themeProvider);

    final themeMode = brightness == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light;

    return MaterialApp(
      title: 'bussin!',
      theme: AppTheme.getTheme(Brightness.light),
      darkTheme: AppTheme.getTheme(Brightness.dark),
      themeMode: themeMode,
      routes: AppRouter.routes,
      home: const MainScaffold(),
      debugShowCheckedModeBanner: false,
    );
  }
}
