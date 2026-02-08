import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bussin/core/utils/time_utils.dart';
import 'package:bussin/data/models/bus_route.dart';
import 'package:bussin/data/models/trip_update.dart';
import 'package:bussin/data/models/vehicle_position.dart';
import 'package:bussin/providers/route_providers.dart';
import 'package:bussin/providers/trip_update_providers.dart';
import 'package:bussin/providers/stop_providers.dart';
import 'package:bussin/navigation/app_router.dart';

/// ---------------------------------------------------------------------------
/// BusInfoBottomSheet - Info sheet shown when a bus marker is tapped
/// ---------------------------------------------------------------------------
/// A Cupertino modal popup that slides up from the bottom to show detailed
/// information about a tapped bus vehicle. Displayed via
/// [showCupertinoModalPopup] from the MapScreen.
///
/// Content layout:
/// ┌──────────────────────────────────────────┐
/// │              [ Drag Handle ]             │
/// │                                          │
/// │  ┌──────┐                                │
/// │  │  49  │  UBC / Metrotown               │
/// │  └──────┘  Last updated: 0:15            │
/// │                                          │
/// │  Speed: 32 km/h                          │
/// │                                          │
/// │  Upcoming Stops:                         │
/// │    ● Main St Station     2 min           │
/// │    ○ Broadway-City Hall  8 min           │
/// │    ○ King Edward          12 min         │
/// │    ○ 41st Avenue          18 min         │
/// │                                          │
/// │  [ View Full Route ]  [ Set Alert ]      │
/// └──────────────────────────────────────────┘
///
/// State consumed:
/// - [routeProvider]: Route details (name, color) for the header badge
/// - [tripUpdateProvider]: Real-time trip update with per-stop ETAs
/// - [stopProvider]: Stop names for the upcoming stops list
///
/// Actions:
/// - "View Full Route": navigates to RouteDetailScreen
/// - "Set Arrival Alert": placeholder for notification scheduling
/// ---------------------------------------------------------------------------
class BusInfoBottomSheet extends ConsumerStatefulWidget {
  /// The vehicle position data for the tapped bus marker.
  final VehiclePositionModel vehicle;

  const BusInfoBottomSheet({
    super.key,
    required this.vehicle,
  });

  @override
  ConsumerState<BusInfoBottomSheet> createState() => _BusInfoBottomSheetState();
}

class _BusInfoBottomSheetState extends ConsumerState<BusInfoBottomSheet> {
  /// Timer that ticks every second to update the elapsed time display
  Timer? _timer;
  
