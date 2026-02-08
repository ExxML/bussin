import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bussin/core/constants/api_constants.dart';

/// ---------------------------------------------------------------------------
/// API Key Provider
/// ---------------------------------------------------------------------------
/// Manages the TransLink API key with runtime mutability.
///
/// Priority order for the API key:
///   1. User-entered key saved in SharedPreferences (highest priority)
///   2. Compile-time key from --dart-define=TRANSLINK_API_KEY=... (fallback)
///   3. Empty string if neither is set (will cause 403 errors)
///
/// The provider loads the saved key on initialization and exposes methods
/// to set/clear the key at runtime from the Settings screen.
///
/// When the API key changes, all providers that depend on
/// [translinkApiServiceProvider] will automatically rebuild because the
/// service is recreated with the new key.
/// ---------------------------------------------------------------------------

/// SharedPreferences key used to persist the user-entered API key.
const String _apiKeyPrefKey = 'translink_api_key';

/// Provides the current TransLink API key as an [AsyncNotifier].
///
/// Widgets and other providers watch this to get the active API key.
/// The [TranslinkApiService] reads from this provider so that changing
/// the key in Settings immediately takes effect on the next API call.
final apiKeyProvider = AsyncNotifierProvider<ApiKeyNotifier, String>(
  ApiKeyNotifier.new,
);

/// Notifier that manages the TransLink API key with SharedPreferences persistence.
///
/// On [build], loads any saved key from SharedPreferences. If none is saved,
/// falls back to the compile-time key from `--dart-define`.
///
/// [setApiKey] saves a new key to SharedPreferences and updates the state.
/// [clearApiKey] removes the saved key and reverts to the compile-time fallback.
class ApiKeyNotifier extends AsyncNotifier<String> {
  /// Loads the API key from SharedPreferences on first access.
  ///
  /// Falls back to the compile-time constant if no key has been saved
  /// by the user via the Settings screen.
  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_apiKeyPrefKey);

    // If the user has previously saved a key, use it.
    // Otherwise fall back to the compile-time --dart-define value.
    if (savedKey != null && savedKey.isNotEmpty) {
      return savedKey;
    }
    return ApiConstants.translinkApiKey;
  }

  /// Saves a new API key to SharedPreferences and updates the provider state.
  ///
  /// This causes all providers watching [apiKeyProvider] to rebuild,
  /// which in turn recreates the [TranslinkApiService] with the new key
  /// and triggers fresh API calls.
  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPrefKey, key);

    // Update the in-memory state so watchers rebuild immediately
    state = AsyncData(key);
  }

  /// Removes the saved API key from SharedPreferences and reverts to
  /// the compile-time fallback.
  ///
  /// Useful if the user wants to go back to using the key provided
  /// at build time via `--dart-define`.
  Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyPrefKey);

    // Revert to the compile-time key
    state = AsyncData(ApiConstants.translinkApiKey);
  }
}
