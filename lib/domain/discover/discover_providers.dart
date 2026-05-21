import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'discover_feed.dart';
import '../event/event.dart';
import '../navigation/navigation_providers.dart';

const List<String> discoverCategories = [
  'All',
  'Community',
  'Music',
  'Film',
  'Arts',
  'Fitness',
  'Food',
];

const double kDiscoverDefaultLatitude = -26.2041;
const double kDiscoverDefaultLongitude = 28.0473;

/// How long a successful `tab: All` fetch is reused before refetching.
const Duration kDiscoverFeedCacheTtl = Duration(minutes: 10);

/// Refetch when the user moves more than this many km from the cached coords.
const double kDiscoverLocationRefreshKm = 3.0;

class DiscoverCategoryFilterNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  void setCategory(String category) => state = category;
}

final discoverCategoryFilterProvider =
    NotifierProvider<DiscoverCategoryFilterNotifier, String>(() {
  return DiscoverCategoryFilterNotifier();
});

final userLocationProvider = FutureProvider<Position?>((ref) async {
  try {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getLastKnownPosition() ??
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 3),
          ),
        );
  } catch (e) {
    return null;
  }
});

/// Cached `getDiscoverFeed` (`tab: All`) payload + fetch metadata.
class DiscoverFeedCache {
  final DiscoverFeedAllResponse allResponse;
  final double latitude;
  final double longitude;
  final DateTime fetchedAt;

  const DiscoverFeedCache({
    required this.allResponse,
    required this.latitude,
    required this.longitude,
    required this.fetchedAt,
  });

  bool isExpired(DateTime now) => now.difference(fetchedAt) > kDiscoverFeedCacheTtl;

  bool locationMovedFar(double lat, double lng) {
    return _haversineKm(latitude, longitude, lat, lng) > kDiscoverLocationRefreshKm;
  }
}

class DiscoverFeedCacheNotifier extends AsyncNotifier<DiscoverFeedCache?> {
  @override
  Future<DiscoverFeedCache?> build() async {
    ref.keepAlive();
    // IndexedStack mounts Discover early; defer network until that tab is visible.
    final shellIndex = ref.watch(mainShellIndexProvider);
    if (shellIndex != 1 && state.value == null) {
      return null;
    }
    return _load(force: false);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(force: true));
  }

  Future<DiscoverFeedCache?> _load({required bool force}) async {
    final coords = await ref.read(userLocationProvider.future);
    final lat = coords?.latitude ?? kDiscoverDefaultLatitude;
    final lng = coords?.longitude ?? kDiscoverDefaultLongitude;
    final now = DateTime.now();

    final existing = state.value;
    if (!force &&
        existing != null &&
        !existing.isExpired(now) &&
        !existing.locationMovedFar(lat, lng)) {
      return existing;
    }

    final functions = FirebaseFunctions.instanceFor(region: 'africa-south1');
    final result = await functions.httpsCallable('getDiscoverFeed').call({
      'latitude': lat,
      'longitude': lng,
      'tab': 'All',
    });

    final data = result.data;
    DiscoverFeedAllResponse allResponse;
    if (data is Map) {
      allResponse =
          DiscoverFeedAllResponse.fromMap(Map<String, dynamic>.from(data));
    } else {
      allResponse = const DiscoverFeedAllResponse(
        weekendForecast: [],
        meetNewPeople: [],
        soundcheck: [],
        modernRenaissance: [],
        notForTheWeak: [],
        foodieFrenzy: [],
        silverScreening: [],
        feed: [],
      );
    }

    return DiscoverFeedCache(
      allResponse: allResponse,
      latitude: lat,
      longitude: lng,
      fetchedAt: now,
    );
  }
}

final discoverFeedCacheProvider =
    AsyncNotifierProvider<DiscoverFeedCacheNotifier, DiscoverFeedCache?>(() {
  return DiscoverFeedCacheNotifier();
});

