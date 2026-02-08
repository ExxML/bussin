import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as ll;

import 'package:bussin/providers/route_providers.dart';
import 'package:bussin/providers/vehicle_providers.dart';
import 'package:bussin/providers/shape_providers.dart';
import 'package:bussin/providers/alert_providers.dart';
import 'package:bussin/providers/trip_update_providers.dart';
import 'package:bussin/core/constants/map_constants.dart';
import 'package:bussin/data/models/vehicle_position.dart';
import 'package:bussin/data/models/service_alert.dart';

import 'package:bussin/features/route_detail/widgets/route_info_header.dart';
import 'package:bussin/features/route_detail/widgets/bus_list_tile.dart';

/// ---------------------------------------------------------------------------
/// Route Detail Screen
/// ---------------------------------------------------------------------------
/// Full-screen view showing comprehensive information about a specific
/// transit route. Accessed when the user taps a route from search results,
/// the map, or the history screen.
///
/// Layout (top to bottom):
///   1. CupertinoNavigationBar with back button and route number title
///   2. RouteInfoHeader: large route badge, long name, headsign, bus count
///   3. Mini map: shows the route polyline + active bus markers
///   4. "Active Buses" section: scrollable list of BusListTile widgets
///   5. "Service Alerts" section: shown only if alerts exist for this route
///
/// State consumed from Riverpod providers:
///   - routeProvider(routeId)            -> route metadata (name, color, etc.)
///   - vehiclesForRouteProvider(routeId) -> real-time bus positions
///   - routeShapeProvider(routeId)       -> polyline coordinates
///   - alertsForRouteProvider(routeId)   -> service disruption alerts
///   - tripUpdatesProvider               -> delay info for each bus
/// ---------------------------------------------------------------------------
class RouteDetailScreen extends ConsumerWidget {
  /// The GTFS route ID to display details for.
  final String routeId;

  const RouteDetailScreen({super.key, required this.routeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // -----------------------------------------------------------------------
    // Watch all providers needed for this screen
    // -----------------------------------------------------------------------

    // Route metadata (name, color, type) from GTFS static data.
    final routeAsync = ref.watch(routeProvider(routeId));

    // Real-time vehicle positions filtered to this route.
    final vehiclesAsync = ref.watch(vehiclesForRouteProvider(routeId));

    // Route polyline shape for the mini map.
    final shapeAsync = ref.watch(routeShapeProvider(routeId));

    // Service alerts affecting this route (detours, cancellations, etc.).
    final alertsAsync = ref.watch(alertsForRouteProvider(routeId));

    // All trip updates -- used to look up per-bus delay information.
    final tripUpdatesAsync = ref.watch(tripUpdatesProvider);

    return CupertinoPageScaffold(
      // --------------------------------------------------------------------
      // Navigation bar with back button
      // --------------------------------------------------------------------
      navigationBar: CupertinoNavigationBar(
        // Shows the route short name in the nav bar title.
        middle: routeAsync.when(
          data: (route) =>
              Text(route != null ? 'Route ${route.routeShortName}' : 'Route'),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Route'),
        ),
        // Back button to return to the previous screen.
        leading: CupertinoNavigationBarBackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),

      // --------------------------------------------------------------------
      // Screen body: scrollable content
      // --------------------------------------------------------------------
      // Wrapped in Material to fix yellow underline text issues
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: routeAsync.when(
            // Loading state: centered activity indicator.
            loading: () => const Center(child: CupertinoActivityIndicator()),

            // Error state: display error message with retry option.
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Removed 'const' because CupertinoColors.systemGrey is dynamic
                  const Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    size: 48.0,
                    color: CupertinoColors.systemGrey,
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    'Failed to load route: $error',
                    textAlign: TextAlign.center,
                    // Removed 'const' because CupertinoColors.systemGrey is dynamic
                    style: const TextStyle(color: CupertinoColors.systemGrey),
                  ),
                  const SizedBox(height: 12.0),
                  CupertinoButton(
                    child: const Text('Retry'),
                    onPressed: () => ref.invalidate(routeProvider(routeId)),
                  ),
                ],
              ),
            ),

