import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/event/event_repository.dart';
import '../auth/auth_providers.dart';
import '../calendar/calendar_providers.dart';
import '../event/event.dart';
import '../event/event_providers.dart';
import '../event/event_visibility.dart';

class SelectedEventForChatNotifier extends Notifier<Event?> {
  @override
  Event? build() => null;

  void select(Event event) => state = event;

  void clear() => state = null;
}

/// Event staged for sharing in the active chat (cleared after send or dismiss).
final selectedEventForChatProvider =
    NotifierProvider<SelectedEventForChatNotifier, Event?>(() {
      return SelectedEventForChatNotifier();
    });

bool canShareEventInChat(Event event, String uid) {
  if (event.audience.visibility != EventVisibility.private) return true;
  return event.metadata.hostId == uid || event.coHostIds.contains(uid);
}

bool _isAttendingRsvp(String? status) {
  if (status == null) return true;
  return status == 'going' || status == 'approved';
}

final chatShareableEventsProvider = FutureProvider<List<Event>>((ref) async {
  final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (uid == null) return [];

  final hosted = ref.watch(hostedEventsProvider).value ?? [];
  final schedule = ref.watch(scheduleStreamProvider).value ?? [];
  final repo = ref.read(eventRepositoryProvider);

  final byId = <String, Event>{};

  for (final event in hosted) {
    if (canShareEventInChat(event, uid)) {
      byId[event.id] = event;
    }
  }

  for (final entry in schedule) {
    if (!_isAttendingRsvp(entry.rsvpStatus)) continue;
    if (byId.containsKey(entry.id)) continue;

    final event = await repo.getEvent(entry.id);
    if (event != null && canShareEventInChat(event, uid)) {
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
