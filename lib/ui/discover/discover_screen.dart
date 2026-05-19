import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/discover/discover_providers.dart';
import '../../domain/calendar/scheduled_event.dart';
import '../shared/widgets/gradient_top_bar.dart';
import '../shared/widgets/event_medium_card.dart';
import '../event/widgets/event_card_large.dart';
import '../shared/widgets/bloom_icon_button.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  @override
  Widget build(BuildContext context) {
    final activeFilter = ref.watch(discoverCategoryFilterProvider);
    final verticalFeedEvents = ref.watch(discoverVerticalFeedProvider);

    final trendingEvents = ref.watch(discoverSpotlightEventsProvider('Trending Now'));
    final friendsEvents = ref.watch(discoverSpotlightEventsProvider('From your friends'));
    final nearbyEvents = ref.watch(discoverSpotlightEventsProvider('Popular Nearby'));
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E12),
      body: Stack(
        children: [
          // 1. Scrollable Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(height: topPadding + 120),
              ),

              // Spotlight carousels (Only show when "All" is selected)
              if (activeFilter == 'All') ...[
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildSpotlightCarousel(
                        title: 'Trending Now',
                        routeCategory: 'Trending',
                        events: trendingEvents,
                      ),
                      const SizedBox(height: 24),
                      _buildSpotlightCarousel(
                        title: 'From your friends',
                        routeCategory: 'Community',
                        events: friendsEvents,
                      ),
                      const SizedBox(height: 24),
                      _buildSpotlightCarousel(
                        title: 'Popular Nearby',
                        routeCategory: 'Trending', // route to Trending or similar
                        events: nearbyEvents,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Title header for the Vertical Feed under "All"
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(left: 16.0, bottom: 12.0),
                    child: Text(
                      'Explore Events',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Spacing when specific category is chosen
                const SliverToBoxAdapter(
                  child: SizedBox(height: 16),
                ),
              ],

              // Infinite Vertical Feed
              if (verticalFeedEvents.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
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
                            'Try browsing another category!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final event = verticalFeedEvents[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: EventMediumCard(
                            event: event,
                            onTap: () => context.push('/event/${event.id}'),
                          ),
                        );
                      },
                      childCount: verticalFeedEvents.length,
                    ),
                  ),
                ),
            ],
          ),

          // 2. Solid Masking Layer (Sharp cut-off 5dp below pills)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPadding + 120,
            child: Container(color: const Color(0xFF0B0E12)),
          ),

          // 3. Atmospheric Gradient Background (Stays at original height)
          const GradientTopBar(height: 100, showDarkOverlay: false),

          // 4. Fixed Header (Title + Categories)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Bar title & actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: SizedBox(
                      height: 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Discovery',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                            ),
                          ),
                          Row(
                            children: [
                              BloomIconButton(
                                icon: Icons.search,
                                onTap: () {
                                  // Empty/Muted handler
                                },
                              ),
                              const SizedBox(width: 12),
                              BloomIconButton(
                                icon: Icons.tune,
                                onTap: () {
                                  // Empty/Muted handler
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Category Chips Row
                  SizedBox(
                    height: 35,
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      itemCount: discoverCategories.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8.0),
                      itemBuilder: (context, index) {
                        final category = discoverCategories[index];
                        final isSelected = activeFilter == category;
                        return GestureDetector(
                          onTap: () {
                            ref.read(discoverCategoryFilterProvider.notifier).setCategory(category);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(horizontal: 14.0),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: isSelected ? 0.12 : 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.07),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotlightCarousel({
    required String title,
    required String routeCategory,
    required List<ScheduledEvent> events,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.chevron_right,
                  color: Colors.white54,
                  size: 24,
                ),
                onPressed: () => context.push('/discover/category/$routeCategory'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 394,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: events.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8.0),
            itemBuilder: (context, index) {
              return EventCardLarge(
                event: events[index],
              );
            },
          ),
        ),
      ],
    );
  }
}
