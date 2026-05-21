import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/core/routing/event_navigation.dart';
import '../../domain/calendar/calendar_providers.dart';
import '../../domain/auth/auth_providers.dart';
import '../shared/widgets/bloom_loading_indicator.dart';
import '../widgets/scheduled_event_card.dart';

class UpcomingEventsSection extends ConsumerWidget {
  const UpcomingEventsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(scheduleStreamProvider);
    final currentUser = ref.watch(firebaseAuthProvider).currentUser;

    return scheduleAsync.when(
      data: (events) {
        if (events.isEmpty) return const SizedBox.shrink();

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final nextWeek = today.add(const Duration(days: 7));

        // Filter: Today
        final todayEvents = events.where((e) {
          if (e.startTime == null) return false;
          final eventDate = DateTime(e.startTime!.year, e.startTime!.month, e.startTime!.day);
          return eventDate.isAtSameMomentAs(today);
        }).toList();

        // Filter: This Week (Next 7 days excluding today)
        final thisWeekEvents = events.where((e) {
          if (e.startTime == null) return false;
          final eventDate = DateTime(e.startTime!.year, e.startTime!.month, e.startTime!.day);
          return eventDate.isAfter(today) && eventDate.isBefore(nextWeek.add(const Duration(days: 1)));
        }).toList();

        if (todayEvents.isEmpty && thisWeekEvents.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (todayEvents.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Today',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'This Week',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
