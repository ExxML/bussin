# bussin! - Architecture Document

## Overview

**bussin!** is a real-time Vancouver bus tracking app built with Flutter. It displays live bus positions on an OpenStreetMap-based map, provides ETA predictions, service alerts, and allows users to search by route or stop number. Data comes from TransLink's GTFS-RT V3 API (Protocol Buffer format) and GTFS Static data.

- **Platforms:** Android and iOS
- **State Management:** Riverpod v3 (with code generation)
- **Map:** flutter_map (OpenStreetMap tiles, no API key required)
- **Local Storage:** SQLite via sqflite
- **UI Style:** Cupertino (iOS-style) with dark/light theme support
- **Real-time Data Format:** Protocol Buffers (binary, not JSON)

---

## Tech Stack and Package Versions

### Dependencies

| Package | Version | Purpose |
|---|---|---|
| `flutter` | `>=3.24.0` | Framework |
| `flutter_riverpod` | `^2.6.1` | State management |
| `riverpod_annotation` | `^2.6.1` | Code generation for providers |
| `flutter_map` | `^7.0.2` | OpenStreetMap map widget |
| `latlong2` | `^0.9.1` | Lat/lng coordinate handling |
| `geolocator` | `^13.0.2` | Device GPS location |
| `protobuf` | `^3.1.0` | Parse GTFS-RT protobuf feeds |
| `http` | `^1.2.2` | HTTP requests to TransLink API |
| `sqflite` | `^2.4.1` | Local SQLite database |
| `path_provider` | `^2.1.5` | File system paths |
| `archive` | `^4.0.2` | Unzip GTFS static data |
| `csv` | `^6.0.0` | Parse GTFS CSV files |
| `flutter_local_notifications` | `^18.0.1` | Bus arrival notifications |
| `shared_preferences` | `^2.3.4` | Simple key-value storage (settings) |
| `freezed_annotation` | `^2.4.6` | Immutable data models |
| `json_annotation` | `^4.9.0` | JSON serialization |
| `cupertino_icons` | `^1.0.8` | iOS-style icons |
| `flutter_map_animations` | `^0.8.1` | Animated map camera movement |
| `url_launcher` | `^6.3.1` | Open external links |
| `permission_handler` | `^11.3.1` | Runtime permission requests |
| `connectivity_plus` | `^6.1.1` | Network connectivity check |
| `intl` | `^0.19.0` | Date/time formatting |

### Dev Dependencies

| Package | Version | Purpose |
|---|---|---|
| `build_runner` | `^2.4.13` | Code generation runner |
| `riverpod_generator` | `^2.6.3` | Generate Riverpod providers |
| `freezed` | `^2.5.7` | Generate immutable models |
| `json_serializable` | `^6.8.0` | Generate JSON serialization |
| `flutter_test` | sdk | Testing |
| `flutter_lints` | `^5.0.0` | Lint rules |
| `mockito` | `^5.4.4` | Mocking for tests |

---

## API Endpoints

### TransLink GTFS-RT V3 (Protobuf binary responses)

All three endpoints return Protocol Buffer binary data. You must parse them with the generated `FeedMessage.fromBuffer(bytes)` method, not as JSON.

| Endpoint | URL | Data |
|---|---|---|
| Vehicle Positions | `https://gtfsapi.translink.ca/v3/gtfsposition?apikey={API_KEY}` | Real-time lat/lng, bearing, speed of all active vehicles |
| Trip Updates | `https://gtfsapi.translink.ca/v3/gtfsrealtime?apikey={API_KEY}` | Arrival/departure predictions, delays per stop |
| Service Alerts | `https://gtfsapi.translink.ca/v3/gtfsalerts?apikey={API_KEY}` | Disruptions, detours, cancellations |

### TransLink GTFS Static (ZIP of CSV files)

| URL | Contents |
|---|---|
| `https://gtfs-static.translink.ca/gtfs/google_transit.zip` | routes.txt, stops.txt, trips.txt, stop_times.txt, shapes.txt, calendar.txt, calendar_dates.txt |

### Polling Intervals

| Feed | Interval | Rationale |
|---|---|---|
| Vehicle positions | 10 seconds | Core feature, needs high frequency |
| Trip updates / ETAs | 30 seconds | Predictions change less rapidly |
| Service alerts | 60 seconds | Alerts change infrequently |
| GTFS static data | On launch if >24h stale | Schedule changes are weekly at most |
| GPS location | Continuous stream | User location needs to be live |

---

## Project Structure

```
bussin/
├── android/                          # Android platform files
├── ios/                              # iOS platform files
├── assets/
│   ├── icons/
│   │   ├── bus_marker.png            # Custom bus icon for map markers (40x40px)
│   │   ├── bus_marker_selected.png   # Highlighted bus marker (48x48px)
│   │   └── app_icon.png              # App launcher icon (1024x1024px)
│   └── fonts/                        # Custom fonts (if any)
├── lib/
│   ├── main.dart                     # App entry point
│   ├── app.dart                      # Root widget (CupertinoApp + ProviderScope)
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   ├── api_constants.dart    # API URLs, keys, poll intervals
│   │   │   ├── map_constants.dart    # Vancouver center, zoom levels, tile URL
│   │   │   └── app_constants.dart    # App name, version, theme values
│   │   ├── theme/
│   │   │   ├── app_theme.dart        # CupertinoThemeData for light and dark
│   │   │   └── theme_provider.dart   # Riverpod provider for theme mode
│   │   ├── errors/
│   │   │   ├── exceptions.dart       # Custom exception classes
│   │   │   └── failure.dart          # Failure sealed class for error handling
│   │   └── utils/
│   │       ├── distance_utils.dart   # Haversine distance calculations
│   │       ├── time_utils.dart       # ETA formatting, time-ago strings
│   │       └── debouncer.dart        # Search input debouncer
│   │
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── translink_api_service.dart       # HTTP client for GTFS-RT endpoints
│   │   │   ├── gtfs_static_service.dart         # Download and parse GTFS static ZIP
│   │   │   ├── location_service.dart            # Geolocator wrapper
│   │   │   ├── notification_service.dart        # Local notifications setup and trigger
│   │   │   └── local_database_service.dart      # SQLite database helper
│   │   ├── models/
│   │   │   ├── gtfs_realtime.pb.dart            # GENERATED: protobuf classes
│   │   │   ├── gtfs_realtime.pbenum.dart        # GENERATED: protobuf enums
│   │   │   ├── gtfs_realtime.pbjson.dart        # GENERATED: protobuf JSON helpers
│   │   │   ├── gtfs_realtime.pbserver.dart      # GENERATED: protobuf server helpers
│   │   │   ├── vehicle_position.dart            # Vehicle position domain model
│   │   │   ├── trip_update.dart                 # Trip update and ETA model
│   │   │   ├── service_alert.dart               # Service alert model
│   │   │   ├── bus_route.dart                   # Route info (from static GTFS)
│   │   │   ├── bus_stop.dart                    # Stop info (from static GTFS)
│   │   │   ├── trip.dart                        # Trip info (from static GTFS)
│   │   │   ├── shape_point.dart                 # Route shape coordinates
│   │   │   ├── stop_time.dart                   # Scheduled stop times
│   │   │   ├── favorite_stop.dart               # User favorited stop
│   │   │   └── route_history_entry.dart         # Previously viewed route entry
│   │   └── repositories/
│   │       ├── vehicle_repository.dart          # Fetches and caches vehicle positions
│   │       ├── trip_update_repository.dart      # Fetches and caches trip updates/ETAs
│   │       ├── alert_repository.dart            # Fetches and caches service alerts
│   │       ├── route_repository.dart            # Routes from static GTFS data
│   │       ├── stop_repository.dart             # Stops from static GTFS data
│   │       ├── shape_repository.dart            # Route shapes (polylines)
│   │       ├── favorites_repository.dart        # CRUD for favorite stops (SQLite)
│   │       └── history_repository.dart          # CRUD for route view history (SQLite)
│   │
│   ├── providers/
│   │   ├── vehicle_providers.dart               # Real-time vehicle position providers
│   │   ├── trip_update_providers.dart           # Trip update and ETA providers
│   │   ├── alert_providers.dart                 # Service alert providers
│   │   ├── route_providers.dart                 # Static route data providers
│   │   ├── stop_providers.dart                  # Static stop data providers
│   │   ├── shape_providers.dart                 # Route shape providers
│   │   ├── location_provider.dart               # Current GPS location provider
│   │   ├── search_provider.dart                 # Search query and filtered results
│   │   ├── favorites_provider.dart              # Favorite stops provider
│   │   ├── history_provider.dart                # Route history provider
│   │   ├── selected_route_provider.dart         # Currently selected/viewed route
│   │   ├── notification_provider.dart           # Notification settings and triggers
│   │   └── nearby_stops_provider.dart           # Auto-detected nearby stops
│   │
│   ├── features/
│   │   ├── map/
│   │   │   ├── map_screen.dart                  # Main screen with map and overlays
│   │   │   ├── widgets/
│   │   │   │   ├── bus_map.dart                 # FlutterMap widget with all layers
│   │   │   │   ├── bus_marker_layer.dart        # Bus icon markers on map
│   │   │   │   ├── route_polyline_layer.dart    # Route path polyline on map
│   │   │   │   ├── user_location_marker.dart    # Blue dot for current location
│   │   │   │   ├── stop_marker_layer.dart       # Stop markers (when route selected)
│   │   │   │   ├── search_bar_widget.dart       # Route/stop search bar overlay
│   │   │   │   ├── route_label_chip.dart        # Bus number label chip
│   │   │   │   ├── locate_me_button.dart        # Button to center on user location
│   │   │   │   ├── nearby_stops_sheet.dart      # Bottom sheet showing nearby stops
│   │   │   │   └── bus_info_bottom_sheet.dart   # Bottom sheet when bus tapped
│   │   │   └── controllers/
│   │   │       └── map_controller_provider.dart # Map camera/animation controller
│   │   │
│   │   ├── search/
│   │   │   ├── search_screen.dart               # Full search screen (route/stop)
│   │   │   └── widgets/
│   │   │       ├── search_result_tile.dart       # Single search result item
│   │   │       ├── recent_searches.dart          # Recently searched routes/stops
│   │   │       └── search_filters.dart           # Filter by route type
│   │   │
│   │   ├── route_detail/
│   │   │   ├── route_detail_screen.dart         # Separate screen: route detail view
│   │   │   └── widgets/
│   │   │       ├── bus_list_tile.dart            # Individual bus card in list
│   │   │       ├── route_info_header.dart        # Route name, direction, status
│   │   │       └── eta_timeline.dart             # ETA at upcoming stops
│   │   │
│   │   ├── stop_detail/
│   │   │   ├── stop_detail_screen.dart          # Stop detail (all arrivals at stop)
│   │   │   └── widgets/
│   │   │       ├── arrival_list_tile.dart        # Upcoming bus arrival card
│   │   │       ├── stop_info_header.dart         # Stop name, ID, accessibility
│   │   │       └── set_alert_button.dart         # Button to set arrival notification
│   │   │
│   │   ├── favorites/
│   │   │   ├── favorites_screen.dart            # List of favorited stops
│   │   │   └── widgets/
│   │   │       └── favorite_stop_tile.dart       # Favorite stop card with live ETAs
│   │   │
│   │   ├── history/
│   │   │   ├── history_screen.dart              # Previously viewed routes list
│   │   │   └── widgets/
│   │   │       └── history_entry_tile.dart       # History entry card
│   │   │
│   │   ├── alerts/
│   │   │   ├── alerts_screen.dart               # Service alerts list (full page)
│   │   │   └── widgets/
│   │   │       └── alert_card.dart               # Individual alert card
│   │   │
│   │   └── settings/
│   │       ├── settings_screen.dart             # App settings
│   │       └── widgets/
│   │           ├── theme_toggle.dart             # Dark/light mode switch
│   │           ├── notification_settings.dart    # Notification preferences
│   │           └── about_section.dart            # App info, TransLink attribution
│   │
│   └── navigation/
│       ├── app_router.dart                      # Named route definitions
│       └── bottom_nav_bar.dart                  # Bottom tab bar (3 tabs)
│
├── proto/
│   └── gtfs-realtime.proto                      # GTFS-RT proto definition file
│
├── test/
│   ├── data/
│   │   ├── datasources/
│   │   │   └── translink_api_service_test.dart
│   │   └── repositories/
│   │       ├── vehicle_repository_test.dart
│   │       └── stop_repository_test.dart
│   ├── providers/
│   │   ├── vehicle_providers_test.dart
│   │   └── search_provider_test.dart
│   └── features/
│       ├── map/
│       │   └── map_screen_test.dart
│       └── search/
│           └── search_screen_test.dart
│
├── pubspec.yaml
├── analysis_options.yaml
├── .env.example
└── architecture.md
```

