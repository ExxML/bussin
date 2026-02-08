import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bussin/core/constants/api_constants.dart';
import 'package:bussin/core/errors/exceptions.dart';

/// HTTP client for fetching raw binary data from TransLink's GTFS-RT V3 endpoints.
///
/// All three endpoints return Protocol Buffer binary data (NOT JSON).
/// The response body must be read as [Uint8List] and parsed with
/// protobuf's [FeedMessage.fromBuffer()] method.
class TranslinkApiService {
  /// HTTP client instance. Injected for testability.
  final http.Client _client;

  /// TransLink API key appended as query parameter to all requests.
  final String _apiKey;

  TranslinkApiService({
    http.Client? client,
    String? apiKey,
  })  : _client = client ?? http.Client(),
        _apiKey = apiKey ?? ApiConstants.translinkApiKey;

  /// Fetches real-time vehicle positions as raw protobuf bytes.
  ///
  /// Returns [Uint8List] containing the binary protobuf response.
  /// Parse with: `FeedMessage.fromBuffer(bytes)`
  ///
  /// Throws [ServerException] on non-200 response or timeout.
  Future<Uint8List> fetchVehiclePositions() async {
    return _fetchProtobufData(ApiConstants.gtfsPositionUrl);
  }

  /// Fetches trip update / ETA predictions as raw protobuf bytes.
  ///
  /// Contains per-stop arrival/departure predictions with delay information.
  /// Throws [ServerException] on non-200 response or timeout.
  Future<Uint8List> fetchTripUpdates() async {
    return _fetchProtobufData(ApiConstants.gtfsRealtimeUrl);
  }

  /// Fetches service alerts as raw protobuf bytes.
  ///
  /// Contains disruption, detour, and cancellation information.
  /// Throws [ServerException] on non-200 response or timeout.
  Future<Uint8List> fetchServiceAlerts() async {
    return _fetchProtobufData(ApiConstants.gtfsAlertsUrl);
  }

  /// Internal helper that performs the HTTP GET request for protobuf data.
  ///
  /// Appends the API key as a query parameter, sets the Accept header
  /// for protobuf, and includes a single retry on network failure.
  Future<Uint8List> _fetchProtobufData(String baseUrl) async {
    final uri = Uri.parse('$baseUrl?apikey=$_apiKey');
    debugPrint('[API] GET $uri');

    // Attempt the request with one retry on network failure
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _client.get(
          uri,
          headers: {'Accept': 'application/x-protobuf'},
        ).timeout(ApiConstants.httpTimeout);

        debugPrint('[API] Response: ${response.statusCode} — ${response.bodyBytes.length} bytes from $baseUrl');

        // Validate HTTP response status
        if (response.statusCode != 200) {
          debugPrint('[API] FAILED: $baseUrl — HTTP ${response.statusCode}');
          throw ServerException(
            message: 'API request failed for $baseUrl',
            statusCode: response.statusCode,
          );
        }

        debugPrint('[API] ✓ SUCCESS: $baseUrl — ${response.bodyBytes.length} bytes');
        // Return raw bytes - do NOT decode as string
        return response.bodyBytes;
      } on ServerException {
        rethrow; // Don't retry server errors (4xx, 5xx)
      } catch (e) {
        debugPrint('[API] Network error (attempt ${attempt + 1}/2): $e');
        // Retry on network/timeout errors, but only once
        if (attempt == 1) {
          debugPrint('[API] ✗ FAILED after retry: $baseUrl — $e');
          throw ServerException(
            message: 'Network error after retry: ${e.toString()}',
          );
        }
      }
    }

    // This should never be reached due to the retry logic above
    throw const ServerException(message: 'Unexpected error in fetch');
  }

  /// Closes the HTTP client. Call when the service is no longer needed.
  void dispose() {
    _client.close();
  }
}
