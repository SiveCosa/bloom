import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shared/widgets/gradient_top_bar.dart';
import '../shared/widgets/event_medium_card.dart';
import '../../domain/event/event_providers.dart';

class ForYouScreen extends ConsumerWidget {
  const ForYouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawFeedAsync = ref.watch(forYouRawFeedProvider);

    return Container(
      color: const Color(0xFF0B0E12),
      child: Stack(
        children: [
          // Atmospheric Gradient Background
          const GradientTopBar(
            height: 100,
            showDarkOverlay: false,
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text(
                'For You',
                style: TextStyle(
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
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome_outlined,
                            color: Colors.white24,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No recommendations yet.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add more interests to your profile and check back later!',
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

                // Since we have data, read the mapped events
                final events = ref.read(forYouEventsProvider);

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 10, bottom: 40),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return EventMediumCard(
                      event: event,
                      onTap: () => context.push('/event/${event.id}'),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFF04A9F), // Bloom Core Pink Accent
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
                        'Failed to load your feed',
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
