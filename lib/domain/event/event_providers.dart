import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/event/event_repository.dart';
import '../../data/firebase_provider.dart' hide firebaseAuthProvider;
import '../auth/auth_providers.dart';
import '../calendar/calendar_providers.dart';
import '../location/location_service.dart';
import 'event.dart';
import '../calendar/scheduled_event.dart';
import 'event_visibility.dart';
import 'event_location.dart';

final hostedEventsProvider = StreamProvider<List<Event>>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return Stream.value([]);

  return ref
      .watch(eventRepositoryProvider)
      .getHostedAndCoHostedEventsStream(user.uid);
});

/// Event ids where the user is host or cohost (for joined-count filtering).
final hostedOrCoHostedEventIdsProvider = Provider<Set<String>>((ref) {
  final events = ref.watch(hostedEventsProvider).value ?? [];
  return events.map((e) => e.id).toSet();
});

final profileHostedCountProvider = Provider<int>((ref) {
  return ref.watch(hostedEventsProvider).value?.length ?? 0;
});

final profileJoinedCountProvider = Provider<int>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return 0;
  final schedule = ref.watch(scheduleStreamProvider).value ?? [];
  final excludeIds = ref.watch(hostedOrCoHostedEventIdsProvider);
  return schedule.where((e) {
    if (excludeIds.contains(e.id)) return false;
    final status = e.rsvpStatus;
    if (status == 'maybe' || status == 'interested') return false;
    return status == null || status == 'going';
  }).length;
});

final publicProfileHostedCountProvider = Provider.family<int, String>((
  ref,
  userId,
) {
  return ref.watch(publicHostedEventsProvider(userId)).value?.length ?? 0;
});

final publicProfileJoinedCountProvider = Provider.family<int, String>((
  ref,
  userId,
) {
  final schedule = ref.watch(publicScheduleStreamProvider(userId)).value ?? [];
  final excludeIds =
      ref
          .watch(publicHostedEventsProvider(userId))
          .value
          ?.map((e) => e.id)
          .toSet() ??
      {};
  return schedule.where((e) {
    if (excludeIds.contains(e.id)) return false;
    final status = e.rsvpStatus;
    if (status == 'maybe' || status == 'interested') return false;
    return status == null || status == 'going';
  }).length;
});

final eventStreamProvider = StreamProvider.family<Event?, String>((
  ref,
  eventId,
) {
  return ref.watch(eventRepositoryProvider).getEventStream(eventId);
});

final userEventRsvpProvider = StreamProvider.family<String?, String>((
  ref,
  eventId,
) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return Stream.value(null);
  return ref
      .watch(eventRepositoryProvider)
      .getUserRSVPStream(eventId, user.uid);
});

final eventGuestsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, eventId) {
      return ref.watch(eventRepositoryProvider).getEventGuestsStream(eventId);
    });

final publicHostedEventsProvider = StreamProvider.family<List<Event>, String>((
  ref,
  userId,
) {
  return ref
      .watch(eventRepositoryProvider)
      .getHostedAndCoHostedEventsStream(userId);
});

final joinedEventsProvider = StreamProvider<List<Event>>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return Stream.value([]);

  return ref.watch(eventRepositoryProvider).getJoinedEventsStream(user.uid);
});

final publicJoinedEventsProvider = StreamProvider.autoDispose
    .family<List<Event>, String>((ref, userId) {
      if (userId.trim().isEmpty) return Stream.value([]);
      return ref.watch(eventRepositoryProvider).getJoinedEventsStream(userId);
    });

