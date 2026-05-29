import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/routing/event_navigation.dart';
import '../shared/widgets/event_medium_card.dart';
import '../../domain/event/event.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../shared/widgets/gradient_top_bar.dart';
import '../shared/widgets/custom_text_fields.dart';

// --- Recent Searches Provider ---
// Loads and saves recent searches using shared_preferences
class RecentSearchesNotifier extends AsyncNotifier<List<String>> {
  static const _key = 'recent_searches';

  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  // Adds a new search to the top of the list
  Future<void> addSearch(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? [];
    // Remove if already exists to avoid duplicates
    current.remove(query);
    // Add to top of list
    current.insert(0, query);
    // Keep only the last 10 searches
    final trimmed = current.take(10).toList();
    await prefs.setStringList(_key, trimmed);
    state = AsyncData(trimmed);
  }

  // Clears all recent searches
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = const AsyncData([]);
  }
}

final recentSearchesProvider =
    AsyncNotifierProvider<RecentSearchesNotifier, List<String>>(
      () => RecentSearchesNotifier(),
    );

// --- Search Results Provider ---
// Holds the current search results
class SearchResultsNotifier extends Notifier<List<Event>> {
  @override
  List<Event> build() => [];

  void setResults(List<Event> results) => state = results;
}

final searchResultsProvider =
    NotifierProvider<SearchResultsNotifier, List<Event>>(
      () => SearchResultsNotifier(),
    );

// --- Discover Search Screen ---
class DiscoverSearchScreen extends ConsumerStatefulWidget {
  const DiscoverSearchScreen({super.key});

  @override
  ConsumerState<DiscoverSearchScreen> createState() =>
      _DiscoverSearchScreenState();
}

class _DiscoverSearchScreenState extends ConsumerState<DiscoverSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Calls the backend to search for events
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Save to recent searches
      await ref.read(recentSearchesProvider.notifier).addSearch(query);

      // Call Firebase function to search events
      final functions = FirebaseFunctions.instanceFor(region: 'africa-south1');
      final result = await functions.httpsCallable('searchEvents').call({
        'query': query,
      });

      // Parse results into Event list
      final data = result.data as List<dynamic>;
      final events = data.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final id = map['id'] as String? ?? '';
        return Event.fromMap(map, id);
      }).toList();

      ref.read(searchResultsProvider.notifier).setResults(events);
    } catch (e) {
      debugPrint('Search error: $e');
      ref.read(searchResultsProvider.notifier).setResults([]);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentSearchesAsync = ref.watch(recentSearchesProvider);
    final searchResults = ref.watch(searchResultsProvider);
    final query = _searchController.text;

    return Container(
      color: const Color(0xFF0B0E12),
      child: Stack(
        children: [
          const GradientTopBar(
            height: 100,
            showDarkOverlay: false,
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
              leadingWidth: 48,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Search events',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: RoundedTextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      hintText: 'Find an event...',
                      prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                      onSubmitted: (value) => _performSearch(value),
                      onChanged: (value) => setState(() {}),
                      suffixIcon: query.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _searchFocusNode.unfocus();
                                setState(() {});
                              },
                              child: const Icon(Icons.clear, color: Colors.white54, size: 20),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),

            // --- Body Content ---
            Expanded(
              child: _isLoading
                  // Show loading spinner while searching
                  ? const Center(child: CircularProgressIndicator())
                  : query.isEmpty
                  // Show recent searches when search bar is empty
                  ? _buildRecentSearches(recentSearchesAsync)
                  // Show search results when query is not empty
                  : _buildSearchResults(searchResults),
            ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Builds the recent searches list
  Widget _buildRecentSearches(AsyncValue<List<String>> recentSearchesAsync) {
    return recentSearchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const SizedBox.shrink(),
      data: (searches) {
        if (searches.isEmpty) {
          return const Center(
            child: Text(
              'No recent searches',
              style: TextStyle(color: Colors.white38),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with clear button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Searches',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(recentSearchesProvider.notifier).clearAll(),
                    child: const Text(
                      'Clear all',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
            // List of recent searches
            Expanded(
              child: ListView.builder(
                itemCount: searches.length,
                itemBuilder: (context, index) {
                  final search = searches[index];
                  return ListTile(
                    // History icon on the left as per acceptance criteria
                    leading: const Icon(Icons.history, color: Colors.white38),
                    title: Text(
                      search,
                      style: const TextStyle(color: Colors.white),
                    ),
                    // Tapping a recent search runs it again
                    onTap: () {
                      _searchController.text = search;
                      _performSearch(search);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Builds the search results list
  Widget _buildSearchResults(List<Event> events) {
    if (events.isEmpty) {
      return const Center(
        child: Text('No events found', style: TextStyle(color: Colors.white38)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: EventMediumCard(
            event: event,
            onTap: () => pushEventDetail(context, event.id),
          ),
        );
      },
    );
  }
}
