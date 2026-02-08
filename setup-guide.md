# bussin! - Setup Guide and Reference

This document covers environment setup, API key registration, platform configuration, and external references that are separate from the core architecture.

---

## TransLink API Key Registration

The app requires a TransLink API key to access GTFS-RT V3 endpoints. The old RTTI API was retired on December 3, 2024.

### Steps to Register

1. Go to the TransLink developer portal: `https://www.translink.ca/about-us/doing-business-with-translink/app-developer-resources`
2. Navigate to "Open API" or GTFS Realtime section
3. Register for an API key (free for non-commercial use)
4. TransLink may require you to provide:
   - Your name and organization
   - How the data will be used
   - Whether usage is commercial or non-commercial
5. Save your API key securely. Do NOT commit it to version control.

### API Key Usage

Pass the key as a query parameter on every request:
```
https://gtfsapi.translink.ca/v3/gtfsposition?apikey=YOUR_KEY_HERE
```

### Storing the API Key in the App

**Option A: Compile-time define (recommended for builds)**
```bash
flutter run --dart-define=TRANSLINK_API_KEY=your_key_here
flutter build apk --dart-define=TRANSLINK_API_KEY=your_key_here
```

Access in code:
```dart
const apiKey = String.fromEnvironment('TRANSLINK_API_KEY');
```

**Option B: .env file (for local development)**
Create a `.env` file in the project root (already in `.gitignore`):
```
TRANSLINK_API_KEY=your_key_here
```
Use the `flutter_dotenv` package to load it. However, `--dart-define` is preferred since `.env` files can accidentally leak.

### .env.example Template

```
# Copy this file to .env and fill in your keys
# DO NOT commit .env to version control

TRANSLINK_API_KEY=your_translink_api_key_here
```

---

## Flutter Environment Setup

### Prerequisites

| Tool | Version | Install |
|---|---|---|
| Flutter SDK | >= 3.24.0 | `https://docs.flutter.dev/get-started/install` |
| Dart SDK | >= 3.5.0 | Bundled with Flutter |
| Android Studio | Latest | `https://developer.android.com/studio` |
| Xcode | >= 15.0 | Mac App Store (iOS builds only) |
| VS Code (optional) | Latest | With Flutter and Dart extensions |
| protoc | >= 3.19.0 | See protobuf setup section below |

### Verify Installation

```bash
flutter doctor -v
```

All checks should pass for your target platforms (Android and iOS).

---

## Protobuf Compiler Setup

The GTFS-RT API returns Protocol Buffer binary data. You need `protoc` to generate Dart classes from the `.proto` schema file.

### Step 1: Install protoc

**Windows (using Chocolatey):**
```bash
choco install protoc
```

**Windows (manual):**
1. Download from `https://github.com/protocolbuffers/protobuf/releases`
2. Get `protoc-{version}-win64.zip`
3. Extract and add the `bin` directory to your system PATH

**macOS:**
```bash
brew install protobuf
```

**Linux:**
```bash
sudo apt install protobuf-compiler
```

### Step 2: Install Dart protoc plugin

```bash
dart pub global activate protoc_plugin
```

Ensure `~/.pub-cache/bin` (or `%APPDATA%\Pub\Cache\bin` on Windows) is in your PATH.

### Step 3: Download the GTFS-RT proto file

```bash
mkdir proto
curl -o proto/gtfs-realtime.proto https://developers.google.com/static/transit/gtfs-realtime/gtfs-realtime.proto
```

Or download manually from `https://developers.google.com/static/transit/gtfs-realtime/gtfs-realtime.proto` and save to `proto/gtfs-realtime.proto`.

### Step 4: Generate Dart classes

```bash
protoc --dart_out=lib/data/models/ proto/gtfs-realtime.proto
```

This generates:
- `lib/data/models/gtfs_realtime.pb.dart` (main classes)
- `lib/data/models/gtfs_realtime.pbenum.dart` (enums)
- `lib/data/models/gtfs_realtime.pbjson.dart` (JSON helpers)
- `lib/data/models/gtfs_realtime.pbserver.dart` (server stubs)

Only `gtfs_realtime.pb.dart` and `gtfs_realtime.pbenum.dart` are actively used by the app, but all generated files should be kept.

### Step 5: Re-generate when proto changes

If you update the `.proto` file, re-run Step 4. The generated files should NOT be manually edited.

---

## Platform-Specific Configuration

### Android

#### `android/app/src/main/AndroidManifest.xml`

Add these permissions inside `<manifest>`:
```xml
<!-- Internet access for API calls and map tiles -->
<uses-permission android:name="android.permission.INTERNET" />

<!-- GPS location -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Background location (for notifications when app is backgrounded) -->
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<!-- Notifications -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- Vibration for notifications -->
<uses-permission android:name="android.permission.VIBRATE" />

<!-- Keep screen on while tracking (optional) -->
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

#### `android/app/build.gradle`

Set minimum SDK version:
```gradle
android {
    defaultConfig {
        minSdkVersion 21  // Required by geolocator and sqflite
        targetSdkVersion 34
    }
}
```

#### Notification Channel Setup (in NotificationService)

Android 8+ requires notification channels:
```dart
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'bus_alerts',           // id
  'Bus Alerts',           // name
  description: 'Notifications for bus arrival alerts',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);