/// Upcoming joining + hosting events for the public profile being viewed ([profileUserId]).
final publicProfileUpcomingEventsProvider = Provider.autoDispose
    .family<AsyncValue<List<ScheduledEvent>>, String>((ref, profileUserId) {
      if (profileUserId.trim().isEmpty) return const AsyncValue.data([]);

      final joinedAsync = ref.watch(publicJoinedEventsProvider(profileUserId));
      final hostedAsync = ref.watch(publicHostedEventsProvider(profileUserId));

      if (joinedAsync.isLoading || hostedAsync.isLoading) {
        if (!joinedAsync.hasValue && !hostedAsync.hasValue) {
          return const AsyncLoading();
        }
      }

      if (joinedAsync.hasError) {
        return AsyncError(joinedAsync.error!, joinedAsync.stackTrace!);
      }
      if (hostedAsync.hasError) {
        return AsyncError(hostedAsync.error!, hostedAsync.stackTrace!);
      }

      final joined = joinedAsync.value ?? [];
      final hosted = hostedAsync.value ?? [];

      final profileDoc = ref
          .watch(userProfileStreamProvider(profileUserId))
          .value;
      final profileName =
          profileDoc?['name']?.toString() ??
          profileDoc?['username']?.toString() ??
          '';

      final now = DateTime.now();
      final allEventsById = <String, Event>{};

      for (final e in joined) {
        allEventsById[e.id] = e;
      }
      for (final e in hosted) {
        allEventsById[e.id] = e;
      }

      final allEvents = allEventsById.values.toList();

      final validEvents = allEvents.where((e) {
        final end =
            e.timing.effectiveEndDate ??
            e.timing.startDate ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return end.isAfter(now);
      }).toList();

      final scheduledEvents = validEvents.map((e) {
        final end =
            e.timing.effectiveEndDate ??
            e.timing.startDate ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return ScheduledEvent(
          id: e.id,
          title: e.title,
          posterUrl: e.visuals.posterUrl,
          startTime: e.timing.startDate,
          endTime: end,
          hostName: e.metadata.hostId == profileUserId ? profileName : '',
          hostId: e.metadata.hostId,
          auroraColors: e.visuals.auroraColors,
          locationName: e.location?.displayName ?? '',
          coHostIds: e.coHostIds,
        );
      }).toList();

      scheduledEvents.sort((a, b) {
        if (a.startTime == null && b.startTime == null) return 0;
        if (a.startTime == null) return -1;
        if (b.startTime == null) return 1;
        return a.startTime!.compareTo(b.startTime!);
      });

      return AsyncData(scheduledEvents.take(5).toList());
    });

/// Max events shown in a home horizontal carousel (For You + In your Area).
const int kHomeFeedCarouselLimit = 10;

List<Map<String, dynamic>> _filterHostedFeedMaps(
  List<Map<String, dynamic>> rawList,
  Ref ref,
) {
  final user = ref.read(firebaseAuthProvider).currentUser;
  final hostedIds = ref.read(hostedOrCoHostedEventIdsProvider);

  return rawList.where((map) {
    final id = map['id'] as String? ?? '';
    final hostId = map['host_id'] as String? ?? '';
    if (hostedIds.contains(id)) return false;
    if (user != null && hostId == user.uid) return false;
    return true;
  }).toList();
}

ScheduledEvent _mapFeedToScheduledEvent(Map<String, dynamic> map) {
  final startTimeMillis = map['start_time'] as int?;
  final start = startTimeMillis != null
      ? DateTime.fromMillisecondsSinceEpoch(startTimeMillis)
      : null;

  return ScheduledEvent(
    id: map['id'] as String? ?? '',
    title: map['title'] as String? ?? '',
    posterUrl: map['poster_url'] as String?,
    startTime: start,
    endTime: start != null
        ? DateTime(start.year, start.month, start.day, 23, 59, 59)
        : DateTime.now(),
    hostName: map['host_username'] as String? ?? '',
    hostId: map['host_id'] as String? ?? '',
    hostImageUrl: map['host_avatar_url'] as String?,
    auroraColors: List<String>.from(map['aurora_colors'] ?? []),
    locationName: map['location_name'] as String? ?? '',
  );
}

Event _mapFeedToEvent(Map<String, dynamic> map) {
  final startTimeMillis = map['start_time'] as int?;
  final start = startTimeMillis != null
      ? DateTime.fromMillisecondsSinceEpoch(startTimeMillis)
      : null;

  return Event(
    id: map['id'] as String? ?? '',
    title: map['title'] as String? ?? '',
    description: '',
    tags: const [],
    visuals: EventVisuals(
      posterUrl: map['poster_url'] as String?,
      aspectRatio: 1.0,
      auroraColors: List<String>.from(map['aurora_colors'] ?? []),
    ),
    timing: EventTiming(startDate: start, startTimeTbd: start == null),
    location: EventLocation(
      displayName: map['location_name'] as String? ?? '',
      formattedAddress: map['location_name'] as String? ?? '',
      latitude: 0.0,
      longitude: 0.0,
      geohash: '',
    ),
    audience: const EventAudience(visibility: EventVisibility.public),
    extras: const [],
    rsvpReminders: const [],
    liveCounts: const EventLiveCounts(),
    previewGuests: const [],
    metadata: EventMetadata(
      hostId: map['host_id'] as String? ?? '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: EventStatus.active,
    ),
  );
}

List<ScheduledEvent> _mapRawFeedToScheduledEvents(
  List<Map<String, dynamic>> rawList,
  Ref ref,
) {
  return _filterHostedFeedMaps(
    rawList,
    ref,
  ).map(_mapFeedToScheduledEvent).toList();
}

List<Event> _mapRawFeedToEvents(List<Map<String, dynamic>> rawList, Ref ref) {
  return _filterHostedFeedMaps(rawList, ref).map(_mapFeedToEvent).toList();
}

