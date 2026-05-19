import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../calendar/scheduled_event.dart';
import '../event/event.dart';
import '../event/event_visibility.dart';
import '../event/event_location.dart';

// List of Discover Categories
const List<String> discoverCategories = [
  'All',
  'Trending',
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

// Provider for Spotlight Carousels: returns a list of ScheduledEvents based on title
final discoverSpotlightEventsProvider = Provider.family<List<ScheduledEvent>, String>((ref, title) {
  // Let's return different mock ScheduledEvents depending on the carousel title
  if (title == 'Trending Now') {
    return [
      ScheduledEvent(
        id: 'spot_trend_1',
        title: 'Neon Resonance: Synthwave Night',
        posterUrl: 'https://picsum.photos/seed/synthwave/400/400',
        startTime: DateTime.now().add(const Duration(days: 1, hours: 4)),
        endTime: DateTime.now().add(const Duration(days: 1, hours: 8)),
        hostName: 'DJ CyberSonik',
        hostId: 'host_cyb',
        hostImageUrl: 'https://picsum.photos/seed/host1/100/100',
        auroraColors: ['#AD83FE', '#00F0FF'],
        locationName: 'The Underground Club',
      ),
      ScheduledEvent(
        id: 'spot_trend_2',
        title: 'Retro Film Reel: Sci-Fi Marathon',
        posterUrl: 'https://picsum.photos/seed/scifi/400/400',
        startTime: DateTime.now().add(const Duration(days: 2, hours: 2)),
        endTime: DateTime.now().add(const Duration(days: 2, hours: 6)),
        hostName: 'Cinema Club',
        hostId: 'host_cinema',
        hostImageUrl: 'https://picsum.photos/seed/host2/100/100',
        auroraColors: ['#FF0055', '#4A00E0'],
        locationName: 'Bioscope Theatre',
      ),
      ScheduledEvent(
        id: 'spot_trend_3',
        title: 'Abstract Canvas: Live Gallery',
        posterUrl: 'https://picsum.photos/seed/gallery/400/400',
        startTime: DateTime.now().add(const Duration(days: 3, hours: 5)),
        endTime: DateTime.now().add(const Duration(days: 3, hours: 9)),
        hostName: 'Elena Rostova',
        hostId: 'host_elena',
        hostImageUrl: 'https://picsum.photos/seed/host3/100/100',
        auroraColors: ['#FFD60A', '#FF9F0A'],
        locationName: 'Vivid Art Loft',
      ),
    ];
  } else if (title == 'From your friends') {
    return [
      ScheduledEvent(
        id: 'spot_friends_1',
        title: 'Urban Rooftop Cookout',
        posterUrl: 'https://picsum.photos/seed/cookout/400/400',
        startTime: DateTime.now().add(const Duration(days: 4, hours: 3)),
        endTime: DateTime.now().add(const Duration(days: 4, hours: 7)),
        hostName: 'Marcus Brodie',
        hostId: 'host_marcus',
        hostImageUrl: 'https://picsum.photos/seed/host4/100/100',
        auroraColors: ['#32D74B', '#FF9F0A'],
        locationName: 'Skyline Terrace',
      ),
      ScheduledEvent(
        id: 'spot_friends_2',
        title: 'Sunset Yoga & Mindfulness',
        posterUrl: 'https://picsum.photos/seed/yoga/400/400',
        startTime: DateTime.now().add(const Duration(days: 5, hours: 6)),
        endTime: DateTime.now().add(const Duration(days: 5, hours: 9)),
        hostName: 'Chloe Jenkins',
        hostId: 'host_chloe',
        hostImageUrl: 'https://picsum.photos/seed/host5/100/100',
        auroraColors: ['#00F0FF', '#32D74B'],
        locationName: 'Green Gardens Park',
      ),
      ScheduledEvent(
        id: 'spot_friends_3',
        title: 'Indie Acoustica Night',
        posterUrl: 'https://picsum.photos/seed/acoustic/400/400',
        startTime: DateTime.now().add(const Duration(days: 6, hours: 4)),
        endTime: DateTime.now().add(const Duration(days: 6, hours: 8)),
        hostName: 'Dave & Friends',
        hostId: 'host_dave',
        hostImageUrl: 'https://picsum.photos/seed/host6/100/100',
        auroraColors: ['#FF5E62', '#FF9966'],
        locationName: 'Whispering Pines Cafe',
      ),
    ];
  } else {
    // 'Popular Nearby' or fallback
    return [
      ScheduledEvent(
        id: 'spot_nearby_1',
        title: 'Culinary Masterclass: Pastries',
        posterUrl: 'https://picsum.photos/seed/pastry/400/400',
        startTime: DateTime.now().add(const Duration(days: 7, hours: 2)),
        endTime: DateTime.now().add(const Duration(days: 7, hours: 5)),
        hostName: 'Chef Pierre',
        hostId: 'host_pierre',
        hostImageUrl: 'https://picsum.photos/seed/host7/100/100',
        auroraColors: ['#FF0055', '#FFD60A'],
        locationName: 'Savory Studio',
      ),
      ScheduledEvent(
        id: 'spot_nearby_2',
        title: 'Cyberpunk Coding Hackathon',
        posterUrl: 'https://picsum.photos/seed/hackathon/400/400',
        startTime: DateTime.now().add(const Duration(days: 8, hours: 8)),
        endTime: DateTime.now().add(const Duration(days: 8, hours: 18)),
        hostName: 'Bloom Tech',
        hostId: 'host_tech',
        hostImageUrl: 'https://picsum.photos/seed/host8/100/100',
        auroraColors: ['#00F0FF', '#4A00E0'],
        locationName: 'Tech Hive Hub',
      ),
      ScheduledEvent(
        id: 'spot_nearby_3',
        title: 'Metropolitan Film Gala',
        posterUrl: 'https://picsum.photos/seed/gala/400/400',
        startTime: DateTime.now().add(const Duration(days: 9, hours: 7)),
        endTime: DateTime.now().add(const Duration(days: 9, hours: 11)),
        hostName: 'City Cinema Trust',
        hostId: 'host_trust',
        hostImageUrl: 'https://picsum.photos/seed/host9/100/100',
        auroraColors: ['#AD83FE', '#FF0055'],
        locationName: 'Palace Cinema',
      ),
    ];
  }
});

// Helper builder for Event
Event _buildMockEvent({
  required String id,
  required String title,
  required String description,
  required String categoryTag,
  required String posterUrl,
  required DateTime startDate,
  required String locationName,
  required String hostId,
  required List<String> auroraColors,
}) {
  return Event(
    id: id,
    title: title,
    description: description,
    tags: [categoryTag, 'Discover'],
    visuals: EventVisuals(
      posterUrl: posterUrl,
      aspectRatio: 1.0,
      auroraColors: auroraColors,
    ),
    timing: EventTiming(
      startDate: startDate,
      startTimeTbd: false,
    ),
    location: EventLocation(
      displayName: locationName,
      formattedAddress: locationName,
      latitude: 0.0,
      longitude: 0.0,
      geohash: '',
    ),
    audience: const EventAudience(
      visibility: EventVisibility.public,
    ),
    extras: const [],
    rsvpReminders: const [],
    liveCounts: const EventLiveCounts(going: 12, interested: 45),
    previewGuests: const [],
    metadata: EventMetadata(
      hostId: hostId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: EventStatus.active,
    ),
  );
}

// Provider for all Discover events
final allDiscoverEventsProvider = Provider<List<Event>>((ref) {
  return [
    _buildMockEvent(
      id: 'feed_ev_1',
      title: 'Acoustic Guitar Workshop',
      description: 'Learn the fundamentals of acoustic playing. Open to beginners and intermediate guitar players. Bring your own guitar or borrow one.',
      categoryTag: 'Music',
      posterUrl: 'https://picsum.photos/seed/guitar/400/400',
      startDate: DateTime.now().add(const Duration(days: 1, hours: 2)),
      locationName: 'Melody Music School',
      hostId: 'host_guitar',
      auroraColors: ['#FF9966', '#FF5E62'],
    ),
    _buildMockEvent(
      id: 'feed_ev_2',
      title: 'Indie Movie Night: Cult Classics',
      description: 'A cozy screening of two classic independent films, followed by a casual panel discussion with film buffs.',
      categoryTag: 'Film',
      posterUrl: 'https://picsum.photos/seed/movie/400/400',
      startDate: DateTime.now().add(const Duration(days: 2, hours: 7)),
      locationName: 'The Backstage Theater',
      hostId: 'host_movie',
      auroraColors: ['#FF0055', '#4A00E0'],
    ),
    _buildMockEvent(
      id: 'feed_ev_3',
      title: 'High-Intensity Cardio Blast',
      description: 'Get your sweat on with a 45-minute high intensity interval training session. All fitness levels welcome.',
      categoryTag: 'Fitness',
      posterUrl: 'https://picsum.photos/seed/cardio/400/400',
      startDate: DateTime.now().add(const Duration(days: 3, hours: 1)),
      locationName: 'Active Life Center',
      hostId: 'host_fitness',
      auroraColors: ['#32D74B', '#00F0FF'],
    ),
    _buildMockEvent(
      id: 'feed_ev_4',
      title: 'Street Food Fair: Food Trucks',
      description: 'Join us for local food trucks, delicious street foods, dynamic music, and a warm neighborhood atmosphere.',
      categoryTag: 'Food',
      posterUrl: 'https://picsum.photos/seed/streetfood/400/400',
      startDate: DateTime.now().add(const Duration(days: 4, hours: 4)),
      locationName: 'Central Plaza Lot B',
      hostId: 'host_food',
      auroraColors: ['#FFD60A', '#FF9F0A'],
    ),
    _buildMockEvent(
      id: 'feed_ev_5',
      title: 'Improv Comedy Workshop',
      description: 'Unlock your creativity and practice spontaneous thinking. No acting experience required!',
      categoryTag: 'Community',
      posterUrl: 'https://picsum.photos/seed/comedy/400/400',
      startDate: DateTime.now().add(const Duration(days: 5, hours: 3)),
      locationName: 'The Laughing Lounge',
      hostId: 'host_comedy',
      auroraColors: ['#AD83FE', '#FF0055'],
    ),
    _buildMockEvent(
      id: 'feed_ev_6',
      title: 'Pottery Painting Session',
      description: 'Pick a piece of pre-made pottery and make it yours. All materials and painting instruction provided.',
      categoryTag: 'Arts',
      posterUrl: 'https://picsum.photos/seed/pottery/400/400',
      startDate: DateTime.now().add(const Duration(days: 6, hours: 2)),
      locationName: 'Clay & Colors Studio',
      hostId: 'host_pottery',
      auroraColors: ['#00F0FF', '#32D74B'],
    ),
  ];
});

// Provider for Vertical Feed events that reacts to selected chip filter
final discoverVerticalFeedProvider = Provider<List<Event>>((ref) {
  final activeFilter = ref.watch(discoverCategoryFilterProvider);
  final allEvents = ref.watch(allDiscoverEventsProvider);

  if (activeFilter == 'All') {
    return allEvents;
  } else if (activeFilter == 'Trending') {
    // Mock trending by returning the first 3 events
    return allEvents.take(3).toList();
  } else {
    // Filter by the tag matching category name
    return allEvents.where((e) => e.tags.contains(activeFilter)).toList();
  }
});

// Provider family for specific category detail page
final categoryEventsProvider = Provider.family<List<Event>, String>((ref, category) {
  final allEvents = ref.watch(allDiscoverEventsProvider);

  if (category.toLowerCase() == 'all') {
    return allEvents;
  } else if (category.toLowerCase() == 'trending') {
    return allEvents.take(3).toList();
  } else {
    // case-insensitive matching
    return allEvents.where((e) => e.tags.any((t) => t.toLowerCase() == category.toLowerCase())).toList();
  }
});

