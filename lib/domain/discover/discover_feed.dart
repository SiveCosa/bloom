import 'package:flutter/foundation.dart';
import '../calendar/scheduled_event.dart';
import '../event/event.dart';
import '../event/event_location.dart';
import '../event/event_visibility.dart';

/// Lightweight card from [getDiscoverFeed] Cloud Function.
class DiscoverFeedCard {
  final String id;
  final String title;
  final String? posterUrl;
  final int? startTimeMillis;
  final String locationName;
  final double distanceKm;
  final List<String> auroraColors;
  final String hostId;
  final String hostUsername;
  final String? hostAvatarUrl;
  final List<String> tags;

  const DiscoverFeedCard({
    required this.id,
    required this.title,
    this.posterUrl,
    this.startTimeMillis,
    required this.locationName,
    required this.distanceKm,
    required this.auroraColors,
    required this.hostId,
    required this.hostUsername,
    this.hostAvatarUrl,
    this.tags = const [],
  });

  factory DiscoverFeedCard.fromMap(Map<String, dynamic> map) {
    return DiscoverFeedCard(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      posterUrl: map['poster_url'] as String?,
      startTimeMillis: (map['start_time'] as num?)?.toInt(),
      locationName: map['location_name'] as String? ?? '',
      distanceKm: (map['distance_km'] as num?)?.toDouble() ?? 0,
      auroraColors: List<String>.from(map['aurora_colors'] ?? []),
      hostId: map['host_id'] as String? ?? '',
      hostUsername: map['host_username'] as String? ?? '',
      hostAvatarUrl: map['host_avatar_url'] as String?,
      tags: List<String>.from(map['tags'] ?? []),
    );
  }

  bool matchesCategory(String category) {
    if (category == 'All') return true;
    final tag = DiscoverFeedCard.categoryTagFor(category);
    if (tag == null) return false;
    final normalized = tags.map((t) => t.toLowerCase().trim()).toList();
    return normalized.contains(tag);
  }

  static String? categoryTagFor(String category) {
    switch (category) {
      case 'Community':
        return 'community';
      case 'Music':
        return 'music';
      case 'Film':
        return 'film';
      case 'Arts':
        return 'arts';
      case 'Fitness':
        return 'fitness';
      case 'Food':
        return 'food';
      case 'Education':
        return 'education';
      default:
        return null;
    }
  }

  DateTime? get startTime => startTimeMillis != null
      ? DateTime.fromMillisecondsSinceEpoch(startTimeMillis!)
      : null;

  ScheduledEvent toScheduledEvent() {
    final start = startTime ?? DateTime.now();
    return ScheduledEvent(
      id: id,
      title: title,
      posterUrl: posterUrl,
      startTime: start,
      endTime: DateTime(start.year, start.month, start.day, 23, 59, 59),
      hostName: hostUsername,
      hostId: hostId,
      hostImageUrl: hostAvatarUrl,
      auroraColors: auroraColors,
      locationName: locationName,
    );
  }

  Event toEvent() {
    final start = startTime;
    return Event(
      id: id,
      title: title,
      description: '',
      tags: tags,
      visuals: EventVisuals(
        posterUrl: posterUrl,
        aspectRatio: 1.0,
        auroraColors: auroraColors,
      ),
      timing: EventTiming(startDate: start, startTimeTbd: start == null),
      location: EventLocation(
        displayName: locationName,
        formattedAddress: locationName,
        latitude: 0,
        longitude: 0,
        geohash: '',
      ),
      audience: const EventAudience(visibility: EventVisibility.public),
      extras: const [],
      rsvpReminders: const [],
      liveCounts: const EventLiveCounts(),
      previewGuests: const [],
      metadata: EventMetadata(
        hostId: hostId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: EventStatus.active,
      ),
    );
  }
}

/// Structured response when tab is `All`.
class DiscoverFeedAllResponse {
  final List<DiscoverFeedCard> weekendForecast;
  final List<DiscoverFeedCard> community;
  final List<DiscoverFeedCard> music;
  final List<DiscoverFeedCard> arts;
  final List<DiscoverFeedCard> fitness;
  final List<DiscoverFeedCard> food;
  final List<DiscoverFeedCard> film;
  final List<DiscoverFeedCard> education;
  final List<DiscoverFeedCard> feed;

  const DiscoverFeedAllResponse({
    required this.weekendForecast,
    required this.community,
    required this.music,
    required this.arts,
    required this.fitness,
    required this.food,
    required this.film,
    required this.education,
    required this.feed,
  });

  factory DiscoverFeedAllResponse.fromMap(Map<String, dynamic> map) {
    List<DiscoverFeedCard> parseList(String key) {
      final raw = map[key];
      if (raw is! List) return [];
      final cards = <DiscoverFeedCard>[];
      for (final item in raw) {
        if (item is! Map) continue;
        try {
          cards.add(DiscoverFeedCard.fromMap(Map<String, dynamic>.from(item)));
        } catch (e) {
          debugPrint('DiscoverFeedCard parse skip: $e');
        }
      }
      return cards;
    }

    return DiscoverFeedAllResponse(
      weekendForecast: parseList('weekend_forecast'),
      community: parseList('community'),
      music: parseList('music'),
      arts: parseList('arts'),
      fitness: parseList('fitness'),
      food: parseList('food'),
      film: parseList('film'),
      education: parseList('education'),
      feed: parseList('feed'),
    );
  }

  Iterable<List<DiscoverFeedCard>> get carouselLists => [
    weekendForecast,
    community,
    music,
    arts,
    fitness,
    food,
    film,
    education,
  ];
}

/// Union result from [getDiscoverFeed].
class DiscoverFeedResult {
  final DiscoverFeedAllResponse? allTab;
  final List<DiscoverFeedCard>? categoryFeed;

  const DiscoverFeedResult.all(DiscoverFeedAllResponse response)
    : allTab = response,
      categoryFeed = null;

  const DiscoverFeedResult.category(List<DiscoverFeedCard> cards)
    : allTab = null,
      categoryFeed = cards;

  bool get isAllTab => allTab != null;

  List<DiscoverFeedCard> cardsForCategoryTab() => categoryFeed ?? [];

  List<Event> toEvents(List<DiscoverFeedCard> cards) =>
      cards.map((c) => c.toEvent()).toList();
}
