import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shared/widgets/gradient_top_bar.dart';
import '../shared/widgets/event_medium_card.dart';
import '../../domain/discover/discover_providers.dart';

class CategoryEventsScreen extends ConsumerWidget {
  final String category;

  const CategoryEventsScreen({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(categoryEventsProvider(category));

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
              title: Text(
                category,
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
            body: events.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.explore_outlined,
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
                            'Check back later or browse other categories!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
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
                  ),
          ),
        ],
      ),
    );
  }
}
