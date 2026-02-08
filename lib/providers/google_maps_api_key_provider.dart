import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bussin/core/constants/api_constants.dart';

const String _googleMapsApiKeyPrefKey = 'google_maps_api_key';

final googleMapsApiKeyProvider = AsyncNotifierProvider<GoogleMapsApiKeyNotifier, String>(
  GoogleMapsApiKeyNotifier.new,
);

class GoogleMapsApiKeyNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_googleMapsApiKeyPrefKey);
    if (savedKey != null && savedKey.isNotEmpty) {
      return savedKey;
    }
    return ApiConstants.googleMapsApiKey;
  }

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_googleMapsApiKeyPrefKey, key);
    state = AsyncData(key);
  }

  Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_googleMapsApiKeyPrefKey);
    state = AsyncData(ApiConstants.googleMapsApiKey);
  }
}
