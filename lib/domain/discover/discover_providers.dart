import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/firebase_provider.dart';
import '../event/event.dart';
import '../event/event_visibility.dart';

// List of Discover Categories
const List<String> discoverCategories = [
  'All',
  'Community',
  'Music',
  'Film',
  'Arts',
  'Fitness',
  'Food',
];

class DiscoverCategoryFilterNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  void setCategory(String category) => state = category;
}

// Discover category filter state provider
final discoverCategoryFilterProvider = NotifierProvider<DiscoverCategoryFilterNotifier, String>(() {
  return DiscoverCategoryFilterNotifier();
});

// Stream provider to fetch active public events from Firestore
final discoverActiveEventsStreamProvider = StreamProvider<List<Event>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('events')
      .where('metadata.status', isEqualTo: 'active')
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => Event.fromMap(doc.data(), doc.id))
        .where((event) => event.audience.visibility == EventVisibility.public)
        .toList();
  });
});

// Provider for all Discover events
final allDiscoverEventsProvider = Provider<List<Event>>((ref) {
  final activeEventsAsync = ref.watch(discoverActiveEventsStreamProvider);
  return activeEventsAsync.value ?? [];
});

// Provider for user location coordinates
final userLocationProvider = FutureProvider<Position?>((ref) async {
  try {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getLastKnownPosition() ?? await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 3),
      ),
    );
  } catch (e) {
    return null;
  }
});

// Special Filter: Weekend Forecast (Friday 00:00:00 to Sunday 23:59:59, within 100km of user location)
final discoverWeekendForecastEventsProvider = Provider<List<Event>>((ref) {
  final allEvents = ref.watch(allDiscoverEventsProvider);
  final userLoc = ref.watch(userLocationProvider).value;

  final now = DateTime.now();
  int daysToFriday = 5 - now.weekday;
  if (now.weekday == 6) daysToFriday = -1;
  if (now.weekday == 7) daysToFriday = -2;

  final weekendStart = DateTime(now.year, now.month, now.day).add(Duration(days: daysToFriday));
  final weekendEnd = weekendStart.add(const Duration(days: 2, hours: 23, minutes: 59, seconds: 59));

  return allEvents.where((event) {
    if (event.timing.startDate == null) return false;
    final start = event.timing.startDate!;
    final end = event.timing.effectiveEndDate ?? start;

    final isInWeekend = start.isBefore(weekendEnd) && end.isAfter(weekendStart);
    if (!isInWeekend) return false;

    if (userLoc != null && event.location != null) {
      final distance = Geolocator.distanceBetween(
        userLoc.latitude,
        userLoc.longitude,
        event.location!.latitude,
        event.location!.longitude,
      );
      if (distance > 100000) return false; // 100km limit
    }
    return true;
  }).toList();
});

// Category Filter Providers
final discoverMusicEventsProvider = Provider<List<Event>>((ref) {
  final allEvents = ref.watch(allDiscoverEventsProvider);
  return allEvents.where((e) => e.tags.any((t) => t.toLowerCase() == 'music')).toList();
});

final discoverFilmEventsProvider = Provider<List<Event>>((ref) {
  final allEvents = ref.watch(allDiscoverEventsProvider);
  return allEvents.where((e) => e.tags.any((t) => t.toLowerCase() == 'film')).toList();
});

final discoverArtsEventsProvider = Provider<List<Event>>((ref) {
  final allEvents = ref.watch(allDiscoverEventsProvider);
  return allEvents.where((e) => e.tags.any((t) => t.toLowerCase() == 'arts')).toList();
});

final discoverFitnessEventsProvider = Provider<List<Event>>((ref) {
  final allEvents = ref.watch(allDiscoverEventsProvider);
  return allEvents.where((e) => e.tags.any((t) => t.toLowerCase() == 'fitness')).toList();
});

final discoverFoodEventsProvider = Provider<List<Event>>((ref) {
  final allEvents = ref.watch(allDiscoverEventsProvider);
  return allEvents.where((e) => e.tags.any((t) => t.toLowerCase() == 'food')).toList();
});

final discoverCommunityEventsProvider = Provider<List<Event>>((ref) {
  final allEvents = ref.watch(allDiscoverEventsProvider);
  return allEvents.where((e) => e.tags.any((t) => t.toLowerCase() == 'community')).toList();
});

