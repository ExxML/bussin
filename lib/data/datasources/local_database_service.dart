import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Manages the SQLite database for GTFS static data cache and user data.
///
/// Stores two categories of data:
/// 1. GTFS Static: routes, stops, trips, stop_times, shapes (refreshed from ZIP)
/// 2. User Data: favorites, route_history (persists across app updates)
///
/// Uses batch API with transactions for efficient bulk imports of GTFS data.
class LocalDatabaseService {
  /// Singleton database instance.
  static Database? _database;

  /// Database file name.
  static const String _dbName = 'bussin.db';

  /// Current database schema version.
  static const int _dbVersion = 1;

  /// Opens or creates the SQLite database.
  ///
  /// Must be called once during app startup before any database operations.
  /// Creates all tables and indexes on first run.
  static Future<void> init() async {
    if (_database != null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(appDir.path, _dbName);

    _database = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _createTables,
    );
  }

  /// Getter for the database instance.
  /// Throws if [init] has not been called.
  static Database get db {
    if (_database == null) {
      throw StateError('Database not initialized. Call LocalDatabaseService.init() first.');
    }
    return _database!;
  }

  /// Creates all database tables and indexes on first run.
  static Future<void> _createTables(Database db, int version) async {
    // ===== GTFS Static Data Tables =====

    await db.execute('''
      CREATE TABLE gtfs_routes (
        route_id TEXT PRIMARY KEY,
        route_short_name TEXT NOT NULL,
        route_long_name TEXT NOT NULL,
        route_type INTEGER NOT NULL,
        route_color TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE gtfs_stops (
        stop_id TEXT PRIMARY KEY,
        stop_name TEXT NOT NULL,
        stop_lat REAL NOT NULL,
        stop_lon REAL NOT NULL,
        stop_code TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_stops_code ON gtfs_stops(stop_code)');
    await db.execute('CREATE INDEX idx_stops_name ON gtfs_stops(stop_name)');

    await db.execute('''
      CREATE TABLE gtfs_trips (
        trip_id TEXT PRIMARY KEY,
        route_id TEXT NOT NULL,
        service_id TEXT NOT NULL,
        trip_headsign TEXT,
        direction_id INTEGER,
        shape_id TEXT,
        FOREIGN KEY (route_id) REFERENCES gtfs_routes(route_id)
      )
    ''');
    await db.execute('CREATE INDEX idx_trips_route ON gtfs_trips(route_id)');
    await db.execute('CREATE INDEX idx_trips_shape ON gtfs_trips(shape_id)');

    await db.execute('''
      CREATE TABLE gtfs_stop_times (
        trip_id TEXT NOT NULL,
        stop_id TEXT NOT NULL,
        arrival_time TEXT NOT NULL,
        departure_time TEXT NOT NULL,
        stop_sequence INTEGER NOT NULL,
        PRIMARY KEY (trip_id, stop_sequence),
        FOREIGN KEY (trip_id) REFERENCES gtfs_trips(trip_id),
        FOREIGN KEY (stop_id) REFERENCES gtfs_stops(stop_id)
      )
    ''');
    await db.execute('CREATE INDEX idx_stop_times_stop ON gtfs_stop_times(stop_id)');

    await db.execute('''
      CREATE TABLE gtfs_shapes (
        shape_id TEXT NOT NULL,
        shape_pt_lat REAL NOT NULL,
        shape_pt_lon REAL NOT NULL,
        shape_pt_sequence INTEGER NOT NULL,
        PRIMARY KEY (shape_id, shape_pt_sequence)
      )
    ''');

    // ===== User Data Tables =====

    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stop_id TEXT NOT NULL UNIQUE,
        stop_name TEXT NOT NULL,
        stop_lat REAL NOT NULL,
        stop_lon REAL NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE route_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        route_id TEXT NOT NULL,
        route_short_name TEXT NOT NULL,
        route_long_name TEXT NOT NULL,
        viewed_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    await db.execute('CREATE INDEX idx_history_route ON route_history(route_id)');
    await db.execute('CREATE INDEX idx_history_date ON route_history(viewed_at DESC)');
  }

  /// Bulk inserts route data from GTFS static CSV.
  ///
  /// Uses batch API with [noResult: true] for performance.
  /// Processes rows in chunks of 1000 within a single transaction.
  Future<void> bulkInsertRoutes(List<Map<String, dynamic>> rows) async {
    await _bulkInsert('gtfs_routes', rows);
  }

  /// Bulk inserts stop data from GTFS static CSV.
  Future<void> bulkInsertStops(List<Map<String, dynamic>> rows) async {
    await _bulkInsert('gtfs_stops', rows);
  }

  /// Bulk inserts trip data from GTFS static CSV.
  Future<void> bulkInsertTrips(List<Map<String, dynamic>> rows) async {
    await _bulkInsert('gtfs_trips', rows);
  }

  /// Bulk inserts stop time data from GTFS static CSV.
  ///
  /// This is the largest table (~500K+ rows) and benefits most from
  /// batch processing in chunks of 1000.
  Future<void> bulkInsertStopTimes(List<Map<String, dynamic>> rows) async {
    await _bulkInsert('gtfs_stop_times', rows);
  }

  /// Bulk inserts shape point data from GTFS static CSV.
  Future<void> bulkInsertShapes(List<Map<String, dynamic>> rows) async {
    await _bulkInsert('gtfs_shapes', rows);
  }

  /// Generic bulk insert helper using batch API for performance.
  ///
  /// Processes [rows] in chunks of 1000 within a single database transaction.
  /// Uses [ConflictAlgorithm.replace] to handle duplicate keys gracefully.
  Future<void> _bulkInsert(String table, List<Map<String, dynamic>> rows) async {
    debugPrint('[DB] Bulk inserting ${rows.length} rows into $table...');
    final stopwatch = Stopwatch()..start();
    await db.transaction((txn) async {
      const chunkSize = 1000;
      for (int i = 0; i < rows.length; i += chunkSize) {
        final chunk = rows.sublist(
          i,
          i + chunkSize > rows.length ? rows.length : i + chunkSize,
        );
        final batch = txn.batch();
        for (final row in chunk) {
          batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
    });
    stopwatch.stop();
    debugPrint('[DB] ✓ $table insert complete (${rows.length} rows in ${stopwatch.elapsedMilliseconds}ms)');
  }

  /// Drops and recreates all GTFS static data tables.
  ///
  /// Called before re-importing GTFS data to ensure a clean state.
  /// Does NOT affect user data tables (favorites, route_history).
  Future<void> clearGtfsData() async {
    debugPrint('[DB] clearGtfsData() — deleting all GTFS tables...');
    await db.execute('DELETE FROM gtfs_stop_times');
    await db.execute('DELETE FROM gtfs_shapes');
    await db.execute('DELETE FROM gtfs_trips');
    await db.execute('DELETE FROM gtfs_stops');
    await db.execute('DELETE FROM gtfs_routes');
    debugPrint('[DB] ✓ All GTFS tables cleared');
  }
}
