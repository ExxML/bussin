import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bussin/features/settings/widgets/theme_toggle.dart';
import 'package:bussin/features/settings/widgets/notification_settings.dart';
import 'package:bussin/features/settings/widgets/about_section.dart';
import 'package:bussin/providers/api_key_provider.dart';
import 'package:bussin/providers/google_maps_api_key_provider.dart';

/// ---------------------------------------------------------------------------
/// SettingsScreen - App configuration and information
/// ---------------------------------------------------------------------------
/// Provides grouped settings sections:
///
/// Section 1: API Key
///   - TransLink API key entry/display with save/clear functionality
///   - Shows current key status (set via Settings, compile-time, or not set)
///
/// Section 2: Appearance
///   - ThemeToggle widget (light / dark / system segmented control)
///
/// Section 3: Notifications
///   - NotificationSettings widget (enable/disable + threshold picker)
///
/// Section 4: Data
///   - "Refresh Transit Data" button to re-download GTFS static data
///   - "Last updated" info showing when data was last refreshed
///   - "Clear Cache" button to wipe cached data
///
/// Section 5: About
///   - AboutSection widget (app info, attributions, licenses)
/// ---------------------------------------------------------------------------
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Tracks whether a GTFS data refresh operation is currently in progress.
  /// Used to show a loading indicator and prevent duplicate refresh requests.
  bool _isRefreshing = false;

  /// Placeholder for last data update timestamp.
  /// In production, this would be read from SharedPreferences or a provider.
  String _lastUpdated = 'Never';

  /// Controller for the API key text field in the dialog.
  final TextEditingController _apiKeyController = TextEditingController();

  final TextEditingController _googleMapsApiKeyController =
      TextEditingController();

  @override
  void dispose() {
    _apiKeyController.dispose();
    _googleMapsApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the API key provider to reactively display current key status.
    final apiKeyAsync = ref.watch(apiKeyProvider);
    final googleMapsApiKeyAsync = ref.watch(googleMapsApiKeyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ----- Section 1: API Key -----
            Text(
              'API KEY',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  // Display the current API key status.
                  // Shows a masked version of the key if set, or "Not set" if empty.
                  ListTile(
                    leading: Icon(
                      apiKeyAsync.when(
                        data: (key) => key.isNotEmpty
                            ? Icons.vpn_key
                            : Icons.vpn_key_off,
                        loading: () => Icons.hourglass_empty,
                        error: (_, __) => Icons.error_outline,
                      ),
                      color: apiKeyAsync.when(
                        data: (key) => key.isNotEmpty
                            ? Colors.green
                            : Theme.of(context).colorScheme.error,
                        loading: () => null,
                        error: (_, __) => Theme.of(context).colorScheme.error,
                      ),
                    ),
                    title: const Text('TransLink API Key'),
                    subtitle: apiKeyAsync.when(
                      data: (key) => Text(
                        key.isNotEmpty
                            ? _maskApiKey(key)
                            : 'Not set — tap to enter your key',
                      ),
                      loading: () => const Text('Loading...'),
                      error: (_, __) => const Text('Error loading key'),
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _showApiKeyDialog(context, apiKeyAsync.value),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      googleMapsApiKeyAsync.when(
                        data: (key) =>
                            key.isNotEmpty ? Icons.map : Icons.map_outlined,
                        loading: () => Icons.hourglass_empty,
                        error: (_, __) => Icons.error_outline,
                      ),
                      color: googleMapsApiKeyAsync.when(
                        data: (key) => key.isNotEmpty
                            ? Colors.green
                            : Theme.of(context).colorScheme.error,
                        loading: () => null,
                        error: (_, __) => Theme.of(context).colorScheme.error,
                      ),
                    ),
                    title: const Text('Google Maps API Key'),
                    subtitle: googleMapsApiKeyAsync.when(
                      data: (key) => Text(
                        key.isNotEmpty
                            ? _maskApiKey(key)
                            : 'Not set — tap to enter your key',
                      ),
                      loading: () => const Text('Loading...'),
                      error: (_, __) => const Text('Error loading key'),
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _showGoogleMapsApiKeyDialog(
                      context,
                      googleMapsApiKeyAsync.value,
                    ),
                  ),
                  const Divider(height: 1),
                  // Clear API key button — only enabled when a key is set.
                  ListTile(
                    leading: Icon(
                      Icons.clear,
                      color: apiKeyAsync.when(
                        data: (key) => key.isNotEmpty
                            ? Theme.of(context).colorScheme.error
                            : Colors.grey,
                        loading: () => Colors.grey,
                        error: (_, __) => Colors.grey,
                      ),
                    ),
                    title: Text(
                      'Clear Saved Key',
                      style: TextStyle(
                        color: apiKeyAsync.when(
                          data: (key) => key.isNotEmpty
                              ? Theme.of(context).colorScheme.error
                              : Colors.grey,
                          loading: () => Colors.grey,
                          error: (_, __) => Colors.grey,
                        ),
                      ),
                    ),
                    subtitle: const Text(
                      'Reverts to compile-time key if available',
                    ),
                    onTap: apiKeyAsync.when(
                      data: (key) =>
                          key.isNotEmpty ? () => _confirmClearApiKey(context) : null,
                      loading: () => null,
                      error: (_, __) => null,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.clear,
                      color: googleMapsApiKeyAsync.when(
                        data: (key) => key.isNotEmpty
                            ? Theme.of(context).colorScheme.error
                            : Colors.grey,
                        loading: () => Colors.grey,
                        error: (_, __) => Colors.grey,
                      ),
                    ),
                    title: Text(
                      'Clear Saved Maps Key',
                      style: TextStyle(
                        color: googleMapsApiKeyAsync.when(
                          data: (key) => key.isNotEmpty
                              ? Theme.of(context).colorScheme.error
                              : Colors.grey,
                          loading: () => Colors.grey,
                          error: (_, __) => Colors.grey,
                        ),
                      ),
                    ),
                    subtitle: const Text(
                      'Reverts to compile-time key if available',
                    ),
                    onTap: googleMapsApiKeyAsync.when(
                      data: (key) => key.isNotEmpty
                          ? () => _confirmClearGoogleMapsApiKey(context)
                          : null,
                      loading: () => null,
                      error: (_, __) => null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ----- Section 2: Appearance -----
            Text(
              'APPEARANCE',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            const Card(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: ThemeToggle(),
              ),
            ),
            const SizedBox(height: 16),

            // ----- Section 3: Notifications -----
            Text(
              'NOTIFICATIONS',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            const Card(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: NotificationSettings(),
              ),
            ),
            const SizedBox(height: 16),

            // ----- Section 4: Data -----
            Text(
              'DATA',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.refresh),
                    title: const Text('Refresh Transit Data'),
                    trailing: _isRefreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _isRefreshing ? null : _refreshTransitData,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Last Updated'),
                    trailing: Text(_lastUpdated),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      'Clear Cache',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    onTap: () => _confirmClearCache(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ----- Section 5: About -----
            Text(
              'ABOUT',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            const Card(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: AboutSection(),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showGoogleMapsApiKeyDialog(BuildContext context, String? currentKey) {
    _googleMapsApiKeyController.text = currentKey ?? '';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Google Maps API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Google Maps Platform API key.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _googleMapsApiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.map),
              ),
              autocorrect: false,
              enableSuggestions: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newKey = _googleMapsApiKeyController.text.trim();
              if (newKey.isNotEmpty) {
                ref.read(googleMapsApiKeyProvider.notifier).setApiKey(newKey);
                Navigator.of(dialogContext).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Maps API key saved successfully'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmClearGoogleMapsApiKey(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear Maps API Key'),
        content: const Text(
          'This will remove your saved Maps API key. '
          'The app will revert to the compile-time key if available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(googleMapsApiKeyProvider.notifier).clearApiKey();
              Navigator.of(dialogContext).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Maps API key cleared'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              'Clear',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  /// Masks the API key for display, showing only the first 4 and last 4 characters.
  ///
  /// Example: "iTn4tHRjuXPlukjNbfTK" => "iTn4************bfTK"
  /// This prevents the full key from being visible on screen.
  String _maskApiKey(String key) {
    if (key.length <= 8) return '*' * key.length;
    final prefix = key.substring(0, 4);
    final suffix = key.substring(key.length - 4);
    final masked = '*' * (key.length - 8);
    return '$prefix$masked$suffix';
  }

  /// Shows a dialog where the user can enter or update their TransLink API key.
  ///
  /// Pre-fills the text field with the current key (if any) so the user
  /// can see what's currently set. The key is saved to SharedPreferences
  /// via the [apiKeyProvider] notifier.
  void _showApiKeyDialog(BuildContext context, String? currentKey) {
    // Pre-fill the controller with the current key
    _apiKeyController.text = currentKey ?? '';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('TransLink API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your TransLink Open API key. '
              'You can get one for free at developer.translink.ca.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'e.g. iTn4tHRjuXPlukjNbfTK',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
              // API keys are typically alphanumeric, no need for obscuring
              autocorrect: false,
              enableSuggestions: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newKey = _apiKeyController.text.trim();
              if (newKey.isNotEmpty) {
                // Save the new key via the provider notifier
                ref.read(apiKeyProvider.notifier).setApiKey(newKey);
                Navigator.of(dialogContext).pop();

                // Show a confirmation snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('API key saved successfully'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Shows a confirmation dialog before clearing the saved API key.
  ///
  /// Warns the user that the app will fall back to the compile-time key
  /// (if one was provided via --dart-define), or the app may stop
  /// fetching data if no fallback key exists.
  void _confirmClearApiKey(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear API Key'),
        content: const Text(
          'This will remove your saved API key. '
          'The app will revert to the compile-time key if available, '
          'or API calls will fail until a new key is entered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Clear the saved key via the provider notifier
              ref.read(apiKeyProvider.notifier).clearApiKey();
              Navigator.of(dialogContext).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('API key cleared'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              'Clear',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  /// Simulates refreshing GTFS static transit data.
  ///
  /// In production, this would call the GtfsStaticService to re-download
  /// the GTFS ZIP from TransLink and reload routes/stops/shapes into SQLite.
  /// For now, simulates a network delay and updates the "last updated" text.
  Future<void> _refreshTransitData() async {
    setState(() => _isRefreshing = true);

    // TODO: Call ref.read(gtfsStaticServiceProvider).downloadAndParse()
    // to actually refresh the GTFS data from TransLink's servers.
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isRefreshing = false;
      _lastUpdated = 'Just now';
    });
  }

  /// Shows a confirmation dialog before clearing all cached data.
  ///
  /// Warns the user that this will require re-downloading transit data
  /// on the next app launch, which may use mobile data.
  void _confirmClearCache(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will remove all cached transit data. '
          'The app will need to re-download data on next launch.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              setState(() => _lastUpdated = 'Never');
            },
            child: Text(
              'Clear',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
