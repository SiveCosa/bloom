import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../../data/event/event_repository.dart';
import '../auth/auth_providers.dart';
import '../calendar/calendar_providers.dart';
import 'event.dart';
import '../calendar/scheduled_event.dart';
import 'event_visibility.dart';
import 'event_location.dart';

final hostedEventsProvider = StreamProvider<List<Event>>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return Stream.value([]);

  return ref.watch(eventRepositoryProvider).getHostedAndCoHostedEventsStream(user.uid);
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

final publicProfileHostedCountProvider = Provider.family<int, String>((ref, userId) {
  return ref.watch(publicHostedEventsProvider(userId)).value?.length ?? 0;
});

final publicProfileJoinedCountProvider = Provider.family<int, String>((ref, userId) {
  final schedule = ref.watch(publicScheduleStreamProvider(userId)).value ?? [];
  final excludeIds =
      ref.watch(publicHostedEventsProvider(userId)).value?.map((e) => e.id).toSet() ?? {};
  return schedule.where((e) {
    if (excludeIds.contains(e.id)) return false;
    final status = e.rsvpStatus;
    if (status == 'maybe' || status == 'interested') return false;
    return status == null || status == 'going';
  }).length;
});

final eventStreamProvider = StreamProvider.family<Event?, String>((ref, eventId) {
  return ref.watch(eventRepositoryProvider).getEventStream(eventId);
});

final userEventRsvpProvider = StreamProvider.family<String?, String>((ref, eventId) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return Stream.value(null);
  return ref.watch(eventRepositoryProvider).getUserRSVPStream(eventId, user.uid);
});

final eventGuestsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, eventId) {
  return ref.watch(eventRepositoryProvider).getEventGuestsStream(eventId);
});

final publicHostedEventsProvider = StreamProvider.family<List<Event>, String>((ref, userId) {
  return ref.watch(eventRepositoryProvider).getHostedAndCoHostedEventsStream(userId);
});

/// Upcoming joining + hosting events for the public profile being viewed ([profileUserId]).
final publicProfileUpcomingEventsProvider =
    StreamProvider.autoDispose.family<List<ScheduledEvent>, String>((ref, profileUserId) {
  if (profileUserId.trim().isEmpty) return Stream.value([]);

  final profileDoc = ref.watch(userProfileStreamProvider(profileUserId)).value;
  final profileName = profileDoc?['name']?.toString() ??
      profileDoc?['username']?.toString() ??
      '';

  return ref.watch(eventRepositoryProvider).watchProfileUpcomingEvents(
        profileUserId,
        profileDisplayName: profileName,
      );
});

final forYouRawFeedProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
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
  final user = ref.watch(firebaseAuthProvider).currentUser;
  final hostedIds = ref.watch(hostedOrCoHostedEventIdsProvider);

  return rawFeedAsync.when(
    data: (rawList) {
      return rawList
          .where((map) {
            final id = map['id'] as String? ?? '';
            final hostId = map['host_id'] as String? ?? '';
            if (hostedIds.contains(id)) return false;
            if (user != null && hostId == user.uid) return false;
            return true;
          })
          .map((map) {
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
          }).toList();
    },
    loading: () => [],
    error: (err, stack) => [],
  );
});

final forYouEventsProvider = Provider<List<Event>>((ref) {
  final rawFeedAsync = ref.watch(forYouRawFeedProvider);
  final user = ref.watch(firebaseAuthProvider).currentUser;
  final hostedIds = ref.watch(hostedOrCoHostedEventIdsProvider);

  return rawFeedAsync.when(
    data: (rawList) {
      return rawList
          .where((map) {
            final id = map['id'] as String? ?? '';
            final hostId = map['host_id'] as String? ?? '';
            if (hostedIds.contains(id)) return false;
            if (user != null && hostId == user.uid) return false;
            return true;
          })
          .map((map) {
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
              timing: EventTiming(
                startDate: start,
                startTimeTbd: start == null,
              ),
              location: EventLocation(
                displayName: map['location_name'] as String? ?? '',
                formattedAddress: map['location_name'] as String? ?? '',
                latitude: 0.0,
                longitude: 0.0,
                geohash: '',
              ),
              audience: const EventAudience(
                visibility: EventVisibility.public,
              ),
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
          }).toList();
    },
    loading: () => [],
    error: (err, stack) => [],
  );
});
