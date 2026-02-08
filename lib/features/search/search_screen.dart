import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bussin/core/utils/debouncer.dart';
import 'package:bussin/navigation/app_router.dart';
import 'package:bussin/providers/search_provider.dart';
import 'package:bussin/providers/selected_route_provider.dart';
import 'package:bussin/features/search/widgets/search_result_tile.dart';
import 'package:bussin/features/search/widgets/recent_searches.dart';

/// ---------------------------------------------------------------------------
/// SearchScreen
/// ---------------------------------------------------------------------------
/// Full-screen modal search interface for finding routes and stops.
///
/// Layout (top to bottom):
///   1. [CupertinoNavigationBar] with a "Cancel" trailing button
///   2. [CupertinoSearchTextField] (auto-focused on mount)
///   3. [CupertinoSlidingSegmentedControl] to toggle "Routes" vs "Stops"
///   4. Content area:
///      - Empty query  -> [RecentSearches] widget (previously viewed routes)
///      - Non-empty    -> filtered [SearchResultTile] list from provider
///
/// State management:
///   - Text input is debounced (300 ms) via [Debouncer] before writing to
///     [searchQueryProvider], preventing excessive SQLite queries.
///   - Results come from [searchResultsProvider] (async, combined routes+stops).
///   - On route tap  -> sets [selectedRouteProvider] and pops this screen.
///   - On stop tap   -> navigates to StopDetailScreen via [AppRouter] and pops.
/// ---------------------------------------------------------------------------

/// Enum for the segmented control tabs so we can switch between
/// showing route results and stop results.
enum _SearchSegment {
  routes,
  stops,
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  // -------------------------------------------------------------------------
  // Local state
  // -------------------------------------------------------------------------

  /// Controller for the search text field; allows us to read/clear the text
  /// and attach listeners.
  final TextEditingController _controller = TextEditingController();

  /// Focus node so we can auto-focus the search field when the screen opens.
  final FocusNode _focusNode = FocusNode();

  /// 300 ms debouncer to throttle writes to [searchQueryProvider].
  /// Without this, every keystroke would trigger a new database search.
  final Debouncer _debouncer = Debouncer(milliseconds: 300);

  /// Currently selected segment (Routes or Stops).
  /// Determines which subset of results is displayed.
  _SearchSegment _selectedSegment = _SearchSegment.routes;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    // Auto-focus the search field as soon as the screen is mounted so the
    // keyboard appears immediately -- standard iOS search UX pattern.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    // Clean up resources to avoid memory leaks.
    _controller.dispose();
    _focusNode.dispose();
    _debouncer.dispose();

    // Reset the provider query so stale results aren't shown if the user
    // opens the search screen again later.
    // NOTE: This is safe to call from dispose because we're reading (not
    // watching) a synchronous Notifier.
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Event handlers
  // -------------------------------------------------------------------------

  /// Called on every keystroke in the search field.
  ///
  /// Debounces the input for 300 ms, then writes the trimmed query to
  /// [searchQueryProvider] which triggers [searchResultsProvider] to
  /// re-evaluate.
  void _onSearchChanged(String text) {
    _debouncer.run(() {
      ref.read(searchQueryProvider.notifier).setQuery(text.trim());
    });
  }

  /// Handles tapping a route result.
  ///
  /// 1. Sets the selected route in global state so the map filters to it.
  /// 2. Clears the search query to reset for next use.
  /// 3. Pops back to the map screen.
  void _onRouteTap(String routeId) {
    ref.read(selectedRouteProvider.notifier).selectRoute(routeId);
    ref.read(searchQueryProvider.notifier).clear();
    Navigator.of(context).pop();
  }

  /// Handles tapping a stop result.
  ///
  /// 1. Clears the search query to reset for next use.
  /// 2. Pops back to the previous screen (map).
  /// 3. Pushes the StopDetailScreen for the tapped stop.
  void _onStopTap(String stopId) {
    ref.read(searchQueryProvider.notifier).clear();
    Navigator.of(context).pop();
    AppRouter.pushStopDetail(context, stopId);
  }

