import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'package:bussin/providers/location_provider.dart';
import 'package:bussin/providers/selected_route_provider.dart';
import 'package:bussin/data/models/bus_stop.dart';
import 'package:bussin/data/models/vehicle_position.dart';
import 'package:bussin/providers/shape_providers.dart';
import 'package:bussin/providers/stop_providers.dart';

import 'package:bussin/features/map/controllers/map_controller_provider.dart';

/// ---------------------------------------------------------------------------
/// BusMap - The GoogleMap widget composing all map layers
/// ---------------------------------------------------------------------------
/// This is the core map widget that renders the Google basemap and overlays
/// transit-specific content (buses, route polylines, stops, and user location).
///
/// Props:
/// - [vehicles]: AsyncValue containing the list of active bus positions
/// - [selectedRouteId]: Currently selected route ID (nullable)
/// - [onBusTapped]: Callback fired when a bus marker is tapped
/// ---------------------------------------------------------------------------
class BusMap extends ConsumerStatefulWidget {
  /// The current vehicle positions to render as markers.
  /// Wrapped in AsyncValue to handle loading/error states from the stream.
  final AsyncValue<List<VehiclePositionModel>> vehicles;

  /// The currently selected route ID, or null if showing all routes.
  /// When non-null, the polyline and stop layers activate for this route.
  final String? selectedRouteId;

  /// Callback invoked when the user taps a bus marker.
  /// Receives the tapped vehicle's data so the parent can open an info sheet.
  final void Function(VehiclePositionModel vehicle) onBusTapped;

  const BusMap({
    super.key,
    required this.vehicles,
    required this.selectedRouteId,
    required this.onBusTapped,
  });

  @override
  ConsumerState<BusMap> createState() => _BusMapState();
}

/// State for [BusMap].
///
/// Mixes in [TickerProviderStateMixin] to serve as the `vsync` for
/// [AnimatedMapController]. This is required because AnimatedMapController
/// creates [AnimationController] instances internally, and those need a
/// [TickerProvider] to drive their animations.
 class _BusMapState extends ConsumerState<BusMap> {
  GoogleMapController? _controller;

  @override
  void dispose() {
    ref.read(mapControllerProvider.notifier).clearGoogleMapController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userLocationAsync = ref.watch(currentLocationProvider);

    final selectedRouteId = ref.watch(selectedRouteProvider);

    final AsyncValue<List<ll.LatLng>> shapeAsync = selectedRouteId != null
        ? ref.watch(routeShapeProvider(selectedRouteId))
        : const AsyncData(<ll.LatLng>[]);

    final AsyncValue<List<BusStop>> stopsAsync = selectedRouteId != null
        ? ref.watch(stopsForRouteProvider(selectedRouteId))
        : const AsyncData(<BusStop>[]);

    final vehicleList = widget.vehicles.value ?? [];

    final markers = <Marker>{
      for (final vehicle in vehicleList)
        Marker(
          markerId: MarkerId('bus_${vehicle.vehicleId}'),
          position: LatLng(vehicle.latitude, vehicle.longitude),
          onTap: () => widget.onBusTapped(vehicle),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
    };

    final polylines = <Polyline>{};
    final routePoints = shapeAsync.asData?.value ?? const <ll.LatLng>[];
    if (routePoints.isNotEmpty) {
      final googlePoints = routePoints
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList(growable: false);

      if (googlePoints.isNotEmpty) {
        polylines.add(
          Polyline(
            polylineId: const PolylineId('selected_route'),
            points: googlePoints,
            color: const Color(0xFF0060A9),
            width: 4,
          ),
        );
      }
    }

    final stops = stopsAsync.asData?.value ?? const <BusStop>[];
    if (stops.isNotEmpty) {
      for (final stop in stops) {
        markers.add(
          Marker(
            markerId: MarkerId('stop_${stop.stopId}'),
            position: LatLng(stop.stopLat, stop.stopLon),
            icon: BitmapDescriptor.defaultMarker,
          ),
        );
      }
    }

    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(49.2827, -123.1207),
        zoom: 13.0,
      ),
      myLocationEnabled: !userLocationAsync.hasError,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      markers: markers,
      polylines: polylines,
      onMapCreated: (controller) {
        _controller = controller;
        ref.read(mapControllerProvider.notifier).setGoogleMapController(controller);
      },
    );
  }
}
