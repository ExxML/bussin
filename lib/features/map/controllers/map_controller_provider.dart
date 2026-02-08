import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'package:bussin/core/constants/map_constants.dart';

/// ---------------------------------------------------------------------------
/// Map Controller Provider
/// ---------------------------------------------------------------------------
/// A Riverpod NotifierProvider that holds a reference to a
/// [GoogleMapController], enabling programmatic camera control from anywhere
/// in the widget tree.
///
/// The controller is created by the GoogleMap widget and registered here via
/// [setGoogleMapController].
///
/// Methods:
/// - [setGoogleMapController]: Registers the controller from BusMap
/// - [clearGoogleMapController]: Clears the reference on widget disposal
/// - [centerOnUser]: Animates map to user's GPS position at zoom 15
/// - [fitRouteBounds]: Animates the map to fit all route coordinates in view
/// - [animateToPosition]: Animates map to any LatLng at a specified zoom
/// ---------------------------------------------------------------------------

/// Provider exposing the [MapControllerNotifier] for programmatic map control.
///
/// The state tracks initialization status so callers can check readiness.
final mapControllerProvider =
    NotifierProvider<MapControllerNotifier, MapControllerState>(
  MapControllerNotifier.new,
);

/// State class for the map controller provider.
///
/// Tracks whether the GoogleMapController has been registered (set by BusMap)
/// so callers can check readiness before attempting map operations.
class MapControllerState {
  /// Whether the GoogleMapController has been registered.
  final bool isInitialized;

  const MapControllerState({this.isInitialized = false});
}

/// Notifier that manages programmatic map control.
///
/// Holds a reference to the [GoogleMapController] created and owned by BusMap.
class MapControllerNotifier extends Notifier<MapControllerState> {
  GoogleMapController? _googleMapController;

  @override
  MapControllerState build() {
    // Initial state: not yet initialized (waiting for BusMap to register
    // the GoogleMapController after its initState completes).
    return const MapControllerState(isInitialized: false);
  }

  void setGoogleMapController(GoogleMapController controller) {
    _googleMapController = controller;
    state = const MapControllerState(isInitialized: true);
  }

  void clearGoogleMapController() {
    _googleMapController = null;
    state = const MapControllerState(isInitialized: false);
  }

  /// Centers the map on the user's GPS position at street-level zoom.
  ///
  /// Called when the user taps the LocateMeButton. Animates smoothly
  /// to the user's position at zoom level 15, which provides enough
  /// detail to see nearby streets and stops.
  ///
  /// [position] is the user's current GPS position from the geolocator package.
  /// No-ops silently if the GoogleMapController hasn't been registered yet.
  void centerOnUser(Position position) {
    if (_googleMapController == null) return;
    _googleMapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        15.0,
      ),
    );
  }

  /// Fits the map viewport to contain all coordinates in a route shape,
  /// using an animated camera transition.
  ///
  /// Used when a route is selected to zoom out/in so the entire route
  /// polyline is visible on screen. Applies padding defined in
  /// [MapConstants.fitBoundsPadding] (50px) to prevent the polyline
  /// from touching the screen edges.
  ///
  /// Uses [GoogleMapController.animateCamera] for a smooth animated
  /// transition instead of an instant jump.
  ///
  /// [points] is the ordered list of LatLng coordinates forming the route path.
  /// No-ops if the list is empty or controller isn't registered.
  void fitRouteBounds(List<ll.LatLng> points) {
    if (_googleMapController == null || points.isEmpty) return;

    double? minLat;
    double? maxLat;
    double? minLng;
    double? maxLng;

    for (final p in points) {
      minLat = minLat == null ? p.latitude : (p.latitude < minLat ? p.latitude : minLat);
      maxLat = maxLat == null ? p.latitude : (p.latitude > maxLat ? p.latitude : maxLat);
      minLng = minLng == null ? p.longitude : (p.longitude < minLng ? p.longitude : minLng);
      maxLng = maxLng == null ? p.longitude : (p.longitude > maxLng ? p.longitude : maxLng);
    }

    if (minLat == null || maxLat == null || minLng == null || maxLng == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    final padding = MapConstants.fitBoundsPadding;
    final paddingValue = padding.horizontal > padding.vertical
        ? padding.horizontal
        : padding.vertical;

    _googleMapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, paddingValue),
    );
  }

  /// Animates the map to a specific position and zoom level.
  ///
  /// General-purpose method for moving the map to any location.
  /// Used by various features like "center on stop" or "center on bus".
  ///
  /// [position] is the target center coordinate.
  /// [zoom] is the target zoom level.
  /// No-ops if the GoogleMapController hasn't been registered.
  void animateToPosition(LatLng position, double zoom) {
    if (_googleMapController == null) return;
    _googleMapController!.animateCamera(
      CameraUpdate.newLatLngZoom(position, zoom),
    );
  }
}
