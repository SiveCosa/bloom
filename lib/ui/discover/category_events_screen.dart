import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/routing/event_navigation.dart';
import '../shared/widgets/gradient_top_bar.dart';
import '../shared/widgets/event_medium_card.dart';
import '../../domain/discover/discover_providers.dart';
import '../../domain/calendar/scheduled_event.dart';
import '../event/widgets/event_card_large.dart';
import '../shared/widgets/bloom_button.dart';

class CategoryEventsScreen extends ConsumerWidget {
  final String category;

  const CategoryEventsScreen({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(categoryEventsProvider(category));

    String displayTitle = category;
    final cleanCat = category.toLowerCase().trim();
    if (cleanCat == 'music') {
      displayTitle = 'After Hours';
    } else if (cleanCat == 'community') {
      displayTitle = 'Meet New People';
    } else if (cleanCat == 'arts') {
      displayTitle = 'Modern Renaissance';
    } else if (cleanCat == 'film') {
      displayTitle = 'Silver Screen';
    } else if (cleanCat == 'fitness') {
      displayTitle = 'Peak Performance';
    } else if (cleanCat == 'food') {
      displayTitle = 'Feast & Flavor';
    } else if (cleanCat == 'weekend-forecast' || cleanCat == 'weekend forecast') {
      displayTitle = 'Weekend Forecast';
    }

    final carouselEvents = eventsForCarousel(events);
    final carouselIds = carouselEvents.map((e) => e.id).toSet();
    final remainingEvents = events.where((e) => !carouselIds.contains(e.id)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E12),
      body: Stack(
        children: [
          // Atmospheric Gradient Background
          const GradientTopBar(
            height: 100,
            showDarkOverlay: false,
          ),
          
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                floating: true,
                pinned: false,
                centerTitle: false,
                title: Text(
                  displayTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => context.pop(),
                ),
              ),

              if (events.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/nav/discover_line.svg',
                            width: 48,
                            height: 48,
                            colorFilter: const ColorFilter.mode(
                              Colors.white24,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No events found',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Check back later or browse other categories!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 32),
                          const DiscoverCreateEventCTA(),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                // Top Spotlight Carousel (if not empty)
                if (carouselEvents.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Text(
                            'Spotlight',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: EventCardLarge.carouselHeight,
                          child: ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            itemCount: carouselEvents.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 8.0),
                            itemBuilder: (context, index) {
                              final event = carouselEvents[index];
                              final card =
                                  ref.watch(discoverFeedCardMapForRouteProvider(category))[event.id];
                              final scheduledEvent = ScheduledEvent(
                                id: event.id,
                                title: event.title,
                                posterUrl: event.visuals.posterUrl,
                                startTime: event.timing.startDate ?? DateTime.now(),
                                endTime: event.timing.effectiveEndDate ?? (event.timing.startDate ?? DateTime.now()).add(const Duration(hours: 3)),
                                hostName: card?.hostUsername ?? '',
                                hostId: event.metadata.hostId,
                                hostImageUrl: card?.hostAvatarUrl,
                                auroraColors: event.visuals.auroraColors,
                                locationName: event.location?.displayName ?? 'Bloom Event',
                                coHostIds: event.coHostIds,
                              );
                              return EventCardLarge(
                                event: scheduledEvent,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                // Remaining events section header
                if (remainingEvents.isNotEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(left: 16.0, top: 12.0, bottom: 12.0),
                      child: Text(
                        'Explore More',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Remaining events vertical list
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final event = remainingEvents[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: EventMediumCard(
                          event: event,
                          onTap: () => pushEventDetail(context, event.id),
                        ),
                      );
                    },
                    childCount: remainingEvents.length,
                  ),
                ),

                const SliverToBoxAdapter(
                  child: DiscoverCreateEventCTA(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class DiscoverCreateEventCTA extends StatelessWidget {
  const DiscoverCreateEventCTA({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Divider(color: Colors.white10, height: 1),
        ),
        const SizedBox(height: 32),
        const Text(
          "Can't find what you're looking for?",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Make it happen then!",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),
        BloomButton(
          text: 'Create event',
          width: null,
          height: 35,
          backgroundColor: Colors.white,
          textColor: Colors.black,
          borderRadius: 50,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          horizontalPadding: 13,
          prefixIcon: const Icon(Icons.add, color: Colors.black, size: 18),
          onPressed: () => context.push('/create-event'),
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}

