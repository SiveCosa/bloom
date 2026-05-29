import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/event_navigation.dart';
import '../../domain/auth/auth_providers.dart';
import '../../domain/calendar/calendar_providers.dart';
import '../../domain/calendar/scheduled_event.dart';
import '../shared/widgets/custom_text_fields.dart';
import '../shared/widgets/gradient_top_bar.dart';
import '../widgets/scheduled_event_card.dart';

class CalendarSearchScreen extends ConsumerStatefulWidget {
  const CalendarSearchScreen({super.key});

  @override
  ConsumerState<CalendarSearchScreen> createState() =>
      _CalendarSearchScreenState();
}

class _CalendarSearchScreenState extends ConsumerState<CalendarSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ScheduledEvent> _filterEvents(List<ScheduledEvent> events) {
    if (_query.isEmpty) return events;

    return events.where((event) {
      final title = event.title.toLowerCase();
      final hostName = event.hostName.toLowerCase();
      return title.contains(_query) || hostName.contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheduleAsync = ref.watch(scheduleStreamProvider);
    final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;

    return Container(
      color: const Color(0xFF0B0E12),
      child: Stack(
        children: [
          const GradientTopBar(height: 100, showDarkOverlay: false),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
              leadingWidth: 48,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => context.pop(),
              ),
              title: const Text(
                'Search events',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: RoundedTextField(
                    controller: _searchController,
                    hintText: 'Find an event...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white54,
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white54,
                              size: 20,
                            ),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                  ),
                ),
                Expanded(
                  child: scheduleAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0086D8),
                      ),
                    ),
                    error: (error, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          error.toString(),
                          style: const TextStyle(color: Colors.white54),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    data: (events) {
                      final results = _filterEvents(events);

                      if (_query.isNotEmpty && results.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  color: Colors.white24,
                                  size: 48,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No events found',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Try adjusting your search query',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (results.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  color: Colors.white24,
                                  size: 48,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No events scheduled',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Search for events in discover or create your own',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final event = results[index];
                          final isHost =
                              currentUserId != null &&
                              (currentUserId == event.hostId ||
                                  event.coHostIds.contains(currentUserId));

                          return ScheduledEventCard(
                            event: event,
                            isHost: isHost,
                            onTap: () => pushEventDetail(context, event.id),
                          );
                        },
                      );
                    },
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