---

## File Specifications

### Entry Point

#### `lib/main.dart`

**Purpose:** App entry point. Initializes all services before running the widget tree.

**Behavior:**
1. Call `WidgetsFlutterBinding.ensureInitialized()`
2. Initialize `LocalDatabaseService.init()` to open/create the SQLite database
3. Initialize `NotificationService.init()` to configure notification channels
4. Load API key from secure storage or compile-time `--dart-define`
5. Run the app wrapped in `ProviderScope` from Riverpod

**Key code pattern:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDatabaseService.init();
  await NotificationService.init();
  runApp(const ProviderScope(child: App()));
}
```

---

#### `lib/app.dart`

**Purpose:** Root widget. Sets up CupertinoApp with theme, routes, and the main scaffold with bottom navigation.

**Behavior:**
- Returns a `ConsumerWidget` that reads `themeProvider` to determine light/dark mode
- Wraps everything in `CupertinoApp` with `CupertinoThemeData`
- Home is a `CupertinoTabScaffold` with `BottomNavBar`
- Named routes registered from `AppRouter`

**Key code pattern:**
```dart
class App extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(themeProvider);
    return CupertinoApp(
      title: 'bussin!',
      theme: AppTheme.getTheme(brightness),
      home: const MainScaffold(),
      routes: AppRouter.routes,
    );
  }
}
```

---

### Core Layer

#### `lib/core/constants/api_constants.dart`

**Purpose:** All API-related constants in one place.

**Contents:**
```
TRANSLINK_API_KEY        - String, loaded from env/secure storage at runtime
GTFS_POSITION_URL        - 'https://gtfsapi.translink.ca/v3/gtfsposition'
GTFS_REALTIME_URL        - 'https://gtfsapi.translink.ca/v3/gtfsrealtime'
GTFS_ALERTS_URL          - 'https://gtfsapi.translink.ca/v3/gtfsalerts'
GTFS_STATIC_URL          - 'https://gtfs-static.translink.ca/gtfs/google_transit.zip'
VEHICLE_POLL_INTERVAL    - Duration(seconds: 10)
TRIP_UPDATE_POLL_INTERVAL - Duration(seconds: 30)
ALERT_POLL_INTERVAL      - Duration(seconds: 60)
STATIC_REFRESH_THRESHOLD - Duration(hours: 24)
HTTP_TIMEOUT             - Duration(seconds: 15)
```

---

#### `lib/core/constants/map_constants.dart`

**Purpose:** Map display defaults centered on Vancouver.

**Contents:**
```
VANCOUVER_CENTER         - LatLng(49.2827, -123.1207)
DEFAULT_ZOOM             - 13.0
MIN_ZOOM                 - 10.0
MAX_ZOOM                 - 18.0
TILE_URL                 - 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
USER_AGENT_PACKAGE       - 'com.bussin.app'
NEARBY_RADIUS_METERS     - 500.0
FIT_BOUNDS_PADDING       - EdgeInsets.all(50.0)
```

---

#### `lib/core/constants/app_constants.dart`

**Purpose:** General app-wide constants.

**Contents:**
```
APP_NAME                 - 'bussin!'
APP_VERSION              - '1.0.0'
TRANSLINK_ATTRIBUTION    - 'Route and arrival data used in this product or service
                            is provided by permission of TransLink. TransLink assumes
                            no responsibility for the accuracy or currency of the
                            Data used in this product or service.'
MAX_HISTORY_ENTRIES      - 50
SEARCH_DEBOUNCE_MS       - 300
MAX_SEARCH_RESULTS       - 20
MARKER_ANIMATION_DURATION - Duration(milliseconds: 2000)
```

---

#### `lib/core/theme/app_theme.dart`

**Purpose:** Defines complete CupertinoThemeData for both light and dark modes.

**Light theme:**
- Primary color: `#0060A9` (TransLink blue)
- Background: `CupertinoColors.systemBackground`
- Scaffold background: white
- Text: dark on light

**Dark theme:**
- Primary color: `#4DA6FF` (lighter blue for dark backgrounds)
- Background: `CupertinoColors.darkBackgroundGray`
- Scaffold background: near-black
- Text: light on dark

**Method:**
```dart
static CupertinoThemeData getTheme(Brightness brightness)
```

---

#### `lib/core/theme/theme_provider.dart`

**Purpose:** Riverpod provider that manages and persists the user's theme preference.

**Provider type:** `StateNotifierProvider<ThemeNotifier, Brightness>`

**Behavior:**
- On init: reads saved preference from `SharedPreferences` (key: `theme_mode`)
- Values: `Brightness.light`, `Brightness.dark`, or system default
- `toggle()` method switches between light and dark
- `setMode(Brightness)` for explicit setting
- Persists choice to `SharedPreferences` on every change

---

#### `lib/core/errors/exceptions.dart`

**Purpose:** Typed exceptions thrown by datasources.

**Classes:**
- `ServerException({String message, int? statusCode})` - HTTP errors from TransLink API
- `CacheException({String message})` - SQLite read/write errors
- `LocationException({String message})` - GPS permission denied or unavailable
- `ParseException({String message})` - Protobuf or CSV parsing failures

---

#### `lib/core/errors/failure.dart`

**Purpose:** Sealed class representing handled failures in repositories, used by the UI to show appropriate error messages.

**Classes:**
```dart
sealed class Failure {
  final String message;
}
class ServerFailure extends Failure       // API/network errors
class CacheFailure extends Failure        // Database errors
class LocationFailure extends Failure     // GPS errors
class ParseFailure extends Failure        // Data format errors
```

---

#### `lib/core/utils/distance_utils.dart`

**Purpose:** Geographic distance calculations.

**Functions:**
- `double haversineDistance(LatLng a, LatLng b)` - returns distance in meters between two coordinates using the Haversine formula
- `List<BusStop> stopsWithinRadius(LatLng center, double radiusM, List<BusStop> stops)` - filters a list of stops to only those within the given radius
- `String formatDistance(double meters)` - returns human-readable string like "150m" or "1.2km"

---

#### `lib/core/utils/time_utils.dart`

**Purpose:** Time and ETA formatting.

**Functions:**
- `String formatEta(int secondsAway)` - returns "2 min", "< 1 min", "15 min", "Now"
- `String timeAgo(DateTime timestamp)` - returns "3 min ago", "1 hr ago", "Just now"
- `String formatScheduledTime(DateTime time)` - returns "3:45 PM" using intl package
- `String formatDelay(int delaySeconds)` - returns "+3 min late" or "-1 min early" or "On time"

---

#### `lib/core/utils/debouncer.dart`

**Purpose:** Debounces rapid function calls (used for search input).

**Class:** `Debouncer`
- Constructor: `Debouncer({int milliseconds = 300})`
- `void run(VoidCallback action)` - cancels previous timer and starts new one
- `void cancel()` - cancels pending action
- `void dispose()` - cleanup

