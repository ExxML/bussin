import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussin/data/models/bus_route.dart';
import 'package:bussin/data/models/bus_stop.dart';
import 'package:bussin/providers/route_providers.dart';
import 'package:bussin/providers/stop_providers.dart';

/// ---------------------------------------------------------------------------
/// Search Providers
/// ---------------------------------------------------------------------------
/// These providers power the search screen by combining route and stop
/// search results into a single unified result set. The search query is
/// debounced at the UI level (300ms) before updating [searchQueryProvider].
/// ---------------------------------------------------------------------------

/// Holds the current search text entered by the user.
///
/// Updated from the search screen's [CupertinoSearchTextField] with
/// a 300ms debounce delay to avoid excessive database queries.
/// Setting this to a non-empty string triggers [searchResultsProvider]
/// to re-evaluate and fetch matching routes and stops.
///
/// Uses [Notifier] instead of the legacy [StateProvider] for Riverpod 3.x
/// compatibility.
final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

/// Notifier that manages the current search query string.
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  /// Updates the search query to the given text.
  void setQuery(String query) {
    state = query;
  }

  /// Clears the search query back to empty.
  void clear() {
    state = '';
  }
}

/// Combined search results containing matching routes and stops.
///
/// Derived from [searchQueryProvider]:
/// - If query is empty: returns an empty [SearchResults]
/// - Otherwise: calls [routeSearchProvider] and [stopSearchProvider]
///   in parallel and combines the results
///
/// Widgets should watch this provider to display search results on the
/// search screen, handling loading/error states via [AsyncValue].
final searchResultsProvider =
    FutureProvider.autoDispose<SearchResults>((ref) async {
  final query = ref.watch(searchQueryProvider);

  // Don't search on empty query -- show recent searches instead
  if (query.isEmpty) {
    debugPrint('[Search] Query is empty — returning empty results');
    return SearchResults(routes: [], stops: []);
  }

  debugPrint('[Search] Querying: "$query"');

  // Execute route and stop searches in parallel for faster results
  final results = await Future.wait([
    ref.read(routeRepositoryProvider).searchRoutes(query),
    ref.read(stopRepositoryProvider).searchStops(query),
  ]);

  final searchResults = SearchResults(
    routes: results[0] as List<BusRoute>,
    stops: results[1] as List<BusStop>,
  );

  debugPrint('[Search] Results for "$query": '
      '${searchResults.routes.length} routes, '
      '${searchResults.stops.length} stops');

  if (searchResults.isEmpty) {
    debugPrint('[Search] WARNING: No results found for "$query"');
  }

  return searchResults;
});

/// Container class for combined search results.
///
/// Groups matching routes and stops together so the search screen
/// can display them in separate sections (using a segmented control
/// or combined list).
class SearchResults {
  /// Routes matching the search query (by short or long name).
  final List<BusRoute> routes;

  /// Stops matching the search query (by name or stop code).
  final List<BusStop> stops;

  const SearchResults({
    required this.routes,
    required this.stops,
  });

  /// Whether both route and stop results are empty.
  bool get isEmpty => routes.isEmpty && stops.isEmpty;

  /// Total number of results across both categories.
  int get totalCount => routes.length + stops.length;
}