```

### iOS

#### `ios/Runner/Info.plist`

Add these keys:
```xml
<!-- Location permission descriptions (REQUIRED) -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>bussin! needs your location to show nearby stops and your position on the map.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>bussin! needs your location to notify you when your bus is approaching.</string>

<!-- Notification permission (requested at runtime, but description recommended) -->
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
  <string>fetch</string>
</array>
```

#### `ios/Podfile`

Set minimum iOS version:
```ruby
platform :ios, '14.0'
```

#### App Transport Security

OpenStreetMap tiles use HTTPS by default, so no ATS exceptions are needed. The TransLink API also uses HTTPS.

---

## Code Generation Workflow

The project uses three code generators that run together:

| Generator | Package | Generates |
|---|---|---|
| `freezed` | `freezed` + `freezed_annotation` | Immutable model classes with equality, copyWith, pattern matching |
| `json_serializable` | `json_serializable` + `json_annotation` | fromJson/toJson methods |
| `riverpod_generator` | `riverpod_generator` + `riverpod_annotation` | Provider boilerplate from @riverpod annotations |

### Running Code Generation

```bash
# One-time build
dart run build_runner build --delete-conflicting-outputs

# Watch mode (auto-rebuilds on file changes)
dart run build_runner watch --delete-conflicting-outputs
```

### Generated Files

Generated files follow the pattern `*.g.dart` and `*.freezed.dart`. They are created next to their source files:
```
vehicle_position.dart           # You write this
vehicle_position.freezed.dart   # Generated by freezed
vehicle_position.g.dart         # Generated by json_serializable
```

These generated files SHOULD be committed to version control (they are needed for builds without running build_runner).

---

## GTFS Data Reference

### Static GTFS Files (from ZIP)

| File | Contents | Row Count (approx) |
|---|---|---|
| `routes.txt` | Route definitions (ID, name, type, color) | ~250 |
| `stops.txt` | Stop locations (ID, name, lat, lon, code) | ~8,000 |
| `trips.txt` | Trip definitions (links route to shape and schedule) | ~15,000 |
| `stop_times.txt` | Scheduled times at each stop for each trip | ~500,000+ |
| `shapes.txt` | Geographic path points for route polylines | ~300,000+ |
| `calendar.txt` | Service days (weekday/weekend schedules) | ~20 |
| `calendar_dates.txt` | Service exceptions (holidays) | ~100 |

### GTFS Route Types

| Type | Meaning | TransLink Examples |
|---|---|---|
| 0 | Tram / Light Rail | - |
| 1 | Subway / Metro | SkyTrain (Expo, Millennium, Canada Line) |
| 2 | Rail | West Coast Express |
| 3 | Bus | All bus routes |
| 4 | Ferry | SeaBus |

### GTFS-RT Feed Entity Types

Each `FeedEntity` in a protobuf `FeedMessage` contains one of:

| Field | Check Method | Data |
|---|---|---|
| `vehicle` | `entity.hasVehicle()` | Current position, bearing, speed, trip info |
| `tripUpdate` | `entity.hasTripUpdate()` | Per-stop arrival/departure predictions |
| `alert` | `entity.hasAlert()` | Service disruption info |

### Protobuf Field Reference (Key Fields)

**VehiclePosition:**
```
entity.vehicle.trip.tripId        -> String
entity.vehicle.trip.routeId       -> String
entity.vehicle.vehicle.id         -> String (vehicle ID)
entity.vehicle.vehicle.label      -> String (bus number)
entity.vehicle.position.latitude  -> double
entity.vehicle.position.longitude -> double
entity.vehicle.position.bearing   -> float (degrees, 0-360)
entity.vehicle.position.speed     -> float (m/s)
entity.vehicle.timestamp          -> uint64 (Unix seconds)
entity.vehicle.currentStopSequence -> uint32
```

**TripUpdate:**
```
entity.tripUpdate.trip.tripId     -> String
entity.tripUpdate.trip.routeId    -> String
entity.tripUpdate.timestamp       -> uint64
entity.tripUpdate.stopTimeUpdate  -> List<StopTimeUpdate>
  .stopSequence                   -> uint32
  .stopId                         -> String
  .arrival.time                   -> int64 (Unix seconds, predicted)
  .arrival.delay                  -> int32 (seconds, + = late, - = early)
  .departure.time                 -> int64
  .departure.delay                -> int32
```

**Alert:**
```
entity.alert.activePeriod         -> List<TimeRange>
  .start                          -> uint64 (Unix seconds)
  .end                            -> uint64
entity.alert.informedEntity       -> List<EntitySelector>
  .routeId                        -> String
  .stopId                         -> String
