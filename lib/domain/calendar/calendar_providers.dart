import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/event/event_repository.dart';
import '../auth/auth_providers.dart';
import 'calendar_filter.dart';
import 'scheduled_event.dart';

enum CalendarFormat { month, week }

class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void updateDate(DateTime date) => state = date;
}

final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(
  () {
    return SelectedDateNotifier();
  },
);

class CalendarFormatNotifier extends Notifier<CalendarFormat> {
  @override
  CalendarFormat build() => CalendarFormat.month;

  void updateFormat(CalendarFormat format) => state = format;
}

final calendarFormatProvider =
    NotifierProvider<CalendarFormatNotifier, CalendarFormat>(() {
      return CalendarFormatNotifier();
    });

class CalendarFilterNotifier extends Notifier<Set<CalendarFilterCategory>> {
  @override
  Set<CalendarFilterCategory> build() =>
      Set<CalendarFilterCategory>.from(defaultCalendarFilters);

  void setFilters(Set<CalendarFilterCategory> filters) {
    state = Set<CalendarFilterCategory>.from(filters);
  }

  void reset() {
    state = Set<CalendarFilterCategory>.from(defaultCalendarFilters);
  }
}

final calendarFilterProvider =
    NotifierProvider<CalendarFilterNotifier, Set<CalendarFilterCategory>>(
      CalendarFilterNotifier.new,
    );

final scheduleStreamProvider = StreamProvider<List<ScheduledEvent>>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return Stream.value([]);

  final repository = ref.watch(eventRepositoryProvider);
  return repository.getScheduleStream(user.uid).map((list) {
    return list
        .map((data) => ScheduledEvent.fromMap(data, data['id'] as String))
        .toList();
  });
});

final filteredScheduleProvider = Provider<AsyncValue<List<ScheduledEvent>>>((
  ref,
) {
  final scheduleAsync = ref.watch(scheduleStreamProvider);
  final selectedFilters = ref.watch(calendarFilterProvider);
  final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;

  return scheduleAsync.when(
    data: (events) {
      if (userId == null) return const AsyncData([]);
      final filtered = events
          .where((e) => matchesCalendarFilters(e, userId, selectedFilters))
          .toList();
      return AsyncData(filtered);
    },
    loading: () => const AsyncLoading(),
    error: (error, stack) => AsyncError(error, stack),
  );
});

final publicScheduleStreamProvider = StreamProvider.autoDispose
    .family<List<ScheduledEvent>, String>((ref, profileUserId) {
      if (profileUserId.trim().isEmpty) return Stream.value([]);
      final repository = ref.watch(eventRepositoryProvider);
      return repository.getScheduleStream(profileUserId).map((list) {
        return list
            .map((data) => ScheduledEvent.fromMap(data, data['id'] as String))
            .toList();
      });
    });

final upcomingScheduleStreamProvider = StreamProvider<List<ScheduledEvent>>((
  ref,
) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return Stream.value([]);

  final repository = ref.watch(eventRepositoryProvider);
  return repository.getUpcomingScheduleStream(user.uid).map((list) {
    return list
        .map((data) => ScheduledEvent.fromMap(data, data['id'] as String))
        .toList();
  });
});
