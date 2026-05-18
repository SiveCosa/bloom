import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/auth/auth_providers.dart';
import '../../../domain/calendar/calendar_providers.dart';
import '../../widgets/scheduled_event_card.dart';
import 'dart:ui' as ui;

class EventsJoinedScreen extends ConsumerWidget {
  final String? targetUserId;
  final String? targetUsername;

  const EventsJoinedScreen({super.key, this.targetUserId, this.targetUsername});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPublic = targetUserId != null;
    final currentUser = ref.watch(firebaseAuthProvider).currentUser;
    final fetchUserId = isPublic ? targetUserId! : (currentUser?.uid ?? '');

    final scheduleAsync = isPublic 
        ? ref.watch(publicScheduleStreamProvider(fetchUserId))
        : ref.watch(scheduleStreamProvider);

    final titleText = isPublic ? '${targetUsername ?? "User"} joined' : 'Events Joined';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E12),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 80.0, sigmaY: 80.0),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppTheme.coreGradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.topRight,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        titleText,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: scheduleAsync.when(
                    data: (schedule) {
                      // Filter out hosted events to get only joined events
                      final joinedEvents = schedule.where((e) => e.hostId != fetchUserId).toList();
                      
                      if (joinedEvents.isEmpty) {
                        return const Center(
                          child: Text(
                            'No events joined yet.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        );
                      }

                      final now = DateTime.now();
                      final upcoming = joinedEvents.where((e) => e.endTime.isAfter(now)).toList();
                      final past = joinedEvents.where((e) => e.endTime.isBefore(now)).toList();

                      upcoming.sort((a, b) => a.startTime.compareTo(b.startTime));
                      past.sort((a, b) => b.startTime.compareTo(a.startTime));

                      return CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          if (upcoming.isNotEmpty)
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: ScheduledEventCard(
                                      event: upcoming[index],
                                      isHost: false,
                                      onTap: () => context.push('/event/${upcoming[index].id}'),
                                    ),
                                  ),
                                  childCount: upcoming.length,
                                ),
                              ),
                            ),
                          
                          if (past.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                                child: Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        "Past events",
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.4),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                                  ],
                                ),
                              ),
                            ),

                          if (past.isNotEmpty)
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: ScheduledEventCard(
                                      event: past[index],
                                      isHost: false,
                                      onTap: () => context.push('/event/${past[index].id}'),
                                    ),
                                  ),
                                  childCount: past.length,
                                ),
                              ),
                            ),
                            
                          const SliverToBoxAdapter(child: SizedBox(height: 40)),
                        ],
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Colors.white24),
                    ),
                    error: (err, stack) => Center(
                      child: Text(
                        'Error: $err',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