/// View of the cache for the active category chip (no extra network calls).
final discoverFeedProvider = Provider<AsyncValue<DiscoverFeedResult>>((ref) {
  final cacheAsync = ref.watch(discoverFeedCacheProvider);
  final filter = ref.watch(discoverCategoryFilterProvider);

  return cacheAsync.when(
    data: (cache) {
      if (cache == null) {
        return const AsyncData(DiscoverFeedResult.category([]));
      }
      if (filter == 'All') {
        return AsyncData(DiscoverFeedResult.all(cache.allResponse));
      }
      return AsyncData(
        DiscoverFeedResult.category(
          categoryCardsFromAll(cache.allResponse, filter),
        ),
      );
    },
    loading: () => const AsyncLoading(),
    error: (error, stack) => AsyncError(error, stack),
  );
});

List<DiscoverFeedCard> categoryCardsFromAll(
  DiscoverFeedAllResponse all,
  String category,
) {
  if (category == 'All') return all.feed;
  return all.feed.where((c) => c.matchesCategory(category)).toList();
}

List<DiscoverFeedCard> spotlightCardsForFilter(
  DiscoverFeedAllResponse all,
  String filter,
) {
  switch (filter) {
    case 'Community':
      return all.meetNewPeople;
    case 'Music':
      return all.soundcheck;
    case 'Film':
      return all.silverScreening;
    case 'Arts':
      return all.modernRenaissance;
    case 'Fitness':
      return all.notForTheWeak;
    case 'Food':
      return all.foodieFrenzy;
    default:
      return [];
  }
}

List<DiscoverFeedCard> cardsForRouteCategory(
  DiscoverFeedAllResponse all,
  String routeCategory,
) {
  final c = routeCategory.toLowerCase().trim();
  if (c == 'weekend-forecast' || c == 'weekend forecast') {
    return all.weekendForecast;
  }
  if (c == 'music' || c == 'after hours' || c == 'after-hours') {
    return categoryCardsFromAll(all, 'Music');
  }
  if (c == 'community' || c == 'meet new people' || c == 'meet-new-people') {
    return categoryCardsFromAll(all, 'Community');
  }
  if (c == 'arts' || c == 'modern renaissance' || c == 'modern-renaissance') {
    return categoryCardsFromAll(all, 'Arts');
  }
  if (c == 'film' || c == 'silver screen' || c == 'silver-screen') {
    return categoryCardsFromAll(all, 'Film');
  }
  if (c == 'fitness' || c == 'peak performance' || c == 'peak-performance') {
    return categoryCardsFromAll(all, 'Fitness');
  }
  if (c == 'food' || c == 'feast & flavor' || c == 'feast-&-flavor') {
    return categoryCardsFromAll(all, 'Food');
  }
  if (discoverCategories.contains(routeCategory)) {
    return categoryCardsFromAll(all, routeCategory);
  }
  return all.feed;
}

List<Event> _cardsToEvents(List<DiscoverFeedCard> cards) =>
    cards.map((c) => c.toEvent()).toList();

Map<String, DiscoverFeedCard> _cardMapFromAll(DiscoverFeedAllResponse all) {
  final cards = <DiscoverFeedCard>[
    ...all.feed,
    ...all.carouselLists.expand((list) => list),
  ];
  return {for (final c in cards) c.id: c};
}

final discoverFeedCardMapProvider = Provider<Map<String, DiscoverFeedCard>>((ref) {
  final cacheAsync = ref.watch(discoverFeedCacheProvider);
  return cacheAsync.when(
    data: (cache) => cache == null ? {} : _cardMapFromAll(cache.allResponse),
    loading: () => {},
    error: (_, _) => {},
  );
});

