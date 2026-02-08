import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bussin/data/repositories/shape_repository.dart';

/// ---------------------------------------------------------------------------
/// Shape Providers
/// ---------------------------------------------------------------------------
/// These providers expose route polyline data from GTFS shape tables.
/// Shape data maps a route's geographic path as an ordered list of
/// LatLng coordinates, used for drawing route polylines on the map.
/// ---------------------------------------------------------------------------

/// Singleton instance of [ShapeRepository].
///
/// The shape repository queries SQLite for shape points linked to routes
/// through the trips table (routes -> trips -> shapes).
final shapeRepositoryProvider = Provider<ShapeRepository>((ref) {
  return ShapeRepository();
});

/// Route polyline coordinates for a specific route.
///
/// Returns an ordered [List<LatLng>] representing the geographic path
/// of the route, suitable for rendering as a polyline on a map.
///
/// Looks up the shape_id from any trip on the route, then fetches all
/// shape points ordered by sequence. Returns an empty list if no shape
/// data exists for the route.
final routeShapeProvider =
    FutureProvider.family<List<LatLng>, String>((ref, routeId) async {
  return ref.read(shapeRepositoryProvider).getRouteShape(routeId);
});
