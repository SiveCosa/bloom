import '../calendar/scheduled_event.dart';

enum HomeScheduleFilter { upcoming, hosting, invites, attending }

bool isInHomeWeekWindow(ScheduledEvent event, DateTime now) {
  final start = event.startTime;
  if (start == null) return false;

  final today = DateTime(now.year, now.month, now.day);
  final nextWeek = today.add(const Duration(days: 7));
  final eventDate = DateTime(start.year, start.month, start.day);

  return eventDate.isAtSameMomentAs(today) ||
      (eventDate.isAfter(today) &&
          eventDate.isBefore(nextWeek.add(const Duration(days: 1))));
}

bool isStillUpcoming(ScheduledEvent event) => !event.isPast;

bool isHosting(ScheduledEvent event, String uid) =>
    event.hostId == uid || event.coHostIds.contains(uid);

bool matchesHomeFilter(
  ScheduledEvent event,
  String uid,
  HomeScheduleFilter filter,
) {
  switch (filter) {
    case HomeScheduleFilter.upcoming:
      return true;
    case HomeScheduleFilter.hosting:
      return isHosting(event, uid);
    case HomeScheduleFilter.invites:
      if (isHosting(event, uid)) return false;
      final status = event.rsvpStatus;
      return status == 'maybe' || status == 'interested';
    case HomeScheduleFilter.attending:
      if (isHosting(event, uid)) return false;
      return event.rsvpStatus == 'going';
  }
}