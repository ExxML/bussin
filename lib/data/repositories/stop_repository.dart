import 'package:flutter/foundation.dart';
import 'package:bussin/data/datasources/gtfs_static_service.dart';
import 'package:bussin/data/datasources/local_database_service.dart';
import 'package:bussin/data/models/bus_stop.dart';
import 'package:bussin/core/utils/distance_utils.dart';
import 'package:latlong2/latlong.dart';

/// Repository that provides stop data from the local SQLite cache
/// of GTFS static data.
///
/// Stops are imported from stops.txt in the GTFS static ZIP file.
/// Includes an in-memory cache of all stops for fast nearby-stop
/// calculations using the Haversine formula.
class StopRepository {
  /// Database service for SQLite queries.
  final LocalDatabaseService _dbService;

  /// GTFS static service for downloading and re-importing data.
  final GtfsStaticService _gtfsService;

  /// In-memory cache of all stops. Loaded once and reused for
  /// nearby calculations and search to avoid repeated DB queries.
  List<BusStop>? _allStopsCache;

  StopRepository({
    required LocalDatabaseService dbService,
    required GtfsStaticService gtfsService,
  })  : _dbService = dbService,
        _gtfsService = gtfsService;

  /// Fetches all stops from the local SQLite database.
  ///
  /// Results are cached in memory after the first load for fast
  /// access by nearby-stop and search operations (~8,000 stops).
  Future<List<BusStop>> getAllStops() async {
    if (_allStopsCache != null) return _allStopsCache!;

    final rows = await LocalDatabaseService.db.query('gtfs_stops');
    _allStopsCache = rows.map(_mapRowToStop).toList();
    return _allStopsCache!;
  }

  /// Fetches a single stop by its ID.
  ///
  /// Returns null if the stop is not found in the database.
  Future<BusStop?> getStop(String stopId) async {
    final rows = await LocalDatabaseService.db.query(
      'gtfs_stops',
      where: 'stop_id = ?',
      whereArgs: [stopId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRowToStop(rows.first);
  }

  /// Searches stops by name or stop code.
  ///
  /// Matches stops where the name contains the [query] string or
  /// the stop code exactly matches (for numeric lookups).
  /// Limited to 20 results for performance.
  Future<List<BusStop>> searchStops(String query) async {
    debugPrint('[StopRepo] searchStops("$query") — querying SQLite...');
    final rows = await LocalDatabaseService.db.query(
      'gtfs_stops',
      where: 'stop_name LIKE ? OR stop_code = ?',
      whereArgs: ['%$query%', query],
      limit: 20,
    );
    debugPrint('[StopRepo] searchStops("$query") → ${rows.length} results');
    return rows.map(_mapRowToStop).toList();
  }

  /// Finds all stops served by a specific route.
  ///
  /// Performs a join across gtfs_trips, gtfs_stop_times, and gtfs_stops
  /// to find stops on the given route, ordered by stop_sequence.
  /// Returns distinct stops to avoid duplicates from multiple trips.
  Future<List<BusStop>> getStopsForRoute(String routeId) async {
    final rows = await LocalDatabaseService.db.rawQuery('''
      SELECT DISTINCT s.stop_id, s.stop_name, s.stop_lat, s.stop_lon, s.stop_code
      FROM gtfs_stops s
      INNER JOIN gtfs_stop_times st ON s.stop_id = st.stop_id
      INNER JOIN gtfs_trips t ON st.trip_id = t.trip_id
      WHERE t.route_id = ?
      ORDER BY st.stop_sequence
    ''', [routeId]);

    return rows.map(_mapRowToStop).toList();
  }

  /// Finds stops within a given radius of a geographic position.
  ///
  /// Uses the in-memory stop cache and Haversine distance formula
  /// to filter stops within [radiusMeters] of [location].
  /// Much faster than a database query for this geometric operation.
  Future<List<BusStop>> getNearbyStops(
    LatLng location,
    double radiusMeters,
  ) async {
    final allStops = await getAllStops();
    return DistanceUtils.stopsWithinRadius(location, radiusMeters, allStops);
  }

  /// Invalidates the in-memory cache, forcing a reload from SQLite
  /// on the next [getAllStops] call.
  void clearCache() {
    debugPrint('[StopRepo] In-memory cache cleared');
    _allStopsCache = null;
  }

  /// Forces a refresh of stop data from the GTFS static ZIP file.
  ///
  /// Downloads the latest GTFS data (if not already downloaded),
  /// parses stops.txt CSV, and bulk-inserts into the database.
  Future<void> refreshFromStatic() async {
    debugPrint('[StopRepo] refreshFromStatic() — parsing stops.txt...');

    final stopRows = await _gtfsService.parseCsvFile('stops.txt');
    debugPrint('[StopRepo] Parsed ${stopRows.length} stops from stops.txt');

    // Clear existing stop data
    await LocalDatabaseService.db.delete('gtfs_stops');

    // Map CSV rows to database column format
    final dbRows = stopRows.map((row) => <String, dynamic>{
      'stop_id': row['stop_id'] ?? '',
      'stop_name': row['stop_name'] ?? '',
      'stop_lat': double.tryParse(row['stop_lat'] ?? '0') ?? 0.0,
      'stop_lon': double.tryParse(row['stop_lon'] ?? '0') ?? 0.0,
      'stop_code': row['stop_code'],
    }).toList();

    await _dbService.bulkInsertStops(dbRows);
    debugPrint('[StopRepo] ✓ Inserted ${dbRows.length} stops into SQLite');

    // Invalidate in-memory cache so next getAllStops() reloads from DB
    clearCache();
  }

  /// Maps a database row map to a [BusStop] domain model.
  BusStop _mapRowToStop(Map<String, dynamic> row) {
    return BusStop(
      stopId: row['stop_id'] as String,
      stopName: row['stop_name'] as String,
      stopLat: (row['stop_lat'] as num).toDouble(),
      stopLon: (row['stop_lon'] as num).toDouble(),
      stopCode: row['stop_code'] as String?,
    );
  }
}