Future<GeoPoint?> _readUserGeoPoint(
  FirebaseFirestore firestore,
  String uid,
) async {
  final snap = await firestore.collection('users').doc(uid).get();
  final location = snap.data()?['location'];
  if (location is GeoPoint) return location;
  return null;
}

Future<GeoPoint?> _ensureUserGeoPoint(Ref ref) async {
  final user = ref.read(firebaseAuthProvider).currentUser;
  if (user == null) return null;

  final firestore = ref.read(firestoreProvider);
  var location = await _readUserGeoPoint(firestore, user.uid);
  if (location != null) return location;

  await ref.read(locationServiceProvider).updateUserLocation();
  location = await _readUserGeoPoint(firestore, user.uid);
  return location;
}

final forYouRawFeedProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  try {
    final functions = FirebaseFunctions.instanceFor(region: 'africa-south1');
    final result = await functions.httpsCallable('getForYouFeed').call();
    final data = result.data as List<dynamic>;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (e) {
    debugPrint('Error fetching raw for you feed: $e');
    return [];
  }
});

final forYouScheduledEventsProvider = Provider<List<ScheduledEvent>>((ref) {
  final rawFeedAsync = ref.watch(forYouRawFeedProvider);

  return rawFeedAsync.when(
    data: (rawList) => _mapRawFeedToScheduledEvents(
      rawList,
      ref,
    ).take(kHomeFeedCarouselLimit).toList(),
    loading: () => [],
    error: (err, stack) => [],
  );
});

final forYouEventsProvider = Provider<List<Event>>((ref) {
  final rawFeedAsync = ref.watch(forYouRawFeedProvider);

  return rawFeedAsync.when(
    data: (rawList) => _mapRawFeedToEvents(rawList, ref),
    loading: () => [],
    error: (err, stack) => [],
  );
});

bool _isEligibleForInYourAreaCarousel(Map<String, dynamic> map) {
  final name = (map['location_name'] as String? ?? '').trim();
  if (name.isEmpty) return false;
  final lower = name.toLowerCase();
  return lower != 'location tbd' && lower != 'tbd';
}

List<Map<String, dynamic>> _mergeInAreaWithForYou(
  List<Map<String, dynamic>> inArea,
  List<Map<String, dynamic>> forYou,
) {
  final seen = <String>{};
  final merged = <Map<String, dynamic>>[];

  for (final map in inArea) {
    if (!_isEligibleForInYourAreaCarousel(map)) continue;
    final id = map['id'] as String? ?? '';
    if (id.isEmpty || seen.contains(id)) continue;
    seen.add(id);
    merged.add(map);
  }

  for (final map in forYou) {
    if (!_isEligibleForInYourAreaCarousel(map)) continue;
    final id = map['id'] as String? ?? '';
    if (id.isEmpty || seen.contains(id)) continue;
    seen.add(id);
    merged.add(map);
  }

  return merged;
}

final eventsInAreaRawFeedProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  try {
    List<Map<String, dynamic>> inArea = [];
    final location = await _ensureUserGeoPoint(ref);
    if (location != null) {
      final functions = FirebaseFunctions.instanceFor(region: 'africa-south1');
      final result = await functions.httpsCallable('getEventsInArea').call({
        'latitude': location.latitude,
        'longitude': location.longitude,
      });
      final data = result.data as List<dynamic>;
      inArea = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else {
      debugPrint('Events in area: no user location, using For You fallback');
    }

    final forYou = await ref.watch(forYouRawFeedProvider.future);
    return _mergeInAreaWithForYou(inArea, forYou);
  } catch (e) {
    debugPrint('Error fetching events in area feed: $e');
    final forYou = ref.read(forYouRawFeedProvider).value ?? [];
    return forYou.where(_isEligibleForInYourAreaCarousel).toList();
  }
});

final eventsInAreaScheduledEventsProvider = Provider<List<ScheduledEvent>>((
  ref,
) {
  final rawFeedAsync = ref.watch(eventsInAreaRawFeedProvider);

  return rawFeedAsync.when(
    data: (rawList) => _mapRawFeedToScheduledEvents(
      rawList,
      ref,
    ).take(kHomeFeedCarouselLimit).toList(),
    loading: () => [],
    error: (err, stack) => [],
  );
});

final eventsInAreaEventsProvider = Provider<List<Event>>((ref) {
  final rawFeedAsync = ref.watch(eventsInAreaRawFeedProvider);

  return rawFeedAsync.when(
    data: (rawList) => _mapRawFeedToEvents(rawList, ref),
    loading: () => [],
    error: (err, stack) => [],
  );
});
