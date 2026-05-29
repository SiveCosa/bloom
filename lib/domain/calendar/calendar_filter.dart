import 'scheduled_event.dart';

enum CalendarFilterCategory {
  myEvents,
  attending,
  deciding,
  notGoing,
  waitingOnHost,
}

extension CalendarFilterCategoryLabels on CalendarFilterCategory {
  String get title {
    switch (this) {
      case CalendarFilterCategory.myEvents:
        return 'My events';
      case CalendarFilterCategory.attending:
        return 'Attending';
      case CalendarFilterCategory.deciding:
        return 'Deciding';
      case CalendarFilterCategory.notGoing:
        return 'Not Going';
      case CalendarFilterCategory.waitingOnHost:
        return 'Waiting on host';
    }
  }

  String get subtitle {
    switch (this) {
      case CalendarFilterCategory.myEvents:
        return 'Hosting | Cohosting | Hosted';
      case CalendarFilterCategory.attending:
        return 'Going | On the list';
      case CalendarFilterCategory.deciding:
        return 'Invite | Maybe | Interested';
      case CalendarFilterCategory.notGoing:
        return 'Declined | Not Approved';
      case CalendarFilterCategory.waitingOnHost:
        return 'Pending | Waitlisted';
    }
  }
}

const defaultCalendarFilters = {
  CalendarFilterCategory.myEvents,
  CalendarFilterCategory.attending,
  CalendarFilterCategory.deciding,
};

bool isHostingOrCohost(ScheduledEvent event, String userId) =>
    event.hostId == userId || event.coHostIds.contains(userId);

String? _normalizedStatus(ScheduledEvent event) =>
    event.rsvpStatus?.toLowerCase().trim();

bool matchesCalendarFilterCategory(
  ScheduledEvent event,
  String userId,
  CalendarFilterCategory category,
) {
  final isHostRole = isHostingOrCohost(event, userId);
  final status = _normalizedStatus(event);

  switch (category) {
    case CalendarFilterCategory.myEvents:
      return isHostRole;
    case CalendarFilterCategory.attending:
      if (isHostRole) return false;
      return status == 'going' || status == 'approved';
    case CalendarFilterCategory.deciding:
      if (isHostRole) return false;
      return status == 'invited' || status == 'maybe' || status == 'interested';
    case CalendarFilterCategory.notGoing:
      if (isHostRole) return false;
      return status == 'declined' ||
          status == 'not_going' ||
          status == 'not_approved';
    case CalendarFilterCategory.waitingOnHost:
      if (isHostRole) return false;
      return status == 'requested' ||
          status == 'pending' ||
          status == 'waitlisted';
  }
}

bool matchesCalendarFilters(
  ScheduledEvent event,
  String userId,
  Set<CalendarFilterCategory> selectedFilters,
) {
  if (selectedFilters.isEmpty) return false;
  return selectedFilters.any(
    (category) => matchesCalendarFilterCategory(event, userId, category),
  );
}
