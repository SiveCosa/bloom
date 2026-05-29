import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:ui' as ui;
import 'package:bloom/domain/event/event.dart';
import 'package:bloom/domain/calendar/scheduled_event.dart';
import 'package:bloom/domain/event/event_providers.dart';
import 'package:bloom/ui/widgets/scheduled_event_card.dart';

class InterestedEventsScreen extends ConsumerWidget {
  const InterestedEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Interested Events',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ref
                      .watch(interestedEventsProvider)
                      .when(
                        data: (events) {
                          final now = DateTime.now();
                          final todayStart = DateTime(
                            now.year,
                            now.month,
                            now.day,
                          );
                          final todayEnd = todayStart.add(
                            const Duration(days: 1),
                          );
                          final next7DaysEnd = todayStart.add(
                            const Duration(days: 7),
                          );
                          final next30DaysEnd = todayStart.add(
                            const Duration(days: 30),
                          );

                          final validEvents = events.where((e) {
                            if (e.timing.isPast) return false;
                            final deadline = e.audience.rsvpDeadline;
                            if (deadline != null && deadline.isBefore(now)) {
                              return false;
                            }
                            return true;
                          }).toList();

                          validEvents.sort((a, b) {
                            final aStart =
                                a.timing.startDate ??
                                DateTime.fromMillisecondsSinceEpoch(0);
                            final bStart =
                                b.timing.startDate ??
                                DateTime.fromMillisecondsSinceEpoch(0);
                            return aStart.compareTo(bStart);
                          });

                          final todayEvents = <Event>[];
                          final next7DaysEvents = <Event>[];
                          final next30DaysEvents = <Event>[];
                          final upcomingEvents = <Event>[];

                          for (final event in validEvents) {
                            final start = event.timing.startDate;
                            if (start == null) {
                              upcomingEvents.add(event);
                              continue;
                            }
                            if (start.isBefore(todayEnd) &&
                                start.isAfter(
                                  todayStart.subtract(
                                    const Duration(milliseconds: 1),
                                  ),
                                )) {
                              todayEvents.add(event);
                            } else if (start.isBefore(next7DaysEnd)) {
                              next7DaysEvents.add(event);
                            } else if (start.isBefore(next30DaysEnd)) {
                              next30DaysEvents.add(event);
                            } else {
                              upcomingEvents.add(event);
                            }
                          }

                          if (validEvents.isEmpty) {
                            return const Center(
                              child: Text(
                                'No interested events yet.',
                                style: TextStyle(color: Colors.white54),
                              ),
                            );
                          }

                          return ListView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            children: [
                              if (todayEvents.isNotEmpty) ...[
                                _buildSectionTitle('Today'),
                                ...todayEvents.map(
                                  (e) => _buildEventCard(context, e),
                                ),
                                const SizedBox(height: 24),
                              ],
                              if (next7DaysEvents.isNotEmpty) ...[
                                _buildSectionTitle('Next 7 Days'),
                                ...next7DaysEvents.map(
                                  (e) => _buildEventCard(context, e),
                                ),
                                const SizedBox(height: 24),
                              ],
                              if (next30DaysEvents.isNotEmpty) ...[
                                _buildSectionTitle('Next 30 Days'),
                                ...next30DaysEvents.map(
                                  (e) => _buildEventCard(context, e),
                                ),
                                const SizedBox(height: 24),
                              ],
                              if (upcomingEvents.isNotEmpty) ...[
                                _buildSectionTitle('Upcoming'),
                                ...upcomingEvents.map(
                                  (e) => _buildEventCard(context, e),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ],
                          );
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFAD83FE),
                          ),
                        ),
                        error: (err, stack) => Center(
                          child: Text(
                            'Failed to load events',
                            style: TextStyle(color: Colors.red[300]),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, Event event) {
    final end =
        event.timing.effectiveEndDate ??
        event.timing.startDate ??
        DateTime.now();

    final scheduledEvent = ScheduledEvent(
      id: event.id,
      title: event.title,
      posterUrl: event.visuals.posterUrl,
      startTime: event.timing.startDate,
      endTime: end,
      hostName: '',
      hostId: event.metadata.hostId,
      auroraColors: event.visuals.auroraColors,
      locationName: event.location?.displayName ?? '',
      coHostIds: event.coHostIds,
    );

    return ScheduledEventCard(
      event: scheduledEvent,
      isHost: false,
      onTap: () => context.push('/event/${event.id}'),
    );
  }
}
