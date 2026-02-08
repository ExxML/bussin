import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussin/data/datasources/gtfs_static_service.dart';
import 'package:bussin/data/datasources/local_database_service.dart';
import 'package:bussin/providers/route_providers.dart';
import 'package:bussin/providers/stop_providers.dart';

/// ---------------------------------------------------------------------------
/// GTFS Data Initialization Provider
/// ---------------------------------------------------------------------------
/// Orchestrates downloading, parsing, and importing GTFS static data into
/// the local SQLite database on app startup.
///
/// Uses a single [Notifier] that manages its own [GtfsInitStatus] state,
/// avoiding cross-provider mutations during build (which Riverpod forbids).
///
/// The loading screen watches [gtfsDataInitProvider] and calls
/// [GtfsDataInitNotifier.initialize] once on startup.
/// ---------------------------------------------------------------------------

/// Status object tracking GTFS initialization progress.
class GtfsInitStatus {
  final bool isComplete;
  final bool hasError;
  final String message;
  final double progress; // 0.0 to 1.0
  final Object? error;

  const GtfsInitStatus({
    required this.isComplete,
    required this.message,
    this.hasError = false,
    this.progress = 0.0,
    this.error,
  });

  const GtfsInitStatus.initial()
      : isComplete = false,
        hasError = false,
        message = 'Checking transit data...',
        progress = 0.0,
        error = null;

  const GtfsInitStatus.complete()
      : isComplete = true,
        hasError = false,
        message = 'Ready!',
        progress = 1.0,
        error = null;
}

/// Single provider that manages GTFS data initialization.
///
/// Watch this from the loading screen. Call [initialize] once on startup.
final gtfsDataInitProvider =
    NotifierProvider<GtfsDataInitNotifier, GtfsInitStatus>(
        GtfsDataInitNotifier.new);

class GtfsDataInitNotifier extends Notifier<GtfsInitStatus> {
  @override
  GtfsInitStatus build() => const GtfsInitStatus.initial();

