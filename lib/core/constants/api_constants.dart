/// API constants for TransLink GTFS-RT V3 endpoints and polling configuration.
/// The API key is loaded at compile-time via --dart-define for security.

class ApiConstants {
  ApiConstants._(); // Prevent instantiation

  /// TransLink API key loaded from compile-time --dart-define flag.
  /// Usage: flutter run --dart-define=TRANSLINK_API_KEY=your_key_here
  static const String translinkApiKey =
      String.fromEnvironment('TRANSLINK_API_KEY');

  /// Google Maps API key loaded from compile-time --dart-define flag.
  /// Usage: flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key_here
  static const String googleMapsApiKey =
      String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  /// GTFS-RT V3 endpoint for real-time vehicle positions (protobuf binary).
  static const String gtfsPositionUrl =
      'https://gtfsapi.translink.ca/v3/gtfsposition';

  /// GTFS-RT V3 endpoint for trip updates / ETA predictions (protobuf binary).
  static const String gtfsRealtimeUrl =
      'https://gtfsapi.translink.ca/v3/gtfsrealtime';

  /// GTFS-RT V3 endpoint for service alerts (protobuf binary).
  static const String gtfsAlertsUrl =
      'https://gtfsapi.translink.ca/v3/gtfsalerts';

  /// GTFS Static data download URL (ZIP of CSV files).
  static const String gtfsStaticUrl =
      'https://gtfs-static.translink.ca/gtfs/google_transit.zip';

  /// Polling interval for vehicle position updates (high frequency for live tracking).
  static const Duration vehiclePollInterval = Duration(seconds: 10);

  /// Polling interval for trip update / ETA predictions.
  static const Duration tripUpdatePollInterval = Duration(seconds: 30);

  /// Polling interval for service alert checks.
  static const Duration alertPollInterval = Duration(seconds: 60);

  /// Threshold before re-downloading GTFS static data (schedule updates).
  static const Duration staticRefreshThreshold = Duration(hours: 24);

  /// HTTP request timeout duration.
  static const Duration httpTimeout = Duration(seconds: 15);
}