---

### Data Layer - Datasources

#### `lib/data/datasources/translink_api_service.dart`

**Purpose:** HTTP client that fetches raw binary data from TransLink's GTFS-RT V3 endpoints.

**Dependencies:** `http` package

**Methods:**
- `Future<Uint8List> fetchVehiclePositions()` - GET request to position endpoint, returns raw protobuf bytes
- `Future<Uint8List> fetchTripUpdates()` - GET request to realtime endpoint
- `Future<Uint8List> fetchServiceAlerts()` - GET request to alerts endpoint

**Implementation details:**
- Appends `?apikey={API_KEY}` to each URL
- Sets `Accept: application/x-protobuf` header
- Timeout: 15 seconds
- On non-200 response: throws `ServerException` with status code
- On timeout: throws `ServerException` with timeout message
- Single retry on network failure before throwing
- Response body is `Uint8List` (raw bytes), NOT decoded as string

**Key code pattern:**
```dart
Future<Uint8List> fetchVehiclePositions() async {
  final uri = Uri.parse('$GTFS_POSITION_URL?apikey=$apiKey');
  final response = await client.get(uri).timeout(HTTP_TIMEOUT);
  if (response.statusCode != 200) {
    throw ServerException(message: 'Failed', statusCode: response.statusCode);
  }
  return response.bodyBytes;  // raw protobuf bytes
}
```

---

#### `lib/data/datasources/gtfs_static_service.dart`

**Purpose:** Downloads, extracts, and parses the GTFS static data ZIP file.

**Dependencies:** `http`, `archive`, `csv`, `path_provider`

**Methods:**
- `Future<void> downloadAndExtractGtfsData()` - downloads ZIP to temp dir, extracts CSV files to app documents dir
- `Future<List<Map<String, String>>> parseCsvFile(String filename)` - reads a CSV file and returns list of row maps
- `Future<DateTime?> getLastDownloadTime()` - reads timestamp from SharedPreferences
- `Future<void> setLastDownloadTime(DateTime time)` - stores timestamp
- `Future<bool> isDataStale()` - returns true if last download was >24h ago or never

**CSV parsing details:**
- Uses `csv` package `CsvToListConverter` with `eol: '\n'` and `fieldDelimiter: ','`
- First row is header row, used as keys for subsequent row maps
- Files parsed: `routes.txt`, `stops.txt`, `trips.txt`, `stop_times.txt`, `shapes.txt`
- `stop_times.txt` is the largest file (millions of rows). Parse and insert in batches of 1000

---

#### `lib/data/datasources/location_service.dart`

**Purpose:** Wraps the `geolocator` package for GPS access.

**Dependencies:** `geolocator`, `permission_handler`

**Methods:**
- `Future<bool> checkAndRequestPermission()` - checks location permission, requests if not granted, returns success bool
- `Future<Position> getCurrentPosition()` - one-shot GPS fix with high accuracy
- `Stream<Position> getPositionStream({int distanceFilter = 10})` - continuous updates, only emits when user moves >10m
- `Future<bool> isLocationServiceEnabled()` - checks if GPS is turned on at system level

**Error handling:**
- Permission permanently denied: throws `LocationException` with message guiding user to settings
- Location service disabled: throws `LocationException` prompting user to enable GPS
- Timeout (30s): throws `LocationException`

**Fallback:** When location is unavailable, providers fall back to `VANCOUVER_CENTER` coordinates so the map still works.

---

#### `lib/data/datasources/notification_service.dart`

**Purpose:** Configures and fires local push notifications for bus arrival alerts. Foreground-only (notifications work while app is running or backgrounded, not when killed).

**Dependencies:** `flutter_local_notifications`

**Methods:**
- `static Future<void> init()` - initializes plugin with:
  - Android: notification channel "Bus Alerts", importance high, vibration on
  - iOS: request alert + badge + sound permissions
- `Future<void> showBusApproachingNotification({required String routeShortName, required String stopName, required int minutesAway})` - fires notification with title "Bus {route} arriving" and body "{minutesAway} min to {stopName}"
- `Future<void> cancelNotification(int id)` - cancel specific notification
- `Future<void> cancelAllNotifications()` - cancel all

**Notification ID scheme:** hash of `routeId + stopId` to avoid duplicates.

---

#### `lib/data/datasources/local_database_service.dart`

**Purpose:** Manages the SQLite database for GTFS static data cache and user data (favorites, history).

**Dependencies:** `sqflite`, `path_provider`

**Methods:**
- `static Future<void> init()` - opens or creates database at version 1
- `static Database get db` - getter for the database instance
- `Future<void> bulkInsertRoutes(List<Map<String, dynamic>> rows)` - batch insert into gtfs_routes
- `Future<void> bulkInsertStops(List<Map<String, dynamic>> rows)` - batch insert into gtfs_stops
- `Future<void> bulkInsertTrips(List<Map<String, dynamic>> rows)` - batch insert into gtfs_trips
- `Future<void> bulkInsertStopTimes(List<Map<String, dynamic>> rows)` - batch insert into gtfs_stop_times
- `Future<void> bulkInsertShapes(List<Map<String, dynamic>> rows)` - batch insert into gtfs_shapes
- `Future<void> clearGtfsData()` - drops and recreates all gtfs_ tables (before re-import)
- Standard CRUD for `favorites` and `route_history` tables

**Bulk insert strategy:** Uses `Batch` API with `noResult: true` for performance. Wraps entire import in a transaction. Inserts in chunks of 1000 rows.

**Database file location:** `{appDocumentsDir}/bussin.db`

---

### Data Layer - Models

#### `lib/data/models/gtfs_realtime.pb.dart` (and companion files)

**Purpose:** Auto-generated Dart classes from the GTFS-RT protobuf schema.

**Generation:** Run `protoc --dart_out=lib/data/models/ proto/gtfs-realtime.proto` with the `protoc_plugin` Dart package installed.

**Key generated classes used by the app:**
- `FeedMessage` - top-level container, has `header` and `entity` list
- `FeedEntity` - wrapper with `id`, optional `tripUpdate`, `vehicle`, `alert`
- `VehiclePosition` - has `trip`, `vehicle`, `position`, `currentStopSequence`, `timestamp`
- `Position` - has `latitude`, `longitude`, `bearing`, `speed`
- `TripUpdate` - has `trip`, `stopTimeUpdate` list, `timestamp`
- `StopTimeUpdate` - has `stopSequence`, `stopId`, `arrival`, `departure`
- `StopTimeEvent` - has `delay`, `time`
- `Alert` - has `activePeriod`, `informedEntity`, `cause`, `effect`, `headerText`, `descriptionText`
- `TripDescriptor` - has `tripId`, `routeId`, `directionId`, `startTime`, `startDate`
- `VehicleDescriptor` - has `id`, `label`
- `TranslatedString` - has `translation` list with `text` and `language`
- `EntitySelector` - has `routeId`, `stopId`, optional `trip`

**Usage pattern:**
```dart
final bytes = await apiService.fetchVehiclePositions();
final feed = FeedMessage.fromBuffer(bytes);
for (final entity in feed.entity) {
  if (entity.hasVehicle()) {
    final v = entity.vehicle;
    // v.position.latitude, v.position.longitude, v.trip.routeId, etc.
  }
}
```

---

#### `lib/data/models/vehicle_position.dart`

**Purpose:** App domain model for a vehicle's real-time position.

**Fields:**
```dart
@freezed
class VehiclePositionModel with _$VehiclePositionModel {
  const factory VehiclePositionModel({
    required String vehicleId,       // unique vehicle identifier
    required String tripId,          // current trip this vehicle is on
    required String routeId,         // route this vehicle is serving
    required double latitude,
    required double longitude,
    double? bearing,                 // heading direction in degrees (0-360)
    double? speed,                   // speed in m/s
    required DateTime timestamp,     // when this position was reported
    String? currentStopId,           // stop the vehicle is at or approaching
    int? currentStopSequence,        // position in the trip's stop sequence
    String? vehicleLabel,            // human-readable bus number
  }) = _VehiclePositionModel;
}
```

**Mapping from protobuf:** Created in `VehicleRepository` by extracting fields from `FeedEntity.vehicle`.

---

#### `lib/data/models/trip_update.dart`

**Purpose:** Models trip-level delay/ETA information and per-stop arrival predictions.

**Fields:**
```dart
@freezed
class TripUpdateModel with _$TripUpdateModel {
  const factory TripUpdateModel({
    required String tripId,
    required String routeId,
    required List<StopTimeUpdateModel> stopTimeUpdates,
    DateTime? timestamp,
    int? delay,                      // overall trip delay in seconds (negative = early)
  }) = _TripUpdateModel;
}

@freezed
class StopTimeUpdateModel with _$StopTimeUpdateModel {
  const factory StopTimeUpdateModel({
    required String stopId,
    required int stopSequence,
    DateTime? predictedArrival,      // predicted arrival time at this stop
    DateTime? predictedDeparture,    // predicted departure time
    int? arrivalDelay,               // delay in seconds for arrival
    int? departureDelay,             // delay in seconds for departure
  }) = _StopTimeUpdateModel;
}
```

---

#### `lib/data/models/service_alert.dart`

**Purpose:** Models a TransLink service disruption or alert.

**Fields:**
```dart
@freezed
class ServiceAlertModel with _$ServiceAlertModel {
  const factory ServiceAlertModel({
    required String id,
    required String headerText,       // alert title
    required String descriptionText,  // full description
    required String cause,            // CONSTRUCTION, ACCIDENT, WEATHER, etc.
    required String effect,           // DETOUR, REDUCED_SERVICE, NO_SERVICE, etc.
    List<String>? affectedRouteIds,   // routes affected by this alert
    List<String>? affectedStopIds,    // stops affected
    DateTime? activePeriodStart,
    DateTime? activePeriodEnd,
  }) = _ServiceAlertModel;
}
```