  /// Runs the full GTFS data initialization pipeline.
  ///
  /// Safe to call multiple times — subsequent calls after success are no-ops.
  Future<void> initialize() async {
    // Already done
    if (state.isComplete) return;

    final gtfsService = ref.read(gtfsStaticServiceProvider);
    final dbService = ref.read(localDatabaseServiceProvider);

    final stopwatch = Stopwatch()..start();

    try {
      // ---- Step 1: Check if data is stale ----
      state = const GtfsInitStatus(
        isComplete: false,
        message: 'Checking transit data...',
        progress: 0.05,
      );

      final isStale = await gtfsService.isDataStale();
      debugPrint('[GTFS-Init] isDataStale → $isStale');

      if (!isStale) {
        // Data is fresh — verify tables are not empty
        final routeCount = (await LocalDatabaseService.db
                .rawQuery('SELECT COUNT(*) as cnt FROM gtfs_routes'))
            .first['cnt'] as int;
        final stopCount = (await LocalDatabaseService.db
                .rawQuery('SELECT COUNT(*) as cnt FROM gtfs_stops'))
            .first['cnt'] as int;

        debugPrint('[GTFS-Init] Existing data: $routeCount routes, $stopCount stops');

        if (routeCount > 0 && stopCount > 0) {
          debugPrint('[GTFS-Init] Data is fresh and tables are populated — skipping download');
          state = const GtfsInitStatus.complete();
          return;
        }

        debugPrint('[GTFS-Init] WARNING: Data marked fresh but tables are empty! Re-downloading...');
      }

      // ---- Step 2: Download GTFS static ZIP ----
      state = const GtfsInitStatus(
        isComplete: false,
        message: 'Downloading transit data...',
        progress: 0.10,
      );
      debugPrint('[GTFS-Init] Downloading GTFS static ZIP...');

      await gtfsService.downloadAndExtractGtfsData();
      debugPrint('[GTFS-Init] Download complete (${stopwatch.elapsedMilliseconds}ms)');

      // ---- Step 3: Clear old data ----
      state = const GtfsInitStatus(
        isComplete: false,
        message: 'Preparing database...',
        progress: 0.25,
      );
      debugPrint('[GTFS-Init] Clearing old GTFS data...');
      await dbService.clearGtfsData();

      // ---- Step 4: Parse and import routes.txt ----
      state = const GtfsInitStatus(
        isComplete: false,
        message: 'Importing routes...',
        progress: 0.30,
      );
      debugPrint('[GTFS-Init] Parsing routes.txt...');
      final routeRows = await gtfsService.parseCsvFile('routes.txt');
      debugPrint('[GTFS-Init] Parsed routes.txt: ${routeRows.length} rows');

      final routeDbRows = routeRows.map((row) => <String, dynamic>{
        'route_id': row['route_id'] ?? '',
        'route_short_name': row['route_short_name'] ?? '',
        'route_long_name': row['route_long_name'] ?? '',
        'route_type': int.tryParse(row['route_type'] ?? '3') ?? 3,
        'route_color': row['route_color'],
      }).toList();
      await dbService.bulkInsertRoutes(routeDbRows);
      debugPrint('[GTFS-Init] ✓ Inserted ${routeDbRows.length} routes into SQLite');

      // ---- Step 5: Parse and import stops.txt ----
      state = const GtfsInitStatus(
        isComplete: false,
        message: 'Importing stops...',
        progress: 0.45,
      );
      debugPrint('[GTFS-Init] Parsing stops.txt...');
      final stopRows = await gtfsService.parseCsvFile('stops.txt');
      debugPrint('[GTFS-Init] Parsed stops.txt: ${stopRows.length} rows');

      final stopDbRows = stopRows.map((row) => <String, dynamic>{
        'stop_id': row['stop_id'] ?? '',
        'stop_name': row['stop_name'] ?? '',
        'stop_lat': double.tryParse(row['stop_lat'] ?? '0') ?? 0.0,
        'stop_lon': double.tryParse(row['stop_lon'] ?? '0') ?? 0.0,
        'stop_code': row['stop_code'],
      }).toList();
      await dbService.bulkInsertStops(stopDbRows);
      debugPrint('[GTFS-Init] ✓ Inserted ${stopDbRows.length} stops into SQLite');

      // Invalidate the stop repository in-memory cache
      ref.read(stopRepositoryProvider).clearCache();

      // ---- Step 6: Parse and import trips.txt ----
      state = const GtfsInitStatus(
        isComplete: false,
        message: 'Importing trips...',
        progress: 0.55,
      );
      debugPrint('[GTFS-Init] Parsing trips.txt...');
      final tripRows = await gtfsService.parseCsvFile('trips.txt');
      debugPrint('[GTFS-Init] Parsed trips.txt: ${tripRows.length} rows');

      final tripDbRows = tripRows.map((row) => <String, dynamic>{
        'trip_id': row['trip_id'] ?? '',
        'route_id': row['route_id'] ?? '',
        'service_id': row['service_id'] ?? '',
        'trip_headsign': row['trip_headsign'],
        'direction_id': int.tryParse(row['direction_id'] ?? '0'),
        'shape_id': row['shape_id'],
      }).toList();
      await dbService.bulkInsertTrips(tripDbRows);
      debugPrint('[GTFS-Init] ✓ Inserted ${tripDbRows.length} trips into SQLite');

      // ---- Step 7: Parse and import stop_times.txt ----
      state = const GtfsInitStatus(
        isComplete: false,
        message: 'Importing schedules...',
        progress: 0.65,
      );
      debugPrint('[GTFS-Init] Parsing stop_times.txt...');
      final stopTimeRows = await gtfsService.parseCsvFile('stop_times.txt');
      debugPrint('[GTFS-Init] Parsed stop_times.txt: ${stopTimeRows.length} rows');

      final stopTimeDbRows = stopTimeRows.map((row) => <String, dynamic>{
        'trip_id': row['trip_id'] ?? '',
        'stop_id': row['stop_id'] ?? '',
        'arrival_time': row['arrival_time'] ?? '',
        'departure_time': row['departure_time'] ?? '',
        'stop_sequence': int.tryParse(row['stop_sequence'] ?? '0') ?? 0,
      }).toList();
      await dbService.bulkInsertStopTimes(stopTimeDbRows);
      debugPrint('[GTFS-Init] ✓ Inserted ${stopTimeDbRows.length} stop_times into SQLite');

      // ---- Step 8: Parse and import shapes.txt ----
      state = const GtfsInitStatus(
        isComplete: false,
        message: 'Importing route shapes...',
        progress: 0.85,
      );
      debugPrint('[GTFS-Init] Parsing shapes.txt...');
      final shapeRows = await gtfsService.parseCsvFile('shapes.txt');
      debugPrint('[GTFS-Init] Parsed shapes.txt: ${shapeRows.length} rows');

      final shapeDbRows = shapeRows.map((row) => <String, dynamic>{
        'shape_id': row['shape_id'] ?? '',
        'shape_pt_lat': double.tryParse(row['shape_pt_lat'] ?? '0') ?? 0.0,
        'shape_pt_lon': double.tryParse(row['shape_pt_lon'] ?? '0') ?? 0.0,
        'shape_pt_sequence':
            int.tryParse(row['shape_pt_sequence'] ?? '0') ?? 0,
      }).toList();
      await dbService.bulkInsertShapes(shapeDbRows);
      debugPrint('[GTFS-Init] ✓ Inserted ${shapeDbRows.length} shapes into SQLite');

      // ---- Done ----
      stopwatch.stop();
      debugPrint('[GTFS-Init] ✓ All GTFS data imported successfully '
          'in ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('[GTFS-Init] Summary: '
          '${routeDbRows.length} routes, '
          '${stopDbRows.length} stops, '
          '${tripDbRows.length} trips, '
          '${stopTimeDbRows.length} stop_times, '
          '${shapeDbRows.length} shapes');

      state = const GtfsInitStatus.complete();
    } catch (e, stackTrace) {
      stopwatch.stop();
      debugPrint('[GTFS-Init] ✗ FAILED after ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('[GTFS-Init] Error: $e');
      debugPrint('[GTFS-Init] Stack: $stackTrace');

      state = GtfsInitStatus(
        isComplete: false,
        hasError: true,
        message: 'Failed to load transit data: ${e.toString()}',
        progress: 0.0,
        error: e,
      );
    }
  }
}