            // Data loaded: build the full route detail layout.
            data: (route) {
              // Handle null route (ID not found in database).
              if (route == null) {
                // Removed 'const' because CupertinoColors.systemGrey is dynamic
                return const Center(
                  child: Text(
                    'Route not found',
                    style: TextStyle(color: CupertinoColors.systemGrey),
                  ),
                );
              }

              // Extract the list of active vehicles (or empty while loading).
              final vehicles = vehiclesAsync.when(
                data: (v) => v,
                loading: () => <VehiclePositionModel>[],
                error: (_, __) => <VehiclePositionModel>[],
              );

              // Extract the polyline points (or empty while loading).
              final shapePoints = shapeAsync.when(
                data: (points) => points,
                loading: () => <ll.LatLng>[],
                error: (_, __) => <ll.LatLng>[],
              );

              // Extract service alerts (or empty while loading).
              final alerts = alertsAsync.when(
                data: (a) => a,
                loading: () => <ServiceAlertModel>[],
                error: (_, __) => <ServiceAlertModel>[],
              );

              // Extract trip updates for delay lookup.
              final tripUpdates = tripUpdatesAsync.when(
                data: (u) => u,
                loading: () => <dynamic>[],
                error: (_, __) => <dynamic>[],
              );

              // Parse route color for the polyline.
              final polylineColor = _parseRouteColor(route.routeColor);

              return CustomScrollView(
                slivers: [
                  // ----------------------------------------------------------
                  // Section 1: Route info header
                  // ----------------------------------------------------------
                  SliverToBoxAdapter(
                    child: RouteInfoHeader(
                      route: route,
                      activeBusCount: vehicles.length,
                    ),
                  ),

                  // ----------------------------------------------------------
                  // Section 2: Mini map with route polyline + bus markers
                  // ----------------------------------------------------------
                  SliverToBoxAdapter(
                    child:
                        _buildMiniMap(shapePoints, vehicles, polylineColor),
                  ),

                  // ----------------------------------------------------------
                  // Section 3: Active Buses heading
                  // ----------------------------------------------------------
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                      child: Text(
                        'Active Buses',
                        style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  // ----------------------------------------------------------
                  // Section 3b: List of BusListTile widgets
                  // ----------------------------------------------------------
                  if (vehicles.isEmpty)
                    // Removed 'const' because CupertinoColors.systemGrey is dynamic
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        child: Text(
                          'No buses are currently active on this route.',
                          style: TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 14.0,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final vehicle = vehicles[index];

                          // Look up the delay for this specific bus by matching
                          // trip IDs between the vehicle position and trip updates.
                          final delay = _findDelayForVehicle(
                            vehicle,
                            tripUpdates,
                          );

                          return BusListTile(
                            vehicle: vehicle,
                            delaySeconds: delay,
                            onTap: () {
                              // Future: navigate to vehicle detail or center map.
                            },
                          );
                        },
                        childCount: vehicles.length,
                      ),
                    ),

                  // ----------------------------------------------------------
                  // Section 4: Service Alerts (only if alerts exist)
                  // ----------------------------------------------------------
                  if (alerts.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 8.0),
                        child: Text(
                          'Service Alerts',
                          style: TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildAlertCard(context, alerts[index]),
                        childCount: alerts.length,
                      ),
                    ),
                  ],

                  // Bottom padding so content isn't flush with the screen edge.
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 32.0),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // Private helper methods
  // ==========================================================================

  /// Builds the mini map showing the route polyline and active bus markers.
  ///
  /// Uses FlutterMap with an OpenStreetMap TileLayer, a PolylineLayer for the
  /// route shape, and a MarkerLayer for active bus positions.
  Widget _buildMiniMap(
    List<ll.LatLng> shapePoints,
    List<VehiclePositionModel> vehicles,
    Color polylineColor,
  ) {
    // Calculate the map center from the polyline midpoint, or fall back
    // to Vancouver center if no shape data is available.
    final center = shapePoints.isNotEmpty
        ? shapePoints[shapePoints.length ~/ 2]
        : MapConstants.vancouverCenter;

    // Determine appropriate zoom: tighter if we have shape data.
    final zoom = shapePoints.isNotEmpty ? 12.0 : MapConstants.defaultZoom;

    final markers = <gmaps.Marker>{
      for (final v in vehicles)
        gmaps.Marker(
          markerId: gmaps.MarkerId('bus_${v.vehicleId}'),
          position: gmaps.LatLng(v.latitude, v.longitude),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueAzure,
          ),
        ),
    };

    final polylines = <gmaps.Polyline>{};
    if (shapePoints.isNotEmpty) {
      polylines.add(
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('route_shape'),
          points: shapePoints
              .map((p) => gmaps.LatLng(p.latitude, p.longitude))
              .toList(growable: false),
          color: polylineColor,
          width: 4,
        ),
      );
    }

    return Container(
      height: 200.0,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: gmaps.GoogleMap(
        initialCameraPosition: gmaps.CameraPosition(
          target: gmaps.LatLng(center.latitude, center.longitude),
          zoom: zoom,
        ),
        markers: markers,
        polylines: polylines,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        compassEnabled: false,
        mapToolbarEnabled: false,
        zoomControlsEnabled: false,
        scrollGesturesEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        zoomGesturesEnabled: false,
      ),
    );
  }

  /// Builds a single service alert card with header, effect, and description.
  Widget _buildAlertCard(BuildContext context, ServiceAlertModel alert) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: CupertinoColors.systemYellow.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: CupertinoColors.systemYellow.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alert header with warning icon.
          Row(
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                size: 16.0,
                color: CupertinoColors.systemYellow,
              ),
              const SizedBox(width: 6.0),
              Expanded(
                child: Text(
                  alert.headerText,
                  style: const TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4.0),

          // Alert effect badge (e.g., "DETOUR", "REDUCED_SERVICE").
          Text(
            alert.effect,
            style: const TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.systemOrange,
            ),
          ),
          const SizedBox(height: 4.0),

          // Alert description text (truncated to 3 lines).
          Text(
            alert.descriptionText,
            style: const TextStyle(
              fontSize: 13.0,
              color: CupertinoColors.systemGrey,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Looks up the overall delay for a vehicle by matching its tripId
  /// against the trip update feed.
  ///
  /// Returns the delay in seconds, or null if no matching trip update exists.
  int? _findDelayForVehicle(
    VehiclePositionModel vehicle,
    List<dynamic> tripUpdates,
  ) {
    for (final update in tripUpdates) {
      if (update.tripId == vehicle.tripId) {
        return update.delay;
      }
    }
    return null;
  }

  /// Parses a GTFS hex color string (without '#') into a Flutter [Color].
  /// Falls back to TransLink brand blue if parsing fails.
  Color _parseRouteColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return const Color(0xFF0060A9);
    }
    try {
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (_) {
      return const Color(0xFF0060A9);
    }
  }
}
