import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bussin/providers/gtfs_data_init_provider.dart';
import 'package:bussin/navigation/bottom_nav_bar.dart';

/// ---------------------------------------------------------------------------
/// GtfsLoadingScreen
/// ---------------------------------------------------------------------------
/// Shown at app startup while GTFS static data is being downloaded,
/// parsed, and imported into the local SQLite database.
///
/// Watches [gtfsDataInitProvider] and triggers [initialize] on first build.
///   - Loading/in-progress: shows activity indicator + progress message
///   - Complete: renders the main app scaffold (bottom nav bar)
///   - Error: shows error message with a retry button
/// ---------------------------------------------------------------------------
class GtfsLoadingScreen extends ConsumerStatefulWidget {
  const GtfsLoadingScreen({super.key});

  @override
  ConsumerState<GtfsLoadingScreen> createState() => _GtfsLoadingScreenState();
}

class _GtfsLoadingScreenState extends ConsumerState<GtfsLoadingScreen> {
  bool _initCalled = false;

  @override
  void initState() {
    super.initState();
    // Kick off initialization after the first frame so the notifier
    // is fully built before we start mutating its state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initCalled) {
        _initCalled = true;
        ref.read(gtfsDataInitProvider.notifier).initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(gtfsDataInitProvider);

    if (status.isComplete) {
      return const MainScaffold();
    }

    if (status.hasError) {
      return _buildErrorScreen(context, status);
    }

    return _buildLoadingScreen(context, status);
  }

  /// Loading screen with activity indicator and progress text.
  Widget _buildLoadingScreen(BuildContext context, GtfsInitStatus status) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // -- App icon / branding area --
              const Icon(
                Icons.directions_bus_rounded,
                size: 64.0,
                color: Color(0xFF0060A9), // TransLink blue
              ),
              const SizedBox(height: 24.0),

              const Text(
                'Bussin!',
                style: TextStyle(
                  fontSize: 28.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32.0),

              // -- Activity indicator --
              const CupertinoActivityIndicator(radius: 16.0),
              const SizedBox(height: 20.0),

              // -- Progress message --
              Text(
                status.message,
                style: TextStyle(
                  fontSize: 15.0,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16.0),

              // -- Progress bar --
              SizedBox(
                width: 200.0,
                child: LinearProgressIndicator(
                  value: status.progress,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.1),
                  color: const Color(0xFF0060A9),
                  minHeight: 4.0,
                ),
              ),
              const SizedBox(height: 32.0),

              // -- First-launch hint --
              Text(
                'First launch may take a minute to\ndownload transit data.',
                style: TextStyle(
                  fontSize: 12.0,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.4),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Error screen with retry button.
  Widget _buildErrorScreen(
    BuildContext context,
    GtfsInitStatus status,
  ) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 64.0,
                color: CupertinoColors.systemRed,
              ),
              const SizedBox(height: 24.0),

              const Text(
                'Failed to Load Data',
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12.0),

              Text(
                status.message,
                style: TextStyle(
                  fontSize: 14.0,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8.0),

              // Show the actual error for debugging
              if (status.error != null)
                Text(
                  status.error.toString(),
                  style: const TextStyle(
                    fontSize: 11.0,
                    color: CupertinoColors.systemGrey,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 24.0),

              // -- Retry button --
              FilledButton.icon(
                onPressed: () {
                  ref.read(gtfsDataInitProvider.notifier).initialize();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0060A9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
