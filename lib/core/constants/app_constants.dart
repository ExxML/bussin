/// General application-wide constants for bussin! transit app.
class AppConstants {
  AppConstants._();

  /// Application display name.
  static const String appName = 'bussin!';

  /// Current application version.
  static const String appVersion = '1.0.0';

  /// Required TransLink data attribution text (per Terms of Service).
  /// Must be displayed prominently in the app.
  static const String translinkAttribution =
      'Route and arrival data used in this product or service is provided '
      'by permission of TransLink. TransLink assumes no responsibility for '
      'the accuracy or currency of the Data used in this product or service.';

  /// Maximum number of route history entries stored in SQLite.
  static const int maxHistoryEntries = 50;

  /// Debounce delay for search input to reduce excessive database queries.
  static const int searchDebounceMs = 300;

  /// Maximum number of search results returned per query.
  static const int maxSearchResults = 20;

  /// Duration for smooth bus marker position animation between polling updates.
  static const Duration markerAnimationDuration =
      Duration(milliseconds: 2000);
}
