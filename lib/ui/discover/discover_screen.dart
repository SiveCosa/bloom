import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../domain/discover/discover_providers.dart';
import '../../domain/calendar/scheduled_event.dart';
import '../../domain/event/event.dart';
import '../../domain/navigation/navigation_providers.dart';
import '../shared/widgets/gradient_top_bar.dart';
import '../shared/widgets/event_medium_card.dart';
import '../event/widgets/event_card_large.dart';
import '../shared/widgets/bloom_icon_button.dart';
import '../shared/widgets/bloom_button.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> with TickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _spinController;
  double _dragOffset = 0.0;
  bool _isRefreshing = false;
  bool _showIndicator = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      if (!_isRefreshing) {
        final double offset = _scrollController.offset;
        if (offset < 0) {
          setState(() {
            _dragOffset = -offset;
            _showIndicator = true;
          });
        } else {
          if (_dragOffset != 0.0) {
            setState(() {
              _dragOffset = 0.0;
              _showIndicator = false;
            });
          }
        }
      }
    } else if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.idle) {
      if (!_isRefreshing && _scrollController.offset <= -90.0) {
        _triggerRefresh();
      } else if (!_isRefreshing && _dragOffset > 0.0) {
        setState(() {
          _dragOffset = 0.0;
          _showIndicator = false;
        });
      }
    }
    return false;
  }

  Future<void> _triggerRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _showIndicator = true;
      _dragOffset = 90.0;
    });
    _spinController.repeat();

    try {
      ref.invalidate(discoverActiveEventsStreamProvider);
      ref.invalidate(userLocationProvider);
      await ref.read(discoverActiveEventsStreamProvider.future);
      await ref.read(userLocationProvider.future);
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _showIndicator = false;
        _dragOffset = 0.0;
      });
      _spinController.stop();
    }
  }

  void _handleDiscoverTabTap() {
    if (_isRefreshing) return;

    if (_scrollController.hasClients) {
      if (_scrollController.offset > 0) {
        _scrollController
            .animateTo(
          0.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        )
            .then((_) {
          _triggerRefresh();
        });
      } else {
        _triggerRefresh();
      }
    }
  }

  double _getIndicatorTop(double topPadding, double maskHeight) {
    const double indicatorHeight = 42.0;
    final double hiddenPosition = topPadding + maskHeight - indicatorHeight - 10.0;

    if (_isRefreshing) {
      return topPadding + maskHeight + 16.0;
    }

    final double dragAmount = _dragOffset.clamp(0.0, 120.0);
    return hiddenPosition + dragAmount;
  }

  Widget _buildReloadIndicator(double topPadding, double maskHeight) {
    if (!_showIndicator && !_isRefreshing) {
      return const SizedBox.shrink();
    }

    final double pullProgress = (_dragOffset / 90.0).clamp(0.0, 1.0);

    final double indicatorTop = _getIndicatorTop(topPadding, maskHeight);
    final double opacity = _isRefreshing ? 1.0 : pullProgress;
    final double scale = _isRefreshing ? 1.0 : (0.6 + 0.4 * pullProgress);

    const Color iconColor = Colors.white;

    return AnimatedPositioned(
      duration: _isRefreshing ? const Duration(milliseconds: 200) : Duration.zero,
      curve: Curves.easeOutCubic,
      top: indicatorTop,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF161A22).withValues(alpha: 0.85),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Center(
                    child: _isRefreshing
                        ? RotationTransition(
                            turns: _spinController,
                            child: const Icon(
                              Icons.refresh_rounded,
                              color: iconColor,
                              size: 22,
                            ),
                          )
                        : Transform.rotate(
                            angle: pullProgress * 2 * math.pi,
                            child: const Icon(
                              Icons.refresh_rounded,
                              color: iconColor,
                              size: 22,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeFilter = ref.watch(discoverCategoryFilterProvider);
    final verticalFeedEvents = ref.watch(discoverVerticalFeedProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    ref.listen(discoverTabTapProvider, (previous, next) {
      if (next > 0) {
        _handleDiscoverTabTap();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E12),
      body: Stack(
        children: [
          // 1. Scrollable Content
          NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: CustomScrollView(
              controller: _scrollController,
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
                      // 1. Weekend Forecast
                      _buildRealCarousel(
                        ref: ref,
                        title: 'Weekend Forecast',
                        routeCategory: 'weekend-forecast',
                        eventsProvider: discoverWeekendForecastEventsProvider,
                      ),
                      // 2. Meet New People (Community)
                      _buildRealCarousel(
                        ref: ref,
                        title: 'Meet New People',
                        routeCategory: 'Community',
                        eventsProvider: discoverCommunityEventsProvider,
                      ),
                      // 3. After Hours (Music)
                      _buildRealCarousel(
                        ref: ref,
                        title: 'After Hours',
                        routeCategory: 'Music',
                        eventsProvider: discoverMusicEventsProvider,
                      ),
                      // 4. Silver Screen (Film)
                      _buildRealCarousel(
                        ref: ref,
                        title: 'Silver Screen',
                        routeCategory: 'Film',
                        eventsProvider: discoverFilmEventsProvider,
                      ),
                      // 5. Modern Renaissance (Arts)
                      _buildRealCarousel(
                        ref: ref,
                        title: 'Modern Renaissance',
                        routeCategory: 'Arts',
                        eventsProvider: discoverArtsEventsProvider,
                      ),
                      // 6. Peak Performance (Fitness)
                      _buildRealCarousel(
                        ref: ref,
                        title: 'Peak Performance',
                        routeCategory: 'Fitness',
                        eventsProvider: discoverFitnessEventsProvider,
                      ),
                      // 7. Feast & Flavor (Food)
                      _buildRealCarousel(
                        ref: ref,
                        title: 'Feast & Flavor',
                        routeCategory: 'Food',
                        eventsProvider: discoverFoodEventsProvider,
                      ),
                    ],
                  ),
                ),

                // Title header for the Vertical Feed under "All"
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(left: 16.0, top: 12.0, bottom: 12.0),
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
                // Category selected: Show single carousel at the top if it has events
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildCategoryTopCarousel(ref, activeFilter),
                    ],
                  ),
                ),
              ],

              // Infinite Vertical Feed
              if (verticalFeedEvents.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.explore_outlined,
                            color: Colors.white24,
                            size: 48,
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
                            'Try browsing another category!',
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
                SliverList(
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
                const SliverToBoxAdapter(
                  child: DiscoverCreateEventCTA(),
                ),
              ],
            ],
          ),
        ),

          // Custom Reload Indicator (Emerges from below the app header)
          _buildReloadIndicator(topPadding, 120.0),

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

                        String? iconPath;
                        final lowerCat = category.toLowerCase();
                        if (lowerCat == 'all') {
                          iconPath = 'assets/icons/discover/all_icon.svg';
                        } else if (lowerCat == 'community') {
                          iconPath = 'assets/icons/discover/community_icon.svg';
                        } else if (lowerCat == 'music') {
                          iconPath = 'assets/icons/discover/music_icon.svg';
                        } else if (lowerCat == 'film') {
                          iconPath = 'assets/icons/discover/movie_icon.svg';
                        } else if (lowerCat == 'arts') {
                          iconPath = 'assets/icons/discover/art_icon.svg';
                        } else if (lowerCat == 'fitness') {
                          iconPath = 'assets/icons/discover/fitness_icon.svg';
                        } else if (lowerCat == 'food') {
                          iconPath = 'assets/icons/discover/food_icon.svg';
                        }

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
                              color: Colors.white.withValues(alpha: isSelected ? 0.30 : 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.07),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (iconPath != null) ...[
                                  SvgPicture.asset(
                                    iconPath,
                                    width: lowerCat == 'community' ? 15 : 20,
                                    height: lowerCat == 'community' ? 15 : 20,
                                    colorFilter: const ColorFilter.mode(
                                      Colors.white,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  category,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
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

  Widget _buildRealCarousel({
    required WidgetRef ref,
    required String title,
    required String routeCategory,
    required Provider<List<Event>> eventsProvider,
  }) {
    final events = ref.watch(eventsProvider);
    final popularEvents = getTop10Popular(events);

    if (popularEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        _buildSpotlightCarousel(
          title: title,
          routeCategory: routeCategory,
          events: popularEvents,
          showChevron: true,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCategoryTopCarousel(WidgetRef ref, String activeFilter) {
    String title = activeFilter;
    if (activeFilter.toLowerCase() == 'music') title = 'After Hours';
    if (activeFilter.toLowerCase() == 'community') title = 'Meet New People';
    if (activeFilter.toLowerCase() == 'arts') title = 'Modern Renaissance';
    if (activeFilter.toLowerCase() == 'film') title = 'Silver Screen';
    if (activeFilter.toLowerCase() == 'fitness') title = 'Peak Performance';
    if (activeFilter.toLowerCase() == 'food') title = 'Feast & Flavor';

    final events = ref.watch(categoryEventsProvider(activeFilter));
    final popularEvents = getTop10Popular(events);

    if (popularEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        _buildSpotlightCarousel(
          title: title,
          routeCategory: activeFilter,
          events: popularEvents,
          showChevron: false,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSpotlightCarousel({
    required String title,
    required String routeCategory,
    required List<Event> events,
    bool showChevron = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48.0),
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
                if (showChevron)
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Colors.white54,
                      size: 24,
                    ),
                    onPressed: () {
                      if (routeCategory == 'weekend-forecast') {
                        context.push('/discover/category/$routeCategory');
                      } else {
                        ref.read(discoverCategoryFilterProvider.notifier).setCategory(routeCategory);
                      }
                    },
                  ),
              ],
            ),
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
              final event = events[index];
              final scheduledEvent = ScheduledEvent(
                id: event.id,
                title: event.title,
                posterUrl: event.visuals.posterUrl,
                startTime: event.timing.startDate ?? DateTime.now(),
                endTime: event.timing.effectiveEndDate ?? (event.timing.startDate ?? DateTime.now()).add(const Duration(hours: 3)),
                hostName: '',
                hostId: event.metadata.hostId,
                hostImageUrl: null,
                auroraColors: event.visuals.auroraColors,
                locationName: event.location?.displayName ?? 'Bloom Event',
              );
              return EventCardLarge(
                event: scheduledEvent,
              );
            },
          ),
        ),
      ],
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
          text: 'Host Event',
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

