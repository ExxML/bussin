<div align="center">

<img src="assets/app_icon_white.png" alt="bussin! Icon" width="120" height="120">

# bussin!

A real-time Vancouver bus tracking app that shows live vehicle positions, ETAs, service alerts, and nearby stops. Built bus-first so you can check arrivals fast and reliably.

[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white)](https://dart.dev/)
[![Google Maps](https://img.shields.io/badge/Google_Maps-34A853?logo=google-maps&logoColor=white)](https://www.google.com/maps)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-orange.svg)](https://www.gnu.org/licenses/gpl-3.0)

</div>

## 📑 Table of Contents

- [✨ Features](#-features)
- [🛠️ Tech Stack](#️-tech-stack)
- [📁 Project Structure](#-project-structure)
- [🚀 Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [App Setup](#app-setup)
- [🏢 Deployment](#-deployment)
- [🔧 Configuration](#-configuration)
- [📡 API Endpoints](#-api-endpoints)
- [📊 Data Sources](#-data-sources)
- [📝 License](#-license)

## ✨ Features

- **Live bus tracking**: Display real-time TransLink vehicle positions on an interactive map.
- **ETAs / predictions**: Show arrival and departure predictions from GTFS-RT trip updates.
- **Service alerts**: View current disruptions, detours, and cancellations from GTFS-RT alerts.
- **Route & stop search**: Search by route or stop number and jump directly to details.
- **Nearby stops**: Use device location to show stops around you.
- **Favorites**: Save frequently used stops for quick access.
- **History**: Keep a lightweight history of recently viewed routes.
- **Offline-friendly caching**: Cache GTFS static data locally in SQLite to keep searches snappy.
- **Arrival notifications**: Optional local notifications for bus arrival alerts.
- **Light/Dark theme**: Theme toggle with persistent preference.

## 🛠️ Tech Stack

### Mobile App

- **Language**: Dart
- **Framework**: Flutter
- **Maps**:
  - `google_maps_flutter` (Google Maps SDK)
- **Location**: `geolocator` + `permission_handler`
- **Networking**: `http`
- **Serialization**:
  - Protocol Buffers (`protobuf`) for GTFS-RT v3 feeds
  - `freezed` / `json_serializable` for app models
- **Local storage**:
  - SQLite (`sqflite`) for GTFS static caching + user data
  - `shared_preferences` for settings
- **Notifications**: `flutter_local_notifications`

## 📁 Project Structure

```
bussin/
├── android/                      # Android platform integration (Kotlin/Gradle)
├── assets/                       # App assets (icons, images)
│   └── app_icon_white.png
├── lib/
│   ├── main.dart                 # App entry point (DB + notifications init)
│   ├── app.dart                  # Root MaterialApp + theme + routes
│   ├── core/                     # Constants, theme, shared errors/utils
│   ├── data/                     # Datasources, models, repositories
│   ├── features/                 # Feature UI (map, favorites, alerts, etc.)
│   ├── navigation/               # Router + bottom navigation scaffold
│   └── providers/                # Riverpod providers (vehicles, alerts, location...)
├── protos/                       # GTFS-RT .proto schema
├── pubspec.yaml                  # Flutter deps + assets
├── architecture.md               # Detailed architecture reference
└── setup-guide.md                # Setup steps (API key, protobuf tooling, platform config)
```

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** (install `flutter`; check with `flutter doctor -v` should be clean)
- **Dart** (bundled with Flutter)
- **A Google Maps SDK API Key** (required for map functionality)
- **A TransLink API key** (required for GTFS-RT v3 endpoints)

### App Setup

1. Install dependencies:
   ```bash
   flutter pub get
   ```

## 🏢 Deployment

This repository builds a **mobile app** (Android/iOS).

- **Android**:
  - Build APK:
    ```bash
    flutter build apk
    ```
  - Build App Bundle (Play Store):
    ```bash
    flutter build appbundle
    ```

- **iOS** (macOS required):
  - Build iOS:
    ```bash
    flutter build ios
    ```

## 🔧 Configuration

### TransLink API Key

Go to the Settings tab in the app and follow the simple instructions to get a free permanent Translink API token.

## 📡 API Endpoints

The app consumes TransLink GTFS-RT v3 endpoints, which return **Protocol Buffer (binary)** payloads (not JSON). These are parsed using `FeedMessage.fromBuffer(bytes)`.

### Vehicle Positions

- **GET** `https://gtfsapi.translink.ca/v3/gtfsposition?apikey={API_KEY}`
- **Purpose**: Live vehicle latitude/longitude + heading/speed.

### Trip Updates (ETAs)

- **GET** `https://gtfsapi.translink.ca/v3/gtfsrealtime?apikey={API_KEY}`
- **Purpose**: Arrival/departure predictions and delays.

### Service Alerts

- **GET** `https://gtfsapi.translink.ca/v3/gtfsalerts?apikey={API_KEY}`
- **Purpose**: Disruptions, detours, cancellations.

## 📊 Data Sources

- **Real-time (GTFS-RT v3, protobuf)**: TransLink Open API endpoints for vehicle positions, trip updates, and alerts.
- **Static schedules (GTFS Static, zip of CSV)**: Used to cache routes/stops/shapes locally for fast search and display.
- **Maps**: Google Maps (via `google_maps_flutter`).

## 📝 License

This project is licensed under the GNU General Public License v3.0.