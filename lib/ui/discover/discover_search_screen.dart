import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/routing/event_navigation.dart';
import '../../domain/auth/auth_providers.dart';
import '../../domain/discover/discover_feed.dart';
import '../../domain/discover/discover_providers.dart';
import '../../domain/calendar/scheduled_event.dart';
import '../shared/widgets/gradient_top_bar.dart';
import '../shared/widgets/custom_text_fields.dart';
import '../widgets/scheduled_event_card.dart';

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
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _submitSearch(String query) {
    if (query.trim().isNotEmpty) {
      ref.read(recentSearchesProvider.notifier).addSearch(query);
    }
    _searchFocusNode.unfocus();
  }

  List<ScheduledEvent> _filterEvents(DiscoverFeedCache? cache) {
    if (cache == null || _query.isEmpty) return [];

    final allCards = <String, DiscoverFeedCard>{};
    for (final card in cache.allResponse.feed) {
      allCards[card.id] = card;
    }
    for (final list in cache.allResponse.carouselLists) {
      for (final card in list) {
        allCards[card.id] = card;
      }
    }

    return allCards.values.where((card) {
      final title = card.title.toLowerCase();
      final hostName = card.hostUsername.toLowerCase();
      return title.contains(_query) || hostName.contains(_query);
    }).map((c) => c.toScheduledEvent()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final recentSearchesAsync = ref.watch(recentSearchesProvider);
    final cacheAsync = ref.watch(discoverFeedCacheProvider);
    final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;
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
                      onSubmitted: _submitSearch,
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

                  Expanded(
                    child: query.isEmpty
                        // Show recent searches when search bar is empty
                        ? _buildRecentSearches(recentSearchesAsync)
                        // Show search results when query is not empty
                        : _buildSearchResults(cacheAsync, currentUserId),
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
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: Colors.white24,
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Search Bloom',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Find events, friends, and hosts in your area',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      _submitSearch(search);
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

  Widget _buildSearchResults(AsyncValue<DiscoverFeedCache?> cacheAsync, String? currentUserId) {
    return cacheAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0086D8))),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error.toString(),
            style: const TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (cache) {
        final results = _filterEvents(cache);

        if (results.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    color: Colors.white24,
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No events found',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "We couldn't find any events matching your search",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final event = results[index];
            final isHost = currentUserId != null &&
                (currentUserId == event.hostId ||
                    event.coHostIds.contains(currentUserId));

            return ScheduledEventCard(
              event: event,
              isHost: isHost,
              onTap: () => pushEventDetail(context, event.id),
            );
          },
        );
      },
    );
  }
}
