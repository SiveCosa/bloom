import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/core/routing/event_navigation.dart';
import '../../domain/auth/auth_providers.dart';
import '../../domain/calendar/calendar_providers.dart';
import '../../domain/home/home_schedule_filter.dart';
import '../../domain/home/home_schedule_providers.dart';
import '../shared/widgets/bloom_loading_indicator.dart';
import '../widgets/scheduled_event_card.dart';

class UpcomingEventsSection extends ConsumerWidget {
  const UpcomingEventsSection({super.key});

  String _emptyMessage(HomeScheduleFilter filter) {
    switch (filter) {
      case HomeScheduleFilter.upcoming:
        return 'No upcoming events this week.';
      case HomeScheduleFilter.hosting:
        return 'No hosting events this week.';
      case HomeScheduleFilter.invites:
        return 'No invites this week.';
      case HomeScheduleFilter.attending:
        return 'No events you\'re attending this week.';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(scheduleStreamProvider);
    final currentUser = ref.watch(firebaseAuthProvider).currentUser;
    final activeFilter = ref.watch(homeScheduleFilterProvider);
    final filteredEvents = ref.watch(homeFilteredWeekScheduleProvider);

    return scheduleAsync.when(
      skipLoadingOnRefresh: true,
      data: (_) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final nextWeek = today.add(const Duration(days: 7));

        final todayEvents = filteredEvents.where((e) {
          if (e.startTime == null) return false;
          final eventDate = DateTime(
            e.startTime!.year,
            e.startTime!.month,
            e.startTime!.day,
          );
          return eventDate.isAtSameMomentAs(today);
        }).toList();

        final thisWeekEvents = filteredEvents.where((e) {
          if (e.startTime == null) return false;
          final eventDate = DateTime(
            e.startTime!.year,
            e.startTime!.month,
            e.startTime!.day,
          );
          return eventDate.isAfter(today) &&
              eventDate.isBefore(nextWeek.add(const Duration(days: 1)));
        }).toList();

        if (todayEvents.isEmpty && thisWeekEvents.isEmpty) {
          if (activeFilter == HomeScheduleFilter.upcoming) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text(
              _emptyMessage(activeFilter),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (todayEvents.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.0),
                  child: Text(
                    'Today',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: todayEvents.length,
                  itemBuilder: (context, index) {
                    final event = todayEvents[index];
                    return ScheduledEventCard(
                      event: event,
                      isHost: event.hostId == currentUser?.uid,
                      onTap: () => pushEventDetail(context, event.id),
                    );
                  },
                ),
              ],
              if (thisWeekEvents.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'This Week',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: thisWeekEvents.length,
                  itemBuilder: (context, index) {
                    final event = thisWeekEvents[index];
                    return ScheduledEventCard(
                      event: event,
                      isHost: event.hostId == currentUser?.uid,
                      onTap: () => pushEventDetail(context, event.id),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: BloomLoadingIndicator(size: 40)),
      ),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}
