import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/event_navigation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/event/event_providers.dart';
import '../../shared/widgets/past_events_divider.dart';
import '../../shared/widgets/event_medium_card.dart';
import 'dart:ui' as ui;

class EventsHostedScreen extends ConsumerWidget {
  final String? targetUserId;
  final String? targetUsername;

  const EventsHostedScreen({super.key, this.targetUserId, this.targetUsername});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPublic = targetUserId != null;
    final eventsAsync = isPublic 
        ? ref.watch(publicHostedEventsProvider(targetUserId!)) 
        : ref.watch(hostedEventsProvider);
    
    final titleText = isPublic ? '${targetUsername ?? "User"} hosted' : 'Events Hosted';

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
                  child: eventsAsync.when(
                    data: (events) {
                      if (events.isEmpty) {
                        return const Center(
                          child: Text(
                            'No events hosted yet.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        );
                      }

                      final now = DateTime.now();
                      // Group events: Upcoming (Future or Ongoing) vs Past
                      final upcoming = events.where((e) => !e.timing.isPast).toList();
                      final past = events.where((e) => e.timing.isPast).toList();

                      // Sort: Upcoming (closest first), Past (most recent first)
                      upcoming.sort((a, b) => (a.timing.startDate ?? now).compareTo(b.timing.startDate ?? now));
                      past.sort((a, b) => (b.timing.startDate ?? now).compareTo(a.timing.startDate ?? now));

                      return CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          // Upcoming Section
                          if (upcoming.isNotEmpty)
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => EventMediumCard(
                                  event: upcoming[index],
                                  onTap: () => pushEventDetail(context, upcoming[index].id),
                                ),
                                childCount: upcoming.length,
                              ),
                            ),

                          // Past Events Section Divider
                          if (past.isNotEmpty)
                            const SliverToBoxAdapter(child: PastEventsDivider()),

                          // Past Events List
                          if (past.isNotEmpty)
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => EventMediumCard(
                                  event: past[index],
                                  onTap: () => pushEventDetail(context, past[index].id),
                                ),
                                childCount: past.length,
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
