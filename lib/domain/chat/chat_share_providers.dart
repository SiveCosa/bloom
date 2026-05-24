import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/event/event_repository.dart';
import '../auth/auth_providers.dart';
import '../calendar/calendar_providers.dart';
import '../event/event.dart';
import '../event/event_providers.dart';
import '../event/event_visibility.dart';

final chatShareableEventsProvider = FutureProvider<List<Event>>((ref) async {
  final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (uid == null) return [];

  final hosted = ref.watch(hostedEventsProvider).value ?? [];
  final schedule = ref.watch(scheduleStreamProvider).value ?? [];
  final repo = ref.read(eventRepositoryProvider);

  final byId = <String, Event>{};

  for (final event in hosted) {
    if (event.audience.visibility != EventVisibility.private) {
      byId[event.id] = event;
    }
  }

  for (final entry in schedule) {
    final status = entry.rsvpStatus;
    if (status != null && status != 'going') continue;
    if (byId.containsKey(entry.id)) continue;

    final event = await repo.getEvent(entry.id);
    if (event != null && event.audience.visibility != EventVisibility.private) {
      byId[event.id] = event;
    }
  }

  final list = byId.values.toList();
  list.sort((a, b) {
    final aStart = a.timing.startDate;
    final bStart = b.timing.startDate;
    if (aStart == null && bStart == null) return 0;
    if (aStart == null) return 1;
    if (bStart == null) return -1;
    return aStart.compareTo(bStart);
  });
  return list;
});