entity.alert.cause                -> Cause enum
entity.alert.effect               -> Effect enum
entity.alert.headerText           -> TranslatedString
  .translation[].text             -> String
  .translation[].language         -> String
entity.alert.descriptionText      -> TranslatedString
```

---

## Rate Limits and Fair Use

TransLink does not publicly document strict rate limits for the GTFS-RT V3 API, but the following are best practices:

| Guideline | Value |
|---|---|
| Vehicle position poll interval | 10 seconds minimum |
| Trip update poll interval | 30 seconds minimum |
| Alert poll interval | 60 seconds minimum |
| Reduce polling when backgrounded | 30 seconds for positions |
| Stop polling when screen off | Use WidgetsBindingObserver |
| Static data download | Once per 24 hours max |
| Concurrent connections | 1 per endpoint (sequential polling, not parallel) |

If the API returns 429 (Too Many Requests), implement exponential backoff: wait 10s, then 20s, then 40s before retrying.

---

## Useful External References

| Resource | URL |
|---|---|
| TransLink GTFS-RT V3 docs | `https://www.translink.ca/about-us/doing-business-with-translink/app-developer-resources/gtfs/gtfs-realtime` |
| TransLink GTFS Static data | `https://www.translink.ca/about-us/doing-business-with-translink/app-developer-resources/gtfs/gtfs-data` |
| GTFS-RT proto file | `https://developers.google.com/static/transit/gtfs-realtime/gtfs-realtime.proto` |
| GTFS-RT specification | `https://developers.google.com/transit/gtfs-realtime/` |
| GTFS Static reference | `https://developers.google.com/transit/gtfs/reference` |
| flutter_map docs | `https://docs.fleaflet.dev/` |
| flutter_map pub.dev | `https://pub.dev/packages/flutter_map` |
| Riverpod docs | `https://riverpod.dev/` |
| protobuf Dart package | `https://pub.dev/packages/protobuf` |
| protoc_plugin | `https://pub.dev/packages/protoc_plugin` |
| geolocator | `https://pub.dev/packages/geolocator` |
| sqflite | `https://pub.dev/packages/sqflite` |
| flutter_local_notifications | `https://pub.dev/packages/flutter_local_notifications` |
| freezed | `https://pub.dev/packages/freezed` |
| OpenStreetMap tile usage policy | `https://operations.osmfoundation.org/policies/tiles/` |

---

## OpenStreetMap Tile Usage Policy

The app uses free OpenStreetMap tiles. Per their usage policy:

1. Set a valid `User-Agent` / `userAgentPackageName` on tile requests (set to `com.bussin.app`)
2. Do not send excessive tile requests (flutter_map handles caching)
3. Display attribution: "OpenStreetMap contributors" (handled by `RichAttributionWidget`)
4. For heavy usage (many users), consider using a commercial tile provider or self-hosting tiles

---

## Project Initialization Commands (Full Sequence)

Run these in order to set up the project from scratch:

```bash
# 1. Navigate to project directory
cd "C:\Users\qwooz\Documents\HackTheCoast 2026\bussin"

# 2. Create Flutter project
flutter create --org com.bussin --project-name bussin .

# 3. Add all dependencies
flutter pub add flutter_riverpod riverpod_annotation flutter_map latlong2 geolocator protobuf http sqflite path_provider archive csv flutter_local_notifications shared_preferences freezed_annotation json_annotation cupertino_icons flutter_map_animations url_launcher permission_handler connectivity_plus intl

# 4. Add all dev dependencies
flutter pub add --dev build_runner riverpod_generator freezed json_serializable flutter_lints mockito

# 5. Create proto directory and download proto file
mkdir proto
curl -o proto/gtfs-realtime.proto https://developers.google.com/static/transit/gtfs-realtime/gtfs-realtime.proto

# 6. Install protoc (Windows - choose one method)
# Option A: Chocolatey
choco install protoc
# Option B: Manual download from https://github.com/protocolbuffers/protobuf/releases

# 7. Install Dart protoc plugin
dart pub global activate protoc_plugin

# 8. Generate protobuf Dart classes
protoc --dart_out=lib/data/models/ proto/gtfs-realtime.proto

# 9. Create the directory structure (all lib/ subdirectories)
# Then create all .dart files as specified in architecture.md

# 10. Run code generation for freezed + riverpod + json_serializable
dart run build_runner build --delete-conflicting-outputs

# 11. Create .env from template
copy .env.example .env
# Edit .env to add your TransLink API key

# 12. Run the app
flutter run --dart-define=TRANSLINK_API_KEY=your_key_here
```

---

## Git Configuration

### `.gitignore` Additions

The default Flutter `.gitignore` covers most cases. Add these:

```
# API keys and secrets
.env
*.env

# Generated protobuf files (optional - can commit these)
# lib/data/models/*.pb*.dart

# Build artifacts
*.apk
*.ipa
*.aab
```

### Recommended First Commit Structure

```
git add .
git commit -m "Initial project setup with architecture and dependencies"
```