// Popularity sorting helpers
List<Event> sortByPopularity(List<Event> events) {
  final list = List<Event>.from(events);
  list.sort((a, b) {
    final scoreA = a.liveCounts.going + a.liveCounts.interested;
    final scoreB = b.liveCounts.going + b.liveCounts.interested;
    return scoreB.compareTo(scoreA);
  });
  return list;
}

List<Event> getTop10Popular(List<Event> events) {
  return sortByPopularity(events).take(10).toList();
}

// Provider for specific category/filter pages
final categoryEventsProvider = Provider.family<List<Event>, String>((ref, category) {
  final allEvents = ref.watch(allDiscoverEventsProvider);
  final cleanCategory = category.toLowerCase().trim();

  if (cleanCategory == 'all') {
    return allEvents;
  } else if (cleanCategory == 'weekend-forecast' || cleanCategory == 'weekend forecast') {
    return ref.watch(discoverWeekendForecastEventsProvider);
  } else if (cleanCategory == 'music' || cleanCategory == 'after hours' || cleanCategory == 'after-hours') {
    return ref.watch(discoverMusicEventsProvider);
  } else if (cleanCategory == 'community' || cleanCategory == 'meet new people' || cleanCategory == 'meet-new-people') {
    return ref.watch(discoverCommunityEventsProvider);
  } else if (cleanCategory == 'arts' || cleanCategory == 'modern renaissance' || cleanCategory == 'modern-renaissance') {
    return ref.watch(discoverArtsEventsProvider);
  } else if (cleanCategory == 'film' || cleanCategory == 'silver screen' || cleanCategory == 'silver-screen') {
    return ref.watch(discoverFilmEventsProvider);
  } else if (cleanCategory == 'fitness' || cleanCategory == 'peak performance' || cleanCategory == 'peak-performance') {
    return ref.watch(discoverFitnessEventsProvider);
  } else if (cleanCategory == 'food' || cleanCategory == 'feast & flavor' || cleanCategory == 'feast-&-flavor') {
    return ref.watch(discoverFoodEventsProvider);
  } else {
    return allEvents.where((e) => e.tags.any((t) => t.toLowerCase() == cleanCategory)).toList();
  }
});

// Provider for Vertical Feed events that reacts to selected chip filter and prevents duplication
final discoverVerticalFeedProvider = Provider<List<Event>>((ref) {
  final activeFilter = ref.watch(discoverCategoryFilterProvider);
  final allEvents = ref.watch(allDiscoverEventsProvider);

  if (activeFilter == 'All') {
    final weekendEvents = ref.watch(discoverWeekendForecastEventsProvider);
    final weekendPopular = getTop10Popular(weekendEvents);
    
    final musicPopular = getTop10Popular(ref.watch(discoverMusicEventsProvider));
    final communityPopular = getTop10Popular(ref.watch(discoverCommunityEventsProvider));
    final artsPopular = getTop10Popular(ref.watch(discoverArtsEventsProvider));
    final filmPopular = getTop10Popular(ref.watch(discoverFilmEventsProvider));
    final fitnessPopular = getTop10Popular(ref.watch(discoverFitnessEventsProvider));
    final foodPopular = getTop10Popular(ref.watch(discoverFoodEventsProvider));

    final shownIds = <String>{};
    if (weekendEvents.isNotEmpty) shownIds.addAll(weekendPopular.map((e) => e.id));
    if (musicPopular.isNotEmpty) shownIds.addAll(musicPopular.map((e) => e.id));
    if (communityPopular.isNotEmpty) shownIds.addAll(communityPopular.map((e) => e.id));
    if (artsPopular.isNotEmpty) shownIds.addAll(artsPopular.map((e) => e.id));
    if (filmPopular.isNotEmpty) shownIds.addAll(filmPopular.map((e) => e.id));
    if (fitnessPopular.isNotEmpty) shownIds.addAll(fitnessPopular.map((e) => e.id));
    if (foodPopular.isNotEmpty) shownIds.addAll(foodPopular.map((e) => e.id));

    return allEvents.where((e) => !shownIds.contains(e.id)).toList();
  } else {
    final categoryEvents = ref.watch(categoryEventsProvider(activeFilter));
    final top10 = getTop10Popular(categoryEvents);
    final top10Ids = top10.map((e) => e.id).toSet();

    return categoryEvents.where((e) => !top10Ids.contains(e.id)).toList();
  }
});