---

#### `lib/data/models/bus_route.dart`

**Purpose:** A transit route from the GTFS static data.

**Fields:**
```dart
@freezed
class BusRoute with _$BusRoute {
  const factory BusRoute({
    required String routeId,
    required String routeShortName,   // display number: "049", "099", "R4", "Canada Line"
    required String routeLongName,    // full name: "Metrotown Station / UBC"
    required int routeType,           // GTFS route type: 0=tram, 1=subway, 3=bus
    String? routeColor,               // hex color from GTFS (without #)
  }) = _BusRoute;
}
```

---

#### `lib/data/models/bus_stop.dart`

**Purpose:** A transit stop from the GTFS static data.

**Fields:**
```dart
@freezed
class BusStop with _$BusStop {
  const factory BusStop({
    required String stopId,
    required String stopName,         // "UBC Exchange Bay 7"
    required double stopLat,
    required double stopLon,
    String? stopCode,                 // 5-digit stop number for rider use
    String? parentStation,            // parent station ID for grouped stops
  }) = _BusStop;
}
```

---

#### `lib/data/models/trip.dart`

**Purpose:** A scheduled trip from GTFS static data. Links a route to a shape and direction.

**Fields:**
```dart
@freezed
class TripModel with _$TripModel {
  const factory TripModel({
    required String tripId,
    required String routeId,
    required String serviceId,
    String? tripHeadsign,             // destination display: "UBC", "Metrotown"
    int? directionId,                 // 0 = outbound, 1 = inbound
    String? shapeId,                  // links to shapes for polyline
  }) = _TripModel;
}
```

---

#### `lib/data/models/shape_point.dart`

**Purpose:** A single coordinate in a route's geographic shape. Used to build polylines on the map.

**Fields:**
```dart
@freezed
class ShapePoint with _$ShapePoint {
  const factory ShapePoint({
    required String shapeId,
    required double lat,
    required double lon,
    required int sequence,            // order in the polyline
  }) = _ShapePoint;
}
```

---

#### `lib/data/models/stop_time.dart`

**Purpose:** Scheduled arrival/departure time at a stop for a specific trip.

**Fields:**
```dart
@freezed
class StopTimeModel with _$StopTimeModel {
  const factory StopTimeModel({
    required String tripId,
    required String stopId,
    required String arrivalTime,      // "HH:MM:SS" format (can exceed 24:00:00 for overnight)
    required String departureTime,
    required int stopSequence,
  }) = _StopTimeModel;
}
```

---

#### `lib/data/models/favorite_stop.dart`

**Purpose:** A stop the user has bookmarked.

**Fields:**
```dart
@freezed
class FavoriteStop with _$FavoriteStop {
  const factory FavoriteStop({
    int? id,                          // SQLite auto-increment ID
    required String stopId,
    required String stopName,
    required double stopLat,
    required double stopLon,
    required DateTime createdAt,
  }) = _FavoriteStop;
}
```

---

#### `lib/data/models/route_history_entry.dart`

**Purpose:** A record of a route the user previously viewed.

**Fields:**
```dart
@freezed
class RouteHistoryEntry with _$RouteHistoryEntry {
  const factory RouteHistoryEntry({
    int? id,                          // SQLite auto-increment ID
    required String routeId,
    required String routeShortName,
    required String routeLongName,
    required DateTime viewedAt,
  }) = _RouteHistoryEntry;
}
```

---

### Data Layer - Repositories

#### `lib/data/repositories/vehicle_repository.dart`

**Purpose:** Fetches vehicle positions from the TransLink API, parses the protobuf response, and maps it to domain models.

**Dependencies:** `TranslinkApiService`

**Methods:**
- `Future<List<VehiclePositionModel>> getVehiclePositions()` - fetches protobuf, parses `FeedMessage.fromBuffer()`, iterates entities, maps each `entity.vehicle` to `VehiclePositionModel`
- `Future<List<VehiclePositionModel>> getVehiclesForRoute(String routeId)` - calls `getVehiclePositions()` then filters by `routeId`

**Caching:** Stores the last successful result in memory. If the next fetch fails, returns the cached result instead of throwing (stale data is better than no data for real-time tracking).

**Protobuf mapping logic:**
```dart
VehiclePositionModel(
  vehicleId: entity.vehicle.vehicle.id,
  tripId: entity.vehicle.trip.tripId,
  routeId: entity.vehicle.trip.routeId,
  latitude: entity.vehicle.position.latitude,
  longitude: entity.vehicle.position.longitude,
  bearing: entity.vehicle.position.bearing,
  speed: entity.vehicle.position.speed,
  timestamp: DateTime.fromMillisecondsSinceEpoch(
    entity.vehicle.timestamp.toInt() * 1000
  ),
  vehicleLabel: entity.vehicle.vehicle.label,
  currentStopSequence: entity.vehicle.currentStopSequence,
)
```

---

#### `lib/data/repositories/trip_update_repository.dart`

**Purpose:** Fetches trip updates (ETAs and delays) from the TransLink API.

**Dependencies:** `TranslinkApiService`

**Methods:**
- `Future<List<TripUpdateModel>> getTripUpdates()` - fetches and parses trip update feed
- `Future<List<StopTimeUpdateModel>> getEtasForStop(String stopId)` - collects all `StopTimeUpdate` entries across all trip updates that reference the given `stopId`, returns sorted by predicted arrival time
- `Future<TripUpdateModel?> getTripUpdate(String tripId)` - finds a specific trip's update

**Protobuf mapping logic:**
- Each `entity.tripUpdate.stopTimeUpdate` contains `stopId`, `stopSequence`, and `arrival`/`departure` events
- `StopTimeEvent.time` is a Unix timestamp (seconds) for the predicted time
- `StopTimeEvent.delay` is seconds of delay (positive = late, negative = early)

---

#### `lib/data/repositories/alert_repository.dart`

**Purpose:** Fetches service alerts from the TransLink API.

**Dependencies:** `TranslinkApiService`

**Methods:**
- `Future<List<ServiceAlertModel>> getServiceAlerts()` - fetches and parses alert feed
- `Future<List<ServiceAlertModel>> getAlertsForRoute(String routeId)` - filters alerts where `affectedRouteIds` contains the given route

**Protobuf mapping logic:**
- `entity.alert.headerText` and `descriptionText` are `TranslatedString` objects
- Extract the English translation: `translatedString.translation.firstWhere((t) => t.language == 'en', orElse: () => translatedString.translation.first).text`
- `informedEntity` list contains `EntitySelector` objects with `routeId` and `stopId`

---

#### `lib/data/repositories/route_repository.dart`

**Purpose:** Provides route data from the local SQLite cache of GTFS static data.

**Dependencies:** `LocalDatabaseService`, `GtfsStaticService`

**Methods:**
- `Future<List<BusRoute>> getAllRoutes()` - SELECT * FROM gtfs_routes, maps to `BusRoute` list
- `Future<BusRoute?> getRoute(String routeId)` - single route by ID
- `Future<List<BusRoute>> searchRoutes(String query)` - `WHERE route_short_name LIKE '%query%' OR route_long_name LIKE '%query%'`, limited to 20 results
- `Future<void> refreshFromStatic()` - triggers GTFS static download, clears table, re-imports

---

#### `lib/data/repositories/stop_repository.dart`

**Purpose:** Provides stop data from local SQLite cache.

**Dependencies:** `LocalDatabaseService`, `GtfsStaticService`

**Methods:**
- `Future<List<BusStop>> getAllStops()` - all stops (cached in memory after first load for performance)
- `Future<BusStop?> getStop(String stopId)` - single stop by ID
- `Future<List<BusStop>> searchStops(String query)` - `WHERE stop_name LIKE '%query%' OR stop_code = 'query'`, limited to 20 results
- `Future<List<BusStop>> getStopsForRoute(String routeId)` - joins gtfs_trips + gtfs_stop_times + gtfs_stops to find all stops served by a route, ordered by stop_sequence
- `Future<List<BusStop>> getNearbyStops(LatLng location, double radiusMeters)` - uses Haversine filter on in-memory stop list

---

#### `lib/data/repositories/shape_repository.dart`

**Purpose:** Provides route polyline coordinates from GTFS shape data.

**Dependencies:** `LocalDatabaseService`

**Methods:**
- `Future<List<LatLng>> getShapePoints(String shapeId)` - `SELECT shape_pt_lat, shape_pt_lon FROM gtfs_shapes WHERE shape_id = ? ORDER BY shape_pt_sequence`, returns as `LatLng` list
- `Future<List<LatLng>> getRouteShape(String routeId)` - finds any trip for the route via `SELECT shape_id FROM gtfs_trips WHERE route_id = ? LIMIT 1`, then loads that shape

**Note on directions:** Routes typically have two directions (inbound/outbound) with different shapes. For v1, we load the shape matching the first active trip's direction. Future enhancement: show both directions or match to a specific direction.

---

#### `lib/data/repositories/favorites_repository.dart`

**Purpose:** CRUD operations for the user's favorite stops, stored in SQLite.

**Dependencies:** `LocalDatabaseService`

**Methods:**
- `Future<List<FavoriteStop>> getFavorites()` - `SELECT * FROM favorites ORDER BY created_at DESC`
- `Future<void> addFavorite(FavoriteStop stop)` - `INSERT INTO favorites`
- `Future<void> removeFavorite(String stopId)` - `DELETE FROM favorites WHERE stop_id = ?`
- `Future<bool> isFavorite(String stopId)` - `SELECT COUNT(*) FROM favorites WHERE stop_id = ?`

---

#### `lib/data/repositories/history_repository.dart`

**Purpose:** CRUD operations for the user's route viewing history.

**Dependencies:** `LocalDatabaseService`