  /// Cancel button handler: clears state and pops the modal.
  void _onCancel() {
    ref.read(searchQueryProvider.notifier).clear();
    Navigator.of(context).pop();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Watch the search results provider to reactively rebuild when the
    // debounced query updates.
    final searchResultsAsync = ref.watch(searchResultsProvider);

    // Read the current query to decide whether to show recent searches or
    // the result list.
    final query = ref.watch(searchQueryProvider);

    return CupertinoPageScaffold(
      // -- Navigation bar with Cancel button ----------------------------------
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Search'),
        // Cancel button on the trailing side dismisses the modal.
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _onCancel,
          child: const Text('Cancel'),
        ),
        // Remove the automatic back button since this is a modal.
        automaticallyImplyLeading: false,
      ),

      // -- Main content -------------------------------------------------------
      child: SafeArea(
        child: Column(
          children: [
            // ---- Search text field ------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: CupertinoSearchTextField(
                controller: _controller,
                focusNode: _focusNode,
                placeholder: 'Routes, stops, or stop codes',
                onChanged: _onSearchChanged,
                autocorrect: false,
                // Pressing the clear button ('X') in the text field should
                // also reset the provider so the UI switches back to
                // recent searches.
                onSuffixTap: () {
                  _controller.clear();
                  ref.read(searchQueryProvider.notifier).clear();
                },
              ),
            ),

            // ---- Segmented control (Routes | Stops) -------------------------
            // Only show the segment toggle when there is an active query.
            // When the query is empty we show recent searches instead.
            if (query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 4.0,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<_SearchSegment>(
                    groupValue: _selectedSegment,
                    children: const {
                      _SearchSegment.routes: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Routes'),
                      ),
                      _SearchSegment.stops: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Stops'),
                      ),
                    },
                    onValueChanged: (_SearchSegment? value) {
                      if (value != null) {
                        setState(() => _selectedSegment = value);
                      }
                    },
                  ),
                ),
              ),

            const SizedBox(height: 8.0),

            // ---- Content area -----------------------------------------------
            Expanded(
              child: query.isEmpty
                  // No query entered yet -- show recent searches.
                  ? RecentSearches(onRouteTap: _onRouteTap)
                  // Query is active -- show search results.
                  : _buildSearchResults(searchResultsAsync),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Search results list
  // -------------------------------------------------------------------------

  /// Builds the search results list based on the async state from
  /// [searchResultsProvider].
  ///
  /// Handles three states:
  ///   - Loading: centered activity indicator
  ///   - Error: centered error message
  ///   - Data: filtered list of [SearchResultTile] widgets
  Widget _buildSearchResults(AsyncValue<SearchResults> asyncResults) {
    return asyncResults.when(
      // -- Loading state: show a spinner while the DB query runs ----
      loading: () => const Center(
        child: CupertinoActivityIndicator(),
      ),

      // -- Error state: display the error message -------------------
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Search failed: $error',
            style: const TextStyle(
              color: CupertinoColors.systemRed,
              fontSize: 15.0,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),

      // -- Data state: render the filtered result list --------------
      data: (results) {
        // Decide which results to show based on the selected segment.
        final showRoutes = _selectedSegment == _SearchSegment.routes;

        if (showRoutes && results.routes.isEmpty) {
          return _buildEmptyState('No routes found');
        }
        if (!showRoutes && results.stops.isEmpty) {
          return _buildEmptyState('No stops found');
        }

        // Build a scrollable list of result tiles.
        return ListView.builder(
          // Dismisses the keyboard when the user starts scrolling through
          // results, matching standard iOS behavior.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount:
              showRoutes ? results.routes.length : results.stops.length,
          itemBuilder: (context, index) {
            if (showRoutes) {
              // -- Route result tile --
              final route = results.routes[index];
              return SearchResultTile.route(
                routeShortName: route.routeShortName,
                routeLongName: route.routeLongName,
                routeColor: route.routeColor,
                onTap: () => _onRouteTap(route.routeId),
              );
            } else {
              // -- Stop result tile --
              final stop = results.stops[index];
              return SearchResultTile.stop(
                stopName: stop.stopName,
                stopCode: stop.stopCode,
                onTap: () => _onStopTap(stop.stopId),
              );
            }
          },
        );
      },
    );
  }

  /// Builds a centered empty-state message shown when a search returns
  /// no matching results for the selected segment.
  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          message,
          style: const TextStyle(
            color: CupertinoColors.systemGrey,
            fontSize: 15.0,
          ),
        ),
      ),
    );
  }
}
