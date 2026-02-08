import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bussin/providers/stop_providers.dart';
import 'package:bussin/providers/trip_update_providers.dart';
import 'package:bussin/providers/route_providers.dart';
import 'package:bussin/providers/favorites_provider.dart';
import 'package:bussin/data/models/trip_update.dart';
import 'package:bussin/data/models/bus_route.dart';

import 'package:bussin/features/stop_detail/widgets/stop_info_header.dart';
import 'package:bussin/features/stop_detail/widgets/arrival_list_tile.dart';
import 'package:bussin/features/stop_detail/widgets/set_alert_button.dart';

/// ---------------------------------------------------------------------------
/// Stop Detail Screen
/// ---------------------------------------------------------------------------
/// Shows all upcoming bus arrivals at a specific transit stop. Accessed
/// when the user taps a stop marker on the map, selects a stop from
/// search results, or taps a stop from their favorites list.
///
/// Layout (top to bottom):
///   1. CupertinoNavigationBar with back button and stop name title
///   2. StopInfoHeader: stop name, stop code (#51479), favorite star toggle
///   3. List of ArrivalListTile widgets sorted by ETA (soonest first)
///   4. Each arrival row includes a SetAlertButton for notifications
///
/// State consumed from Riverpod providers:
///   - stopProvider(stopId)         -> stop metadata (name, code, location)
///   - etasForStopProvider(stopId)  -> real-time arrival predictions
///   - isFavoriteProvider(stopId)   -> whether stop is in user's favorites
///   - tripUpdatesProvider          -> full trip updates for route matching
///   - allRoutesProvider            -> route metadata for badge colors/names
/// ---------------------------------------------------------------------------
class StopDetailScreen extends ConsumerWidget {
  /// The GTFS stop ID to display details for.
  final String stopId;

  const StopDetailScreen({super.key, required this.stopId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // -----------------------------------------------------------------------
    // Watch all providers needed for this screen
    // -----------------------------------------------------------------------

    // Stop metadata (name, code, coordinates) from GTFS static data.
    final stopAsync = ref.watch(stopProvider(stopId));

    // Real-time arrival predictions for this stop, sorted by ETA ascending.
    final etasAsync = ref.watch(etasForStopProvider(stopId));

    // Full trip updates list -- used to look up route IDs and headsigns
    // for each arrival prediction.
    final tripUpdatesAsync = ref.watch(tripUpdatesProvider);

    // All routes -- used to look up route short names and colors for
    // the arrival list badges.
    final allRoutesAsync = ref.watch(allRoutesProvider);

    return CupertinoPageScaffold(
      // --------------------------------------------------------------------
      // Navigation bar with back button
      // --------------------------------------------------------------------
      navigationBar: CupertinoNavigationBar(
        middle: stopAsync.when(
          data: (stop) => Text(
            stop?.stopName ?? 'Stop',
            overflow: TextOverflow.ellipsis,
          ),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Stop'),
        ),
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
          child: stopAsync.when(
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
                    'Failed to load stop: $error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: CupertinoColors.systemGrey),
                  ),
                  const SizedBox(height: 12.0),
                  CupertinoButton(
                    child: const Text('Retry'),
                    onPressed: () => ref.invalidate(stopProvider(stopId)),
                  ),
                ],
              ),
            ),

            // Data loaded: build the full stop detail layout.
            data: (stop) {
              // Handle null stop (ID not found in database).
              if (stop == null) {
                // Removed 'const' because CupertinoColors.systemGrey is dynamic
                return const Center(
                  child: Text(
                    'Stop not found',
                    style: TextStyle(color: CupertinoColors.systemGrey),
                  ),
                );
              }

              // Build a route lookup map from allRoutesProvider for fast
              // access to route names and colors when rendering arrival tiles.
              final routeMap = allRoutesAsync.when(
                data: (routes) => {
                  for (final route in routes) route.routeId: route,
                },
                loading: () => <String, BusRoute>{},
                error: (_, __) => <String, BusRoute>{},
              );

              // Build a map from tripId -> TripUpdateModel so we can look up
              // the route ID for each stop time update.
              final tripUpdateMap = tripUpdatesAsync.when(
                data: (updates) => {
                  for (final update in updates) update.tripId: update,
                },
                loading: () => <String, TripUpdateModel>{},
                error: (_, __) => <String, TripUpdateModel>{},
              );

              // Extract the ETA list, or show empty while loading.
              final etas = etasAsync.when(
                data: (e) => e,
                loading: () => <StopTimeUpdateModel>[],
                error: (_, __) => <StopTimeUpdateModel>[],
              );

              // Build a combined list of arrival data by matching each ETA's
              // stop time update back to its parent trip update to get the
              // route ID, then looking up route metadata.
              final arrivalEntries = _buildArrivalEntries(
                etas,
                tripUpdateMap,
                routeMap,
              );

              return CustomScrollView(
                slivers: [
                  // ----------------------------------------------------------
                  // Section 1: Stop info header with favorite toggle
                  // ----------------------------------------------------------
                  SliverToBoxAdapter(
                    child: StopInfoHeader(stop: stop),
                  ),

                  // ----------------------------------------------------------
                  // Divider between header and arrivals
                  // ----------------------------------------------------------
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: _Divider(),
                    ),
                  ),

                  // ----------------------------------------------------------
                  // Section 2: "Upcoming Arrivals" heading
                  // ----------------------------------------------------------
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                      child: Text(
                        'Upcoming Arrivals',
                        style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  // ----------------------------------------------------------
                  // Section 3: List of arrival tiles sorted by ETA
                  // ----------------------------------------------------------
                  if (arrivalEntries.isEmpty)
                    // Removed 'const' because CupertinoColors are dynamic
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 24.0,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              CupertinoIcons.clock,
                              size: 40.0,
                              color: CupertinoColors.systemGrey3,
                            ),
                            SizedBox(height: 8.0),
                            Text(
                              'No upcoming arrivals',
                              style: TextStyle(
                                color: CupertinoColors.systemGrey,
                                fontSize: 15.0,
                              ),
                            ),
                            SizedBox(height: 4.0),
                            Text(
                              'Check back later for real-time predictions.',
                              style: TextStyle(
                                color: CupertinoColors.systemGrey2,
                                fontSize: 13.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final entry = arrivalEntries[index];

                          return Row(
                            children: [
                              // The arrival tile takes up most of the row.
                              Expanded(
                                child: ArrivalListTile(
                                  stopTimeUpdate: entry.stopTimeUpdate,
                                  routeId: entry.routeId,
                                  routeShortName: entry.routeShortName,
                                  headsign: entry.headsign,
                                  routeColor: entry.routeColor,
                                ),
                              ),

                              // Set Alert button on the right side of each row.
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: SetAlertButton(
                                  routeId: entry.routeId,
                                  stopId: stopId,
                                  stopName: stop.stopName,
                                  routeShortName: entry.routeShortName,
                                ),
                              ),
                            ],
                          );
                        },
                        childCount: arrivalEntries.length,
                      ),
                    ),

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