**Methods:**
- `Future<List<RouteHistoryEntry>> getHistory()` - `SELECT * FROM route_history ORDER BY viewed_at DESC LIMIT 50`
- `Future<void> addToHistory(RouteHistoryEntry entry)` - upsert: if route_id exists, update viewed_at; otherwise insert
- `Future<void> clearHistory()` - `DELETE FROM route_history`

**Auto-pruning:** After each insert, if count > `MAX_HISTORY_ENTRIES` (50), delete oldest entries.

---

### Providers (Riverpod)

#### `lib/providers/vehicle_providers.dart`

**Providers:**

1. `vehicleRepositoryProvider` - `Provider<VehicleRepository>` - singleton instance of the repository

2. `allVehiclePositionsProvider` - `StreamProvider<List<VehiclePositionModel>>` - emits a new list of all vehicle positions every 10 seconds

   **Implementation:**
   ```dart
   Stream<List<VehiclePositionModel>> stream() async* {
     while (true) {
       yield await ref.read(vehicleRepositoryProvider).getVehiclePositions();
       await Future.delayed(VEHICLE_POLL_INTERVAL);
     }
   }
   ```
   Auto-disposes when no widget is watching.

3. `vehiclesForRouteProvider(String routeId)` - derived `Provider` that filters `allVehiclePositionsProvider` by route ID. Returns `AsyncValue<List<VehiclePositionModel>>`.

---

#### `lib/providers/trip_update_providers.dart`

**Providers:**

1. `tripUpdateRepositoryProvider` - `Provider<TripUpdateRepository>`

2. `tripUpdatesProvider` - `StreamProvider<List<TripUpdateModel>>` polling every 30 seconds

3. `etasForStopProvider(String stopId)` - derived provider that:
   - Reads `tripUpdatesProvider`
   - Filters all `StopTimeUpdateModel` entries matching the stop ID
   - Sorts by `predictedArrival` ascending
   - Returns `AsyncValue<List<StopTimeUpdateModel>>`

4. `tripUpdateProvider(String tripId)` - derived single-trip lookup

---

#### `lib/providers/alert_providers.dart`

**Providers:**

1. `alertRepositoryProvider` - `Provider<AlertRepository>`

2. `serviceAlertsProvider` - `StreamProvider<List<ServiceAlertModel>>` polling every 60 seconds

3. `alertsForRouteProvider(String routeId)` - derived filtered provider

4. `activeAlertCountProvider` - `Provider<int>` derived from `serviceAlertsProvider` that returns the total count of active alerts. Used for the badge number on the Alerts nav icon.

---

#### `lib/providers/route_providers.dart`

**Providers:**

1. `routeRepositoryProvider` - `Provider<RouteRepository>`

2. `allRoutesProvider` - `FutureProvider<List<BusRoute>>` loaded once from SQLite

3. `routeProvider(String routeId)` - `FutureProvider<BusRoute?>` single lookup

4. `routeSearchProvider(String query)` - `FutureProvider<List<BusRoute>>` search results

---

#### `lib/providers/stop_providers.dart`

**Providers:**

1. `stopRepositoryProvider` - `Provider<StopRepository>`

2. `allStopsProvider` - `FutureProvider<List<BusStop>>` loaded once (cached in repo)

3. `stopProvider(String stopId)` - single stop lookup

4. `stopsForRouteProvider(String routeId)` - all stops on a route, ordered

5. `stopSearchProvider(String query)` - search results

---

#### `lib/providers/shape_providers.dart`

**Providers:**

1. `shapeRepositoryProvider` - `Provider<ShapeRepository>`

2. `routeShapeProvider(String routeId)` - `FutureProvider<List<LatLng>>` for drawing the route polyline on the map

---

#### `lib/providers/location_provider.dart`

**Providers:**

1. `locationServiceProvider` - `Provider<LocationService>`

2. `currentLocationProvider` - `StreamProvider<Position>` from GPS stream (continuous, 10m distance filter)

3. `locationPermissionProvider` - `FutureProvider<bool>` checks and requests permission on first access

---

#### `lib/providers/search_provider.dart`

**Providers:**

1. `searchQueryProvider` - `StateProvider<String>` holding the current search text

2. `searchResultsProvider` - `FutureProvider<SearchResults>` derived from `searchQueryProvider`:
   - If query is empty: returns empty results
   - Otherwise: calls `routeSearchProvider(query)` and `stopSearchProvider(query)` in parallel
   - Returns `SearchResults(routes: [...], stops: [...])`

**SearchResults class:**
```dart
class SearchResults {
  final List<BusRoute> routes;
  final List<BusStop> stops;
}
```

---

#### `lib/providers/favorites_provider.dart`

**Providers:**

1. `favoritesProvider` - `AsyncNotifierProvider<FavoritesNotifier, List<FavoriteStop>>`:
   - `build()`: loads all favorites from SQLite
   - `addFavorite(FavoriteStop stop)`: inserts and refreshes state
   - `removeFavorite(String stopId)`: deletes and refreshes state

2. `isFavoriteProvider(String stopId)` - `Provider<bool>` derived from favoritesProvider, checks if stop is in the list

---

#### `lib/providers/history_provider.dart`

**Providers:**

1. `historyProvider` - `AsyncNotifierProvider<HistoryNotifier, List<RouteHistoryEntry>>`:
   - `build()`: loads history from SQLite
   - `addToHistory(RouteHistoryEntry entry)`: upserts and refreshes
   - `clearHistory()`: clears all and refreshes

---

#### `lib/providers/selected_route_provider.dart`

**Providers:**

1. `selectedRouteProvider` - `StateProvider<String?>` holding the currently viewed route ID (null = no route selected, show all buses)

**Side effect:** When this provider's value changes to a non-null route ID:
- Adds an entry to `historyProvider`
- Triggers `routeShapeProvider` to load the polyline
- Triggers `vehiclesForRouteProvider` to filter buses

---

#### `lib/providers/notification_provider.dart`

**Providers:**

1. `notificationServiceProvider` - `Provider<NotificationService>`

2. `busAlertSettingsProvider` - `StateNotifierProvider<BusAlertNotifier, List<BusAlert>>`:
   - `BusAlert` holds: `routeId`, `stopId`, `stopName`, `thresholdMinutes`
   - `addAlert(BusAlert alert)`: registers a new alert
   - `removeAlert(String routeId, String stopId)`: removes an alert
   - On each trip update poll: checks if any alert's ETA <= threshold, fires notification, auto-removes the alert

**Alert check logic (runs inside the notifier):**
```
for each active alert:
  get ETAs for alert.stopId from tripUpdatesProvider
  find ETA matching alert.routeId
  if predictedArrival - now <= alert.thresholdMinutes:
    fire notification
    remove alert from list
```

---

#### `lib/providers/nearby_stops_provider.dart`

**Providers:**

