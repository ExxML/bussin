import 'dart:io';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bussin/core/constants/api_constants.dart';
import 'package:bussin/core/errors/exceptions.dart';

/// Service for downloading, extracting, and parsing GTFS static data.
///
/// The GTFS static data is a ZIP file containing CSV files with route,
/// stop, trip, schedule, and shape information. This data is downloaded
/// on first launch and refreshed every 24 hours.
class GtfsStaticService {
  /// SharedPreferences key for the last download timestamp.
  static const String _lastDownloadKey = 'gtfs_last_download';

  /// Downloads the GTFS static ZIP file and extracts CSV files to local storage.
  ///
  /// The ZIP file (~15MB) is downloaded to a temp directory, then CSV files
  /// are extracted to the app's documents directory for parsing.
  Future<void> downloadAndExtractGtfsData() async {
    try {
      debugPrint('[GTFS] Downloading ZIP from ${ApiConstants.gtfsStaticUrl}...');
      // Download the ZIP file from TransLink
      final response = await http.get(
        Uri.parse(ApiConstants.gtfsStaticUrl),
      ).timeout(const Duration(minutes: 2));

      debugPrint('[GTFS] Download response: HTTP ${response.statusCode}, ${response.bodyBytes.length} bytes');

      if (response.statusCode != 200) {
        debugPrint('[GTFS] ✗ Download FAILED: HTTP ${response.statusCode}');
        throw ServerException(
          message: 'Failed to download GTFS static data',
          statusCode: response.statusCode,
        );
      }

      // Decode the ZIP archive from the response bytes
      debugPrint('[GTFS] Decoding ZIP archive...');
      final archive = ZipDecoder().decodeBytes(response.bodyBytes);
      debugPrint('[GTFS] ZIP contains ${archive.length} files');

      // Get the app documents directory for storing extracted files
      final appDir = await getApplicationDocumentsDirectory();
      final gtfsDir = Directory('${appDir.path}/gtfs');

      // Create the GTFS directory if it doesn't exist
      if (!await gtfsDir.exists()) {
        await gtfsDir.create(recursive: true);
      }

      // Extract each file from the archive
      for (final file in archive) {
        if (file.isFile) {
          final outputFile = File('${gtfsDir.path}/${file.name}');
          await outputFile.writeAsBytes(file.content as List<int>);
          debugPrint('[GTFS] Extracted: ${file.name} (${(file.content as List<int>).length} bytes)');
        }
      }

      // Record the download timestamp
      await setLastDownloadTime(DateTime.now());
      debugPrint('[GTFS] ✓ Download and extraction complete. Files saved to ${gtfsDir.path}');
    } catch (e) {
      debugPrint('[GTFS] ✗ Download/extraction FAILED: $e');
      if (e is ServerException) rethrow;
      throw ServerException(message: 'GTFS download failed: ${e.toString()}');
    }
  }

  /// Parses a CSV file from the extracted GTFS data into a list of row maps.
  ///
  /// The first row is treated as headers and used as keys for subsequent rows.
  /// [filename] should be just the file name (e.g., "routes.txt").
  Future<List<Map<String, String>>> parseCsvFile(String filename) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/gtfs/$filename');

      if (!await file.exists()) {
        throw const ParseException(message: 'GTFS CSV file not found');
      }

      final csvString = await file.readAsString();

      // Parse CSV with standard GTFS delimiters
      final rows = const CsvToListConverter(
        eol: '\n',
        fieldDelimiter: ',',
        shouldParseNumbers: false,
      ).convert(csvString);

      if (rows.isEmpty) return [];

      // First row contains column headers
      final headers = rows.first.map((e) => e.toString().trim()).toList();
      debugPrint('[GTFS] Parsed $filename headers: $headers');
      final result = <Map<String, String>>[];

      // Map each subsequent row to a header-keyed map
      int skippedRows = 0;
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length != headers.length) {
          skippedRows++;
          continue; // Skip malformed rows
        }

        final map = <String, String>{};
        for (int j = 0; j < headers.length; j++) {
          map[headers[j]] = row[j].toString().trim();
        }
        result.add(map);
      }

      if (skippedRows > 0) {
        debugPrint('[GTFS] WARNING: Skipped $skippedRows malformed rows in $filename');
      }
      debugPrint('[GTFS] Parsed $filename: ${result.length} data rows (${rows.length - 1} total, $skippedRows skipped)');
      if (result.isNotEmpty) {
        debugPrint('[GTFS] Sample row from $filename: ${result.first}');
      }

      return result;
    } catch (e) {
      if (e is ParseException) rethrow;
      throw ParseException(message: 'CSV parse error: ${e.toString()}');
    }
  }

  /// Reads the timestamp of the last GTFS static data download.
  ///
  /// Returns null if the data has never been downloaded.
  Future<DateTime?> getLastDownloadTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_lastDownloadKey);
    if (timestamp == null) return null;
    return DateTime.tryParse(timestamp);
  }

  /// Stores the timestamp of the most recent GTFS download.
  Future<void> setLastDownloadTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastDownloadKey, time.toIso8601String());
  }

  /// Checks whether the local GTFS static data needs to be refreshed.
  ///
  /// Returns true if data has never been downloaded or if the last download
  /// was more than 24 hours ago.
  Future<bool> isDataStale() async {
    final lastDownload = await getLastDownloadTime();
    final isStale = lastDownload == null ||
        DateTime.now().difference(lastDownload) >
            ApiConstants.staticRefreshThreshold;
    debugPrint('[GTFS] isDataStale → $isStale (last download: $lastDownload)');
    return isStale;
  }
}
