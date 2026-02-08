import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussin/core/constants/api_constants.dart';
import 'package:bussin/data/datasources/translink_api_service.dart';
import 'package:bussin/data/models/vehicle_position.dart';
import 'package:bussin/data/repositories/vehicle_repository.dart';
import 'package:bussin/providers/api_key_provider.dart';

/// ---------------------------------------------------------------------------
/// Vehicle Position Providers
/// ---------------------------------------------------------------------------
/// These providers expose real-time bus positions fetched from TransLink's
/// GTFS-RT V3 vehicle positions endpoint. Data is polled every 10 seconds
/// via a StreamProvider, and derived providers filter by route ID.
/// ---------------------------------------------------------------------------

/// Singleton instance of [TranslinkApiService] used across the app.
///
/// Watches the [apiKeyProvider] so that whenever the user changes their
/// API key in Settings, this service is automatically recreated with the
/// new key. All downstream providers (vehicle, trip update, alert) will
/// also rebuild since they watch this provider.
///
/// Provides the HTTP client for fetching raw protobuf bytes from
/// TransLink's GTFS-RT endpoints.
final translinkApiServiceProvider = Provider<TranslinkApiService>((ref) {
  // Watch the API key provider - when the key changes, this provider
  // will rebuild and create a new TranslinkApiService with the updated key.
  final apiKeyAsync = ref.watch(apiKeyProvider);

  // Get the API key value, falling back to compile-time constant
  // if the async provider hasn't loaded yet.
  final apiKey = apiKeyAsync.value ?? ApiConstants.translinkApiKey;

  final service = TranslinkApiService(apiKey: apiKey);

  // Clean up the HTTP client when the provider is disposed
  ref.onDispose(() => service.dispose());

  return service;
});

/// Singleton instance of [VehicleRepository] that depends on the API service.
///
/// Handles protobuf parsing and provides an in-memory cache for fallback
/// when network requests fail.
final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  final apiService = ref.watch(translinkApiServiceProvider);
  return VehicleRepository(apiService: apiService);
});

/// Stream of all vehicle positions, polling every 10 seconds.
///
/// Emits a new [List<VehiclePositionModel>] on each poll cycle.
/// Auto-disposes when no widget is watching, stopping the polling loop.
/// If a fetch fails, the repository's internal cache provides stale data
/// rather than an error (better UX for real-time tracking).
final allVehiclePositionsProvider =
    StreamProvider.autoDispose<List<VehiclePositionModel>>((ref) async* {
  // Keep polling as long as at least one widget is watching this provider
  while (true) {
    // Fetch the latest vehicle positions from the repository
    yield await ref.read(vehicleRepositoryProvider).getVehiclePositions();

    // Wait for the configured polling interval before the next fetch
    await Future.delayed(ApiConstants.vehiclePollInterval);
  }
});

/// Filtered vehicle positions for a specific route.
///
/// Returns an [AsyncValue<List<VehiclePositionModel>>] containing only
/// vehicles currently operating on the given [routeId].
/// Derives from [allVehiclePositionsProvider] so no additional API calls
/// are made -- just in-memory filtering.
final vehiclesForRouteProvider = Provider.autoDispose
    .family<AsyncValue<List<VehiclePositionModel>>, String>((ref, routeId) {
  // Watch the master vehicle stream and filter by route ID
  final allVehicles = ref.watch(allVehiclePositionsProvider);

  return allVehicles.whenData(
    (vehicles) =>
        vehicles.where((v) => v.routeId == routeId).toList(),
  );
});