1. `nearbyStopsProvider` - derived from `currentLocationProvider` + `allStopsProvider`:
   - When both have data: filters stops within `NEARBY_RADIUS_METERS` (500m) using Haversine
   - Sorts by distance ascending
   - Returns `AsyncValue<List<(BusStop, double)>>` where the double is the distance in meters
   - Throttled: only recalculates when location changes significantly (handled by geolocator's 10m distance filter)

---

### Features / UI Layer

#### `lib/features/map/map_screen.dart`

**Purpose:** The main screen of the app. Contains the full-screen map with all overlays.

**Layout (top to bottom):**
1. `CupertinoPageScaffold` with transparent nav bar
2. Full-screen `BusMap` widget (fills entire screen, renders under nav bar)
3. Overlaid at top: `SearchBarWidget` with frosted glass background
4. Below search bar: `RouteLabel` chip (only visible when route selected)
5. Bottom-right: `LocateMeButton` (circular Cupertino button)
6. Bottom-left: "Nearby" button that opens `NearbyStopsSheet`
7. When a bus marker is tapped: `BusInfoBottomSheet` slides up

**State consumed:**
- `selectedRouteProvider` - determines which buses/polyline to show
- `vehiclesForRouteProvider` or `allVehiclePositionsProvider` - bus markers
- `currentLocationProvider` - user blue dot
- `routeShapeProvider` - polyline (when route selected)
- `activeAlertCountProvider` - badge on alerts icon in nav bar

**Nav bar actions:**
- History button (clock icon) - pushes `HistoryScreen`
- Alerts button (bell icon with badge count) - pushes `AlertsScreen`

---

#### `lib/features/map/widgets/bus_map.dart`

**Purpose:** The FlutterMap widget composing all map layers.

**Widget type:** `ConsumerStatefulWidget` (needs `MapController` lifecycle)

**Structure:**
```dart
FlutterMap(
  mapController: mapController,
  options: MapOptions(
    initialCenter: VANCOUVER_CENTER,
    initialZoom: DEFAULT_ZOOM,
    minZoom: MIN_ZOOM,
    maxZoom: MAX_ZOOM,
    interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
  ),
  children: [
    // 1. Base tiles
    TileLayer(
      urlTemplate: TILE_URL,
      userAgentPackageName: USER_AGENT_PACKAGE,
    ),
    // 2. Route polyline (when route selected)
    RoutePolylineLayer(routeId: selectedRouteId),
    // 3. Stop markers (when route selected)
    StopMarkerLayer(routeId: selectedRouteId),
    // 4. Bus markers
    BusMarkerLayer(vehicles: vehicles),
    // 5. User location blue dot
    UserLocationMarker(position: userPosition),
    // 6. Attribution
    RichAttributionWidget(attributions: [
      TextSourceAttribution('OpenStreetMap contributors'),
      TextSourceAttribution('TransLink'),
    ]),
  ],
)
```

---

#### `lib/features/map/widgets/bus_marker_layer.dart`

**Purpose:** Renders a `MarkerLayer` with one marker per active bus.

**Inputs:** `List<VehiclePositionModel> vehicles`

**Marker specification:**
- Size: 40x40 pixels
- Icon: custom bus asset (`bus_marker.png`) with route number text overlay
- Rotation: uses `bearing` field to rotate the icon in the direction of travel
- Alignment: `Alignment.center`
- On tap: calls callback that opens `BusInfoBottomSheet` with this vehicle's data

**Smooth animation between polls:**
- Stores previous positions in a `Map<String, LatLng>` keyed by vehicleId
- When new positions arrive, uses `AnimationController` (2s duration) to interpolate each marker from old position to new position using `LatLng.lerp`
- This creates smooth movement instead of jumping every 10 seconds

---

#### `lib/features/map/widgets/route_polyline_layer.dart`

**Purpose:** Draws the route path on the map when a route is selected.

**Inputs:** `String? routeId`

**Behavior:**
- If `routeId` is null: renders nothing
- Otherwise: reads `routeShapeProvider(routeId)` and renders a `PolylineLayer` with:
  - Color: route color from GTFS data, or default `#0060A9` (TransLink blue)
  - Stroke width: 4.0
  - Points: `List<LatLng>` from shape data

---

#### `lib/features/map/widgets/user_location_marker.dart`

**Purpose:** Renders the user's current GPS position as a blue dot with pulsing animation.

**Inputs:** `Position? position` from `currentLocationProvider`

**Visual:**
- Outer ring: translucent blue circle, pulsing (scales between 1.0x and 1.5x over 2 seconds, repeating)
- Inner dot: solid blue (`#007AFF`), 12px diameter
- Accuracy ring: translucent blue circle with radius proportional to GPS accuracy (in meters, converted to map pixels)

**Implementation:** `AnimatedBuilder` wrapping a `MarkerLayer` with a single `Marker`. Uses `AnimationController` with `repeat()` for the pulse.

**When location unavailable:** renders nothing (marker layer with empty list).

---

#### `lib/features/map/widgets/stop_marker_layer.dart`

**Purpose:** Shows small markers at each bus stop along the selected route.

**Inputs:** `String? routeId`

**Behavior:**
- If no route selected: renders nothing
- Otherwise: reads `stopsForRouteProvider(routeId)` and renders `MarkerLayer` with small circle markers (8px, gray with white border)
- On tap: navigates to `StopDetailScreen` for that stop

---

#### `lib/features/map/widgets/search_bar_widget.dart`

**Purpose:** Search bar overlay at the top of the map screen.

**Visual:**
- `CupertinoSearchTextField` with frosted glass (`BackdropFilter`) background
- Rounded corners, shadow, horizontal padding
- Placeholder text: "Search routes or stops..."
- Displays current filter context when route selected (e.g., "Route 49 - UBC")

**Behavior:**
- On tap: navigates to `SearchScreen` (full-screen modal, passes current query)
- Read-only on the map screen itself; actual typing happens on `SearchScreen`

---

#### `lib/features/map/widgets/route_label_chip.dart`

**Purpose:** Small pill showing the currently selected route number.

**Visual:**
- Rounded rectangle with route color background
- White text showing route short name (e.g., "49")
- Small "X" button to clear selection

**Behavior:**
- Only visible when `selectedRouteProvider` is non-null
- Tapping the X clears `selectedRouteProvider` to null (shows all buses again)

---

#### `lib/features/map/widgets/locate_me_button.dart`

**Purpose:** Floating button to center the map on the user's GPS position.

**Visual:**
- Circular button, 44x44, Cupertino styling
- Location arrow icon (`CupertinoIcons.location_fill`)
- Semi-transparent background with blur

**Behavior:**
- On tap: reads `currentLocationProvider`, animates map camera to that position at zoom 15
- If location not available: shows brief Cupertino alert explaining location is unavailable
- Visual state change: icon is outlined when not centered, filled when centered on user

---

#### `lib/features/map/widgets/nearby_stops_sheet.dart`

**Purpose:** Draggable bottom sheet showing auto-detected nearby stops with live arrival times.

**Visual:**
- Cupertino-styled draggable sheet (starts minimized at bottom, can be pulled up)
- Header: "Nearby Stops" with distance radius indicator
- List of nearby stops sorted by distance

**Each item shows:**
- Stop name
- Distance (e.g., "150m")
- Next 2-3 bus arrivals with route number and countdown

**Behavior:**
- Reads `nearbyStopsProvider` for stop list
- Reads `etasForStopProvider` for each stop's arrivals
- Tap on a stop: navigates to `StopDetailScreen`
- If location unavailable: shows message prompting to enable GPS

---

#### `lib/features/map/widgets/bus_info_bottom_sheet.dart`

**Purpose:** Bottom sheet that appears when the user taps a bus marker on the map.

**Visual:**
- Cupertino modal popup style (slides up from bottom, can be dragged to dismiss)
- Route number badge (large, colored)
- Headsign/destination text
- "Last updated: X seconds ago"
- Speed: "45 km/h" (converted from m/s)
- Next 3-4 upcoming stops with ETA countdown

**Actions:**
- "View Full Route" button -> pushes `RouteDetailScreen`
- "Set Arrival Alert" button -> opens stop picker + threshold picker

---

#### `lib/features/map/controllers/map_controller_provider.dart`

**Purpose:** Riverpod provider wrapping `MapController` for programmatic map control.

**Provider type:** `Provider<MapController>` (must be manually disposed with the widget)

**Exposed methods (via extension or wrapper class):**
- `centerOnUser(Position position)` - animates camera to user position at zoom 15
- `fitRouteBounds(List<LatLng> shapePoints)` - calculates bounding box of the route shape and fits camera to show entire route with padding
- `animateToPosition(LatLng target, {double? zoom})` - smooth camera animation to any point

**Uses `flutter_map_animations` package** for smooth animated camera transitions instead of instant jumps.

---

### Search Feature

#### `lib/features/search/search_screen.dart`

**Purpose:** Full-screen search interface, presented modally over the map.

**Layout:**
1. `CupertinoPageScaffold` with nav bar containing a cancel button
2. `CupertinoSearchTextField` at top, auto-focused, auto-selected
3. `CupertinoSlidingSegmentedControl` for tabs: "Routes" | "Stops"
4. When query empty: shows `RecentSearches` widget
5. When query non-empty: shows `SearchResultTile` list

**State:**
- Writes to `searchQueryProvider` with 300ms debounce
- Reads `searchResultsProvider` for results
- On result tap: sets `selectedRouteProvider` (for routes) or pushes `StopDetailScreen` (for stops), then pops this screen

---

#### `lib/features/search/widgets/search_result_tile.dart`

**Purpose:** A single search result row.

**Route result visual:**
- Left: colored badge with route short name
- Right: route long name
- Chevron right indicator

**Stop result visual:**
- Left: `CupertinoIcons.location_solid` icon
- Center: stop name
- Right: stop code in gray text
- Chevron right indicator

---

#### `lib/features/search/widgets/recent_searches.dart`

**Purpose:** Shows previously viewed routes when the search field is empty.

**Data source:** `historyProvider` (most recent 10 entries)

**Visual:** Simple list with route badges and names, "Recent" section header

---

#### `lib/features/search/widgets/search_filters.dart`

**Purpose:** Segmented control to filter search results by transit type.

**Segments:** All | Bus | SkyTrain | SeaBus

**Maps to GTFS route_type:** All = no filter, Bus = 3, SkyTrain = 1, SeaBus = 4

---

### Route Detail Feature

#### `lib/features/route_detail/route_detail_screen.dart`

**Purpose:** Separate full screen showing all information about a specific route. Pushed from map or search.

**Arguments:** `String routeId`

**Layout:**
1. `CupertinoPageScaffold` with back button
2. `RouteInfoHeader` at top
3. Mini map showing the route polyline + all active buses on it
4. "Active Buses" section: list of `BusListTile` widgets
5. "Service Alerts" section (if any alerts for this route): list of `AlertCard` widgets

**State consumed:**
- `routeProvider(routeId)` - route name and info
- `vehiclesForRouteProvider(routeId)` - active buses
- `routeShapeProvider(routeId)` - polyline for mini map
- `alertsForRouteProvider(routeId)` - alerts for this route

---

#### `lib/features/route_detail/widgets/route_info_header.dart`

**Purpose:** Top section of route detail screen.

**Visual:**
- Large colored badge with route number
- Route long name
- Direction info (headsign)
- Active bus count: "5 buses active"

---

#### `lib/features/route_detail/widgets/bus_list_tile.dart`

**Purpose:** A card representing one active bus on the route.

**Visual:**
- Vehicle label/number
- Current position description (nearest stop name)
- Speed
- Delay indicator (on time / late / early)
- Tap: centers main map on this bus and pops back

---

#### `lib/features/route_detail/widgets/eta_timeline.dart`

**Purpose:** Vertical timeline showing a bus's upcoming stops with predicted arrival times.

**Visual:**
- Vertical line with dots at each stop
- Current bus position highlighted with filled circle
- Past stops grayed out
- Future stops show predicted arrival time
- Delay shown in red/green text next to each time

---

### Stop Detail Feature

#### `lib/features/stop_detail/stop_detail_screen.dart`

**Purpose:** Shows all upcoming bus arrivals at a specific stop.

**Arguments:** `String stopId`

**Layout:**
1. `CupertinoPageScaffold`
2. `StopInfoHeader` with stop name, code, and favorite button
3. List of `ArrivalListTile` widgets sorted by ETA
4. `SetAlertButton` on each arrival

**State consumed:**
- `stopProvider(stopId)` - stop info
- `etasForStopProvider(stopId)` - upcoming arrivals
- `isFavoriteProvider(stopId)` - favorite status

---

#### `lib/features/stop_detail/widgets/arrival_list_tile.dart`

**Visual:**
- Route number badge (colored)
- Headsign/destination
- Predicted arrival countdown: "2 min", "15 min"
- Delay indicator: green "On time" or red "+3 min late"
- Tap: selects route and navigates back to map

---

#### `lib/features/stop_detail/widgets/stop_info_header.dart`

**Visual:**
- Stop name (large text)
- Stop code: "#51479"
- Star button to toggle favorite (filled when favorited)

---

#### `lib/features/stop_detail/widgets/set_alert_button.dart`

**Purpose:** Button to set a notification for when a specific bus approaches this stop.

**Behavior:**
- On tap: shows `CupertinoActionSheet` with options: "1 min away", "2 min away", "5 min away", "10 min away"
- Selection adds a `BusAlert` to `busAlertSettingsProvider`
- Shows confirmation toast

---

### Favorites Feature

#### `lib/features/favorites/favorites_screen.dart`

**Purpose:** List of user's bookmarked stops with live arrival data.

**Layout:**
1. `CupertinoPageScaffold` with "Favorites" title
2. List of `FavoriteStopTile` widgets
3. Empty state: centered text "No favorite stops yet" with instruction

**Swipe actions:** Swipe left to delete (with Cupertino destructive action confirmation)

---

#### `lib/features/favorites/widgets/favorite_stop_tile.dart`

**Visual:**
- Stop name
- Next 2-3 bus arrivals with route badges and countdown times
- Tap: navigates to `StopDetailScreen`

---

### History Feature

#### `lib/features/history/history_screen.dart`

**Purpose:** List of previously viewed routes, grouped by date.

**Layout:**
1. `CupertinoPageScaffold`
2. "Clear" button in nav bar
3. Grouped list: "Today", "Yesterday", date headers
4. List of `HistoryEntryTile` widgets

---

#### `lib/features/history/widgets/history_entry_tile.dart`

**Visual:**
- Route number badge + route name
- Time viewed (e.g., "2:30 PM")
- Tap: sets `selectedRouteProvider` to this route and pops back to map

---

### Alerts Feature

#### `lib/features/alerts/alerts_screen.dart`

**Purpose:** Full list of active TransLink service alerts. Reached from the bell icon on the map screen.

**Layout:**
1. `CupertinoPageScaffold` with "Service Alerts" title
2. Filter: optional route filter dropdown
3. List of `AlertCard` widgets sorted by severity then recency
4. Empty state: "No active service alerts"

---

#### `lib/features/alerts/widgets/alert_card.dart`

**Visual:**
- Severity-colored left border (yellow/orange/red based on effect)
- Header text (bold)
- Description text (expandable)
- Cause and effect tags
- Affected routes as colored chips
- Active period dates

---

### Settings Feature

#### `lib/features/settings/settings_screen.dart`

**Purpose:** App configuration and information.

**Layout:** `CupertinoPageScaffold` with grouped `CupertinoListSection`s:

**Section 1: Appearance**
- `ThemeToggle` - Dark / Light / System

**Section 2: Notifications**
- `NotificationSettings` - enable/disable toggle, default threshold

**Section 3: Data**
- "Refresh Transit Data" - forces GTFS static re-download
- "Last updated: {date}" info text
- "Clear Cache" - clears SQLite and re-downloads

**Section 4: About**
- `AboutSection` - app version, TransLink attribution, OSM attribution

---

#### `lib/features/settings/widgets/theme_toggle.dart`

**Widget:** `CupertinoSlidingSegmentedControl<Brightness?>` with three options:
- Light
- Dark
- System (null, follows device setting)

Writes to `themeProvider`.

---

#### `lib/features/settings/widgets/notification_settings.dart`

**Widgets:**
- `CupertinoSwitch` to enable/disable notifications globally
- `CupertinoPicker` for default alert threshold (1, 2, 5, 10 minutes)
- Persisted in `SharedPreferences`

---

#### `lib/features/settings/widgets/about_section.dart`

**Content:**
- App name: "bussin!"
- Version: from `pubspec.yaml`
- TransLink attribution text (required by ToS, displayed in full)
- OpenStreetMap attribution
- Licenses button (opens Flutter licenses page)

---

### Navigation

#### `lib/navigation/app_router.dart`

**Named routes:**

| Route | Screen | Arguments |
|---|---|---|
| `/` | `MainScaffold` (tab bar + map) | none |
| `/search` | `SearchScreen` | optional initial query |
| `/route/:routeId` | `RouteDetailScreen` | `routeId` (String) |
| `/stop/:stopId` | `StopDetailScreen` | `stopId` (String) |
| `/favorites` | `FavoritesScreen` | none |
| `/history` | `HistoryScreen` | none |
| `/alerts` | `AlertsScreen` | none |
| `/settings` | `SettingsScreen` | none |

---

#### `lib/navigation/bottom_nav_bar.dart`

**Purpose:** Bottom tab bar with 3 tabs.

**Tabs:**

| Index | Label | Icon | Screen |
|---|---|---|---|
| 0 | Map | `CupertinoIcons.map` | `MapScreen` |
| 1 | Favorites | `CupertinoIcons.star` | `FavoritesScreen` |
| 2 | Settings | `CupertinoIcons.gear` | `SettingsScreen` |

**Alert badge:** The Map tab's nav bar contains an alerts bell icon button with a red badge showing `activeAlertCountProvider` count. Tapping it pushes `AlertsScreen`.

**History button:** The Map tab's nav bar contains a clock icon button. Tapping it pushes `HistoryScreen`.

---

### Proto Definition

#### `proto/gtfs-realtime.proto`

**Source:** Download from `https://developers.google.com/static/transit/gtfs-realtime/gtfs-realtime.proto`

**Purpose:** Defines the protobuf schema for all three GTFS-RT feeds. Used to generate Dart classes.

**Generation command:**
```bash
protoc --dart_out=lib/data/models/ proto/gtfs-realtime.proto
```

**Prerequisites:** Install `protoc` compiler and `protoc_plugin` Dart package globally:
```bash
dart pub global activate protoc_plugin
```

---

## Data Flow Architecture

```
+-----------------------------------------------------------+
|                       UI LAYER                             |
|  MapScreen, SearchScreen, StopDetail, RouteDetail, etc.   |
|  (ConsumerWidget / ConsumerStatefulWidget)                 |
|  reads from providers via ref.watch()                      |
+---------------------------+-------------------------------+
                            |
                            v
+-----------------------------------------------------------+
|                   PROVIDERS (Riverpod)                      |
|                                                            |
|  Stream Providers (polling):     State Providers:           |
|  - allVehiclePositions (10s)     - selectedRoute            |
|  - tripUpdates (30s)             - searchQuery              |
|  - serviceAlerts (60s)           - themeMode                |
|  - currentLocation (stream)                                 |
|                                                            |
|  Async Notifier Providers:       Derived Providers:         |
|  - favorites                     - vehiclesForRoute         |
|  - history                       - etasForStop              |
|  - busAlertSettings              - nearbyStops              |
|                                  - searchResults            |
|                                  - activeAlertCount         |
+---------------------------+-------------------------------+
                            |
                            v
+-----------------------------------------------------------+
|                   REPOSITORY LAYER                          |
|                                                            |
|  VehicleRepository       RouteRepository                   |
|  TripUpdateRepository    StopRepository                    |
|  AlertRepository         ShapeRepository                   |
|  FavoritesRepository     HistoryRepository                 |
|                                                            |
|  - Fetches raw data from datasources                       |
|  - Parses protobuf binary to FeedMessage                   |
|  - Maps protobuf entities to domain models                 |
|  - In-memory caching of last successful result             |
+---------------------------+-------------------------------+
                            |
              +-------------+-------------+
              |                           |
              v                           v
+-------------------------+  +---------------------------+
|   REMOTE DATASOURCES    |  |    LOCAL DATASOURCES      |
|                         |  |                           |
|  TranslinkApiService    |  |  LocalDatabaseService     |
|  - HTTP GET raw bytes   |  |  - SQLite CRUD            |
|  - Returns Uint8List    |  |  - Bulk CSV import        |
|                         |  |                           |
|  GtfsStaticService      |  |  LocationService          |
|  - Download ZIP         |  |  - GPS position stream    |
|  - Extract CSVs         |  |                           |
|  - Parse to maps        |  |  NotificationService      |
|                         |  |  - Local push alerts      |
+------------+------------+  +---------------------------+
             |
             v
+-------------------------+
|  TRANSLINK GTFS-RT V3   |
|  (protobuf endpoints)   |
|  + GTFS Static (ZIP)    |
+-------------------------+
```

---

## Real-Time Polling Architecture

```
App starts
  |
  +-- Initialize SQLite database
  |
  +-- Initialize notification channels
  |
  +-- Check GTFS Static freshness
  |     |
  |     +-- If stale (>24h) or first launch:
  |     |     Download google_transit.zip (~15MB)
  |     |     Extract CSV files
  |     |     Clear existing GTFS tables
  |     |     Bulk insert routes, stops, trips, stop_times, shapes
  |     |     Record download timestamp
  |     |
  |     +-- If fresh: skip, use cached SQLite data
  |
  +-- Request GPS permission
  |     |
  |     +-- Granted: start position stream (10m distance filter)
  |     +-- Denied: fall back to Vancouver center coordinates
  |
  +-- Start Vehicle Position Polling (10s)
  |     Loop:
  |       HTTP GET gtfsposition -> Uint8List
  |       FeedMessage.fromBuffer(bytes)
  |       Map entities to VehiclePositionModel list
  |       Emit to allVehiclePositionsProvider
  |       UI redraws bus markers (with animation)
  |       Wait 10 seconds
  |
  +-- Start Trip Update Polling (30s)
  |     Loop:
  |       HTTP GET gtfsrealtime -> Uint8List
  |       FeedMessage.fromBuffer(bytes)
  |       Map entities to TripUpdateModel list
  |       Emit to tripUpdatesProvider
  |       Check bus alert thresholds -> fire notifications if met
  |       Wait 30 seconds
  |
  +-- Start Alert Polling (60s)
        Loop:
          HTTP GET gtfsalerts -> Uint8List
          FeedMessage.fromBuffer(bytes)
          Map entities to ServiceAlertModel list
          Emit to serviceAlertsProvider
          Update badge count
          Wait 60 seconds
```

**Marker animation between polls:**
When new vehicle positions arrive every 10 seconds, instead of jumping markers to new positions, the `BusMarkerLayer` widget:
1. Stores previous position for each vehicleId
2. Creates an `AnimationController` with 2-second duration
3. On each tick, interpolates latitude and longitude between old and new position
4. Renders marker at interpolated position
5. Result: buses appear to glide smoothly along the road

---

## SQLite Schema

```sql
-- ============================================================
-- GTFS Static Data (refreshed periodically from ZIP download)
-- ============================================================

CREATE TABLE gtfs_routes (
  route_id TEXT PRIMARY KEY,
  route_short_name TEXT NOT NULL,
  route_long_name TEXT NOT NULL,
  route_type INTEGER NOT NULL,
  route_color TEXT
);

CREATE TABLE gtfs_stops (
  stop_id TEXT PRIMARY KEY,
  stop_name TEXT NOT NULL,
  stop_lat REAL NOT NULL,
  stop_lon REAL NOT NULL,
  stop_code TEXT
);
CREATE INDEX idx_stops_code ON gtfs_stops(stop_code);
CREATE INDEX idx_stops_name ON gtfs_stops(stop_name);

CREATE TABLE gtfs_trips (
  trip_id TEXT PRIMARY KEY,
  route_id TEXT NOT NULL,
  service_id TEXT NOT NULL,
  trip_headsign TEXT,
  direction_id INTEGER,
  shape_id TEXT,
  FOREIGN KEY (route_id) REFERENCES gtfs_routes(route_id)
);
CREATE INDEX idx_trips_route ON gtfs_trips(route_id);
CREATE INDEX idx_trips_shape ON gtfs_trips(shape_id);

CREATE TABLE gtfs_stop_times (
  trip_id TEXT NOT NULL,
  stop_id TEXT NOT NULL,
  arrival_time TEXT NOT NULL,
  departure_time TEXT NOT NULL,
  stop_sequence INTEGER NOT NULL,
  PRIMARY KEY (trip_id, stop_sequence),
  FOREIGN KEY (trip_id) REFERENCES gtfs_trips(trip_id),
  FOREIGN KEY (stop_id) REFERENCES gtfs_stops(stop_id)
);
CREATE INDEX idx_stop_times_stop ON gtfs_stop_times(stop_id);

CREATE TABLE gtfs_shapes (
  shape_id TEXT NOT NULL,
  shape_pt_lat REAL NOT NULL,
  shape_pt_lon REAL NOT NULL,
  shape_pt_sequence INTEGER NOT NULL,
  PRIMARY KEY (shape_id, shape_pt_sequence)
);

-- ============================================================
-- User Data (persists across app updates)
-- ============================================================

CREATE TABLE favorites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  stop_id TEXT NOT NULL UNIQUE,
  stop_name TEXT NOT NULL,
  stop_lat REAL NOT NULL,
  stop_lon REAL NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE route_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  route_id TEXT NOT NULL,
  route_short_name TEXT NOT NULL,
  route_long_name TEXT NOT NULL,
  viewed_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_history_route ON route_history(route_id);
CREATE INDEX idx_history_date ON route_history(viewed_at DESC);
```

---

## Key Implementation Notes

### Protobuf Parsing (Critical)

The GTFS-RT V3 API returns binary protobuf data, NOT JSON. This is the single most important implementation detail:

1. HTTP GET returns `response.bodyBytes` as `Uint8List`
2. Parse with `FeedMessage.fromBuffer(bytes)` (generated protobuf class)
3. Access `feedMessage.entity` which is a `List<FeedEntity>`
4. Each `FeedEntity` has optional fields: `tripUpdate`, `vehicle`, `alert`
5. Check with `entity.hasVehicle()`, `entity.hasTripUpdate()`, `entity.hasAlert()` before accessing

Do NOT try to decode the response as a string or JSON. It will fail.

### GTFS Static Data Lifecycle

1. On first launch: download `google_transit.zip` (~15MB)
2. Extract to app documents directory using `archive` package
3. Parse each CSV file using `csv` package (first row = headers)
4. Bulk insert into SQLite tables using batch API (1000 rows per batch)
5. Store download timestamp in `SharedPreferences`
6. On subsequent launches: check if >24h since last download, refresh if stale
7. User can force refresh from Settings screen
8. TransLink typically updates this file weekly (by Friday)

### Route Shape Matching

GTFS data links routes to shapes through trips:
- `routes.txt` has `route_id`
- `trips.txt` has `trip_id`, `route_id`, `shape_id`
- `shapes.txt` has `shape_id`, `shape_pt_lat`, `shape_pt_lon`, `shape_pt_sequence`

To get a route's polyline:
1. Find any trip for the route: `SELECT shape_id FROM gtfs_trips WHERE route_id = ? LIMIT 1`
2. Load shape points: `SELECT * FROM gtfs_shapes WHERE shape_id = ? ORDER BY shape_pt_sequence`
3. Convert to `List<LatLng>` for the polyline layer

### Search Logic

1. Debounce input by 300ms to avoid excessive database queries
2. Search routes: `WHERE route_short_name LIKE '%query%' OR route_long_name LIKE '%query%'`
3. Search stops: `WHERE stop_name LIKE '%query%' OR stop_code = 'query'`
4. Combine results: routes first, then stops
5. Limit to 20 total results for performance
6. Empty query: show recent history instead

### Bus Arrival Notifications (Foreground Only)

1. User sets alert: "Notify me when Route 49 bus is 5 min from stop #51479"
2. This registers a `BusAlert` in `busAlertSettingsProvider`
3. On each trip update poll (every 30s), the notifier checks all active alerts:
   - For each alert, find the ETA for the matching route at the matching stop
   - If `predictedArrival - now <= thresholdMinutes`, fire notification
   - Auto-remove the alert after notification fires
4. Notifications only work while the app is in foreground or background (not killed)
5. Uses `flutter_local_notifications` with platform-appropriate channels

### Nearby Stops Detection

1. `nearbyStopsProvider` combines GPS position + all stops
2. Uses Haversine formula to calculate distance to each stop
3. Filters to stops within 500m radius
4. Sorts by distance ascending
5. Recalculates when GPS position changes (throttled by geolocator's 10m distance filter)
6. Displayed in the `NearbyStopsSheet` bottom sheet on the map screen

### TransLink Attribution (Required by Terms of Service)

Per TransLink's GTFS Data Terms of Service, the app MUST display this text prominently:

> "Route and arrival data used in this product or service is provided by permission of TransLink. TransLink assumes no responsibility for the accuracy or currency of the Data used in this product or service."

This is displayed in:
- Settings > About section (full text)
- Map attribution widget (short "TransLink" text)

---

## Performance Considerations

| Concern | Strategy |
|---|---|
| Marker count | TransLink runs ~1500 active vehicles. flutter_map handles this fine. If needed, add clustering when zoomed out. |
| Protobuf parse time | Vehicle position feed is ~200-500KB. Parsing takes ~50ms on modern devices. |
| SQLite query speed | Indexed columns (stop_code, stop_name, route_id, shape_id) ensure <50ms query times. |
| Tile caching | flutter_map caches tiles automatically. Consider `flutter_map_cache` plugin for explicit offline tile storage. |
| Memory | Keep only latest poll results in memory. Do not accumulate historical positions. |
| Battery | 10s polling is aggressive. Reduce to 30s when app is backgrounded using `WidgetsBindingObserver`. |
| Static data import | `stop_times.txt` can have millions of rows. Batch insert in chunks of 1000 within a single transaction. Show progress indicator during import. |
| Search performance | In-memory stop list (~8000 stops) for nearby calculation. SQLite LIKE queries for text search with LIMIT 20. |

---

## Testing Strategy

| Layer | Tool | What to Test |
|---|---|---|
| Models | `flutter_test` | Freezed equality, copyWith, serialization |
| Protobuf parsing | `flutter_test` | Parse sample protobuf bytes, verify field extraction |
| Repositories | `flutter_test` + `mockito` | Mock API service, verify protobuf-to-model mapping, error handling, caching |
| Providers | `flutter_test` + Riverpod `ProviderContainer` | State transitions, polling behavior, derived provider correctness |
| Widgets | `flutter_test` (widget tests) | UI renders correctly for each state (loading, data, error), interactions work |
| Integration | `integration_test` package | Full flows: launch -> search -> select route -> view on map -> tap bus -> see details |

---

## Build and Run Commands

```bash
# 1. Create Flutter project (run once)
flutter create --org com.bussin --project-name bussin .

# 2. Install dependencies
flutter pub add flutter_riverpod riverpod_annotation flutter_map latlong2 \
  geolocator protobuf http sqflite path_provider archive csv \
  flutter_local_notifications shared_preferences freezed_annotation \
  json_annotation cupertino_icons flutter_map_animations url_launcher \
  permission_handler connectivity_plus intl

# 3. Install dev dependencies
flutter pub add --dev build_runner riverpod_generator freezed \
  json_serializable flutter_lints mockito

# 4. Download and compile protobuf
#    (see setup-guide.md for protoc installation)
protoc --dart_out=lib/data/models/ proto/gtfs-realtime.proto

# 5. Run code generation (freezed, riverpod, json_serializable)
dart run build_runner build --delete-conflicting-outputs

# 6. Run the app
flutter run

# 7. Run tests
flutter test

# 8. Build release APK (Android)
flutter build apk --release --dart-define=TRANSLINK_API_KEY=your_key_here

# 9. Build release IPA (iOS)
flutter build ipa --release --dart-define=TRANSLINK_API_KEY=your_key_here
```
