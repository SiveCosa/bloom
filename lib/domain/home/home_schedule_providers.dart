import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_providers.dart';
import '../calendar/calendar_providers.dart';
import '../calendar/scheduled_event.dart';
import 'home_schedule_filter.dart';

class HomeScheduleFilterNotifier extends Notifier<HomeScheduleFilter> {
  @override
  HomeScheduleFilter build() => HomeScheduleFilter.upcoming;

  void setFilter(HomeScheduleFilter filter) => state = filter;
}

final homeScheduleFilterProvider =
    NotifierProvider<HomeScheduleFilterNotifier, HomeScheduleFilter>(
      HomeScheduleFilterNotifier.new,
    );

final homeWeekScheduleProvider = Provider<List<ScheduledEvent>>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return const [];

  final events = ref.watch(scheduleStreamProvider).value ?? [];
  final now = DateTime.now();

  return events
      .where((e) => isInHomeWeekWindow(e, now) && isStillUpcoming(e))
      .toList();
});

final homeFilterCountsProvider = Provider<Map<HomeScheduleFilter, int>>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) {
    return {for (final f in HomeScheduleFilter.values) f: 0};
  }

  final weekEvents = ref.watch(homeWeekScheduleProvider);
  final uid = user.uid;

  return {
    for (final filter in HomeScheduleFilter.values)
      filter: weekEvents.where((e) => matchesHomeFilter(e, uid, filter)).length,
  };
});

final homeFilteredWeekScheduleProvider = Provider<List<ScheduledEvent>>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return const [];

  final filter = ref.watch(homeScheduleFilterProvider);
  final weekEvents = ref.watch(homeWeekScheduleProvider);

  return weekEvents
      .where((e) => matchesHomeFilter(e, user.uid, filter))
      .toList();
});