final discoverFeedCardMapForRouteProvider =
    Provider.family<Map<String, DiscoverFeedCard>, String>((ref, routeCategory) {
  final cacheAsync = ref.watch(discoverFeedCacheProvider);
  return cacheAsync.when(
    data: (cache) {
      if (cache == null) return {};
      final cards = cardsForRouteCategory(cache.allResponse, routeCategory);
      return {for (final c in cards) c.id: c};
    },
    loading: () => {},
    error: (_, _) => {},
  );
});

final allDiscoverEventsProvider = Provider<List<Event>>((ref) {
  final cacheAsync = ref.watch(discoverFeedCacheProvider);
  return cacheAsync.when(
    data: (cache) =>
        cache == null ? [] : _cardsToEvents(cache.allResponse.feed),
    loading: () => [],
    error: (_, _) => [],
  );
});

List<Event> _carouselFromCache(
  Ref ref,
  List<DiscoverFeedCard> Function(DiscoverFeedAllResponse) pick,
) {
  final cacheAsync = ref.watch(discoverFeedCacheProvider);
  return cacheAsync.when(
    data: (cache) =>
        cache == null ? [] : _cardsToEvents(pick(cache.allResponse)),
    loading: () => [],
    error: (_, _) => [],
  );
}

final discoverWeekendForecastEventsProvider = Provider<List<Event>>((ref) {
  return _carouselFromCache(ref, (r) => r.weekendForecast);
});

final discoverMusicEventsProvider = Provider<List<Event>>((ref) {
  return _carouselFromCache(ref, (r) => r.soundcheck);
});

final discoverFilmEventsProvider = Provider<List<Event>>((ref) {
  return _carouselFromCache(ref, (r) => r.silverScreening);
});

final discoverArtsEventsProvider = Provider<List<Event>>((ref) {
  return _carouselFromCache(ref, (r) => r.modernRenaissance);
});

final discoverFitnessEventsProvider = Provider<List<Event>>((ref) {
  return _carouselFromCache(ref, (r) => r.notForTheWeak);
});

final discoverFoodEventsProvider = Provider<List<Event>>((ref) {
  return _carouselFromCache(ref, (r) => r.foodieFrenzy);
});

final discoverCommunityEventsProvider = Provider<List<Event>>((ref) {
  return _carouselFromCache(ref, (r) => r.meetNewPeople);
});

List<Event> getTop10Popular(List<Event> events) => events.take(10).toList();

List<Event> sortByPopularity(List<Event> events) => events;

final categoryEventsProvider = Provider.family<List<Event>, String>((ref, category) {
  final cacheAsync = ref.watch(discoverFeedCacheProvider);
  return cacheAsync.when(
    data: (cache) {
      if (cache == null) return [];
      return _cardsToEvents(
        cardsForRouteCategory(cache.allResponse, category),
      );
    },
    loading: () => [],
    error: (_, _) => [],
  );
});

final discoverVerticalFeedProvider = Provider<List<Event>>((ref) {
  final activeFilter = ref.watch(discoverCategoryFilterProvider);
  final cacheAsync = ref.watch(discoverFeedCacheProvider);

  return cacheAsync.when(
    data: (cache) {
      if (cache == null) return [];
      final all = cache.allResponse;

      if (activeFilter == 'All') {
        final shownIds = <String>{};
        for (final list in all.carouselLists) {
          for (final card in list) {
            shownIds.add(card.id);
          }
        }
        return _cardsToEvents(
          all.feed.where((c) => !shownIds.contains(c.id)).toList(),
        );
      }

      final categoryCards = categoryCardsFromAll(all, activeFilter);
      final spotlightIds =
          spotlightCardsForFilter(all, activeFilter).map((c) => c.id).toSet();
      return _cardsToEvents(
        categoryCards.where((c) => !spotlightIds.contains(c.id)).toList(),
      );
    },
    loading: () => [],
    error: (_, _) => [],
  );
});

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(lat1)) *
          math.cos(_toRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

double _toRad(double deg) => deg * math.pi / 180.0;