  /// Builds a combined list of [_ArrivalEntry] objects by matching each
  /// stop time update to its parent trip update (for route ID) and then
  /// to the route metadata (for short name and color).
  ///
  /// This cross-referencing is necessary because [StopTimeUpdateModel] only
  /// contains stop-level data -- the route information lives in the parent
  /// [TripUpdateModel] and the [BusRoute] from the GTFS static data.
  List<_ArrivalEntry> _buildArrivalEntries(
    List<StopTimeUpdateModel> etas,
    Map<String, TripUpdateModel> tripUpdateMap,
    Map<String, BusRoute> routeMap,
  ) {
    final entries = <_ArrivalEntry>[];

    // For each ETA, we need to find the parent trip update to get
    // the route ID. We do this by scanning the trip update map.
    for (final eta in etas) {
      // Find the trip update that contains this stop time update.
      // We match by checking which trip update has a stop time update
      // with the same stopId and stopSequence.
      String? matchedRouteId;
      String? matchedHeadsign;

      for (final update in tripUpdateMap.values) {
        final hasMatch = update.stopTimeUpdates.any(
          (stu) =>
              stu.stopId == eta.stopId &&
              stu.stopSequence == eta.stopSequence &&
              stu.predictedArrival == eta.predictedArrival,
        );
        if (hasMatch) {
          matchedRouteId = update.routeId;
          break;
        }
      }

      // If we couldn't find a matching route, skip this ETA
      // (shouldn't happen normally but guards against data inconsistencies).
      if (matchedRouteId == null) continue;

      // Look up the route metadata for badge color and short name.
      final route = routeMap[matchedRouteId];

      entries.add(_ArrivalEntry(
        stopTimeUpdate: eta,
        routeId: matchedRouteId,
        routeShortName: route?.routeShortName ?? matchedRouteId,
        routeColor: route?.routeColor,
        headsign: matchedHeadsign,
      ));
    }

    return entries;
  }
}

/// Internal data class combining a stop time update with its associated
/// route information for rendering an arrival tile.
class _ArrivalEntry {
  final StopTimeUpdateModel stopTimeUpdate;
  final String routeId;
  final String routeShortName;
  final String? routeColor;
  final String? headsign;

  const _ArrivalEntry({
    required this.stopTimeUpdate,
    required this.routeId,
    required this.routeShortName,
    this.routeColor,
    this.headsign,
  });
}

/// Simple horizontal divider matching Cupertino design language.
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      // Removed 'const' because resolveFrom uses context
      color: CupertinoColors.separator.resolveFrom(context),
    );
  }
}