  /// Elapsed seconds since the bottom sheet was opened
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    // Start the timer immediately when the sheet opens
    _startTimer();
  }

  @override
  void dispose() {
    // Cancel the timer when the sheet is dismissed
    _timer?.cancel();
    super.dispose();
  }

  /// Starts a timer that increments [_elapsedSeconds] every second
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  /// Formats the elapsed seconds into a "M:SS" format
  String _formatElapsedTime() {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Fetch the route details for the header badge color and name
    final routeAsync = ref.watch(routeProvider(widget.vehicle.routeId));

    // Fetch the trip update for this vehicle's current trip.
    // Contains per-stop arrival predictions (ETAs).
    final tripUpdateAsync =
        ref.watch(tripUpdateProvider(widget.vehicle.tripId));

    // Wrapped in Material to fix yellow underline text issues
    return Material(
      type: MaterialType.transparency,
      child: Container(
        // Limit sheet height to 55% of screen for readability
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        // Match background to the navigation bar theme background color
        decoration: BoxDecoration(
          color: Theme.of(context).navigationBarTheme.backgroundColor ??
              Theme.of(context).scaffoldBackgroundColor,
          // Rounded top corners for standard iOS bottom sheet appearance
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Drag handle ---
                // Visual affordance indicating the sheet can be dragged to dismiss.
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    // Removed 'const' because CupertinoColors.systemGrey3 is dynamic
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey3,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),

                // --- Header: Route badge + headsign ---
                _buildHeader(context, routeAsync),

                const SizedBox(height: 16),

                // --- Last updated timestamp ---
                // Shows how fresh the position data is, so users can assess
                // whether the bus has moved since the last GPS report.
                _buildLastUpdated(),

                const SizedBox(height: 8),

                // --- Speed display ---
                // Converts speed from m/s (GTFS-RT format) to km/h for readability.
                _buildSpeed(),

                const SizedBox(height: 20),

                // --- Upcoming stops with ETAs ---
                _buildUpcomingStops(context, ref, tripUpdateAsync),

                const SizedBox(height: 20),

                // --- Action buttons ---
                _buildActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the header row with route number badge and headsign text.
  ///
  /// The badge uses the route's GTFS color if available, defaulting
  /// to TransLink blue (#0060A9).
  Widget _buildHeader(
    BuildContext context,
    AsyncValue<BusRoute?> routeAsync,
  ) {
    return routeAsync.when(
      loading: () => _buildHeaderContent(
        routeShortName: widget.vehicle.routeId,
        routeLongName: 'Loading...',
        backgroundColor: const Color(0xFF0060A9),
      ),
      error: (_, __) => _buildHeaderContent(
        routeShortName: widget.vehicle.routeId,
        routeLongName: '',
        backgroundColor: const Color(0xFF0060A9),
      ),
      data: (route) => _buildHeaderContent(
        routeShortName: route?.routeShortName ?? widget.vehicle.routeId,
        routeLongName: route?.routeLongName ?? '',
        backgroundColor: _parseColor(route?.routeColor),
      ),
    );
  }

  /// Lays out the route badge and headsign text horizontally.
  Widget _buildHeaderContent({
    required String routeShortName,
    required String routeLongName,
    required Color backgroundColor,
  }) {
    return Row(
      children: [
        // --- Large route number badge ---
        // Prominent colored container showing the route number.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            routeShortName,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(width: 12),

        // --- Headsign / route long name ---
        // Flexible to handle long route names without overflow.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                routeLongName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // Show the vehicle label if available (e.g., bus fleet number)
              if (widget.vehicle.vehicleLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Vehicle ${widget.vehicle.vehicleLabel}',
                    style: const TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the "Last updated: M:SS" timer display.
  ///
  /// Shows a timer that counts up from 0:00 every second since the
  /// bottom sheet was opened (clicked on the bus).
  Widget _buildLastUpdated() {
    return Row(
      children: [
        const Icon(
          CupertinoIcons.clock,
          size: 14,
          color: CupertinoColors.systemGrey,
        ),
        const SizedBox(width: 4),
        Text(
          'Last updated: ${_formatElapsedTime()}',
          style: const TextStyle(
            color: CupertinoColors.systemGrey,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  /// Builds the speed display row.
  ///
  /// GTFS-RT reports speed in meters per second, which we convert to
  /// km/h for user readability (multiply by 3.6).
  /// Shows "N/A" if speed data is not reported by the vehicle.
  Widget _buildSpeed() {
    // Convert m/s to km/h: 1 m/s = 3.6 km/h
    final speedKmh = widget.vehicle.speed != null
        ? (widget.vehicle.speed! * 3.6).round()
        : null;

    return Row(
      children: [
        const Icon(
          CupertinoIcons.speedometer,
          size: 14,
          color: CupertinoColors.systemGrey,
        ),
        const SizedBox(width: 4),
        Text(
          speedKmh != null ? 'Speed: $speedKmh km/h' : 'Speed: N/A',
          style: const TextStyle(
            color: CupertinoColors.systemGrey,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  /// Builds the "Upcoming Stops" section with per-stop ETAs.
  ///
  /// Reads the trip update for this vehicle's trip, then displays the
  /// next 3-4 stops with their predicted arrival countdown.
  Widget _buildUpcomingStops(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<TripUpdateModel?> tripUpdateAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        const Text(
          'Upcoming Stops',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        // Trip update data drives the upcoming stops list
        tripUpdateAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          ),
          error: (_, __) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Unable to load arrival predictions.',
              style: TextStyle(
                color: CupertinoColors.systemGrey,
                fontSize: 13,
              ),
            ),
          ),
          data: (tripUpdate) {
            if (tripUpdate == null || tripUpdate.stopTimeUpdates.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No upcoming stop data available.',
                  style: TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 13,
                  ),
                ),
              );
            }

            // Filter to only show future stops (based on current stop sequence).
            // Then take the first 4 for a concise view.
            final currentSeq = widget.vehicle.currentStopSequence ?? 0;
            final upcomingStops = tripUpdate.stopTimeUpdates
                .where((stu) => stu.stopSequence >= currentSeq)
                .take(4)
                .toList();

            if (upcomingStops.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Bus is nearing the end of its trip.',
                  style: TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 13,
                  ),
                ),
              );
            }

            // Build a row for each upcoming stop
            return Column(
              children: upcomingStops.asMap().entries.map((entry) {
                final index = entry.key;
                final stu = entry.value;
                return _UpcomingStopRow(
                  stopId: stu.stopId,
                  predictedArrival: stu.predictedArrival,
                  // First item (index 0) is the next/current stop
                  isNext: index == 0,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  /// Builds the action buttons at the bottom of the sheet.
  ///
  /// - "View Full Route": pushes RouteDetailScreen for this vehicle's route
  /// - "Set Arrival Alert": placeholder for future notification feature
  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        // --- "View Full Route" button ---
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: const Color(0xFF0060A9),
            borderRadius: BorderRadius.circular(10),
            onPressed: () {
              // Dismiss the sheet first, then navigate to route detail
              Navigator.of(context).pop();
              AppRouter.pushRouteDetail(context, widget.vehicle.routeId);
            },
            child: const Text(
              'View Full Route',
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // --- "Set Arrival Alert" button ---
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: CupertinoColors.systemGrey5,
            borderRadius: BorderRadius.circular(10),
            onPressed: () {
              // TODO: Implement arrival alert scheduling via notification provider
              // This will allow users to get a push notification when the bus
              // is approaching a selected stop.
            },
            child: const Text(
              'Set Alert',
              style: TextStyle(
                color: CupertinoColors.activeBlue,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Parses a GTFS hex color string into a Flutter Color.
  /// Falls back to TransLink blue (#0060A9) if the color is null or invalid.
  Color _parseColor(String? hexColor) {
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

/// ---------------------------------------------------------------------------
/// _UpcomingStopRow - Single stop in the upcoming stops list
/// ---------------------------------------------------------------------------
/// Shows a stop name with its ETA countdown. Uses a filled circle (●)
/// for the next stop and an outlined circle (○) for subsequent stops.
class _UpcomingStopRow extends ConsumerWidget {
  final String stopId;
  final DateTime? predictedArrival;
  final bool isNext;

  const _UpcomingStopRow({
    required this.stopId,
    required this.predictedArrival,
    required this.isNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Look up the stop name from the static GTFS data
    final stopAsync = ref.watch(stopProvider(stopId));
    final stopName = stopAsync.value?.stopName ?? 'Stop $stopId';

    // Calculate the ETA countdown string
    String etaText;
    if (predictedArrival != null) {
      final secondsAway =
          predictedArrival!.difference(DateTime.now()).inSeconds;
      etaText = secondsAway > 0 ? TimeUtils.formatEta(secondsAway) : 'Now';
    } else {
      etaText = '--';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // --- Stop indicator dot ---
          // Filled circle for the next stop, outlined for subsequent stops
          Icon(
            isNext ? CupertinoIcons.circle_fill : CupertinoIcons.circle,
            size: 10,
            color: isNext
                ? CupertinoColors.activeBlue
                : CupertinoColors.systemGrey,
          ),

          const SizedBox(width: 10),

          // --- Stop name ---
          Expanded(
            child: Text(
              stopName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isNext ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // --- ETA countdown ---
          Text(
            etaText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isNext
                  ? CupertinoColors.activeBlue
                  : CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }
}
