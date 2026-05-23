import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bloom/core/routing/event_navigation.dart';
import 'package:bloom/domain/event/event.dart';
import 'package:bloom/ui/shared/widgets/event_medium_card.dart';
import 'package:bloom/ui/shared/widgets/gradient_top_bar.dart';

class HomeFeedEmptyState {
  final IconData icon;
  final String title;
  final String subtitle;

  const HomeFeedEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class HomeEventFeedScreen extends ConsumerWidget {
  final String title;
  final FutureProvider<List<Map<String, dynamic>>> rawFeedProvider;
  final Provider<List<Event>> eventsProvider;
  final HomeFeedEmptyState emptyState;
  final String loadErrorTitle;

  const HomeEventFeedScreen({
    super.key,
    required this.title,
    required this.rawFeedProvider,
    required this.eventsProvider,
    required this.emptyState,
    required this.loadErrorTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawFeedAsync = ref.watch(rawFeedProvider);

    return Container(
      color: const Color(0xFF0B0E12),
      child: Stack(
        children: [
          const GradientTopBar(
            height: 100,
            showDarkOverlay: false,
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              leadingWidth: 48,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => context.pop(),
              ),
            ),
            body: rawFeedAsync.when(
              data: (rawList) {
                if (rawList.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            emptyState.icon,
                            color: Colors.white24,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            emptyState.title,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            emptyState.subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final events = ref.watch(eventsProvider);

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 10, bottom: 40),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return EventMediumCard(
                      event: event,
                      onTap: () => pushEventDetail(context, event.id),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFF04A9F),
                ),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 40,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loadErrorTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        err.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}