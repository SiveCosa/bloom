import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/routing/event_navigation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../domain/discover/discover_providers.dart';
import '../../domain/discover/discover_filter.dart';
import '../../domain/calendar/scheduled_event.dart';
import '../../domain/event/event.dart';
import '../../domain/navigation/navigation_providers.dart';
import '../shared/widgets/gradient_top_bar.dart';
import '../shared/widgets/event_medium_card.dart';
import '../event/widgets/event_card_large.dart';
import '../shared/widgets/bloom_icon_button.dart';
import '../shared/widgets/bloom_button.dart';
import '../shared/widgets/bloom_loading_indicator.dart';
import './discover_search_screen.dart';
import './advanced_filter_sheet.dart';

String _discoverErrorMessage(Object? error) {
  final text = error?.toString() ?? '';
  if (text.contains('firebase_functions/internal')) {
    return 'The server had trouble loading events. Pull to refresh or try again.';
  }
  if (text.contains('unauthenticated')) {
    return 'Sign in again to load events.';
  }
  return 'Check your connection and try again.';
}

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with TickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _spinController;
  final ValueNotifier<double> _dragOffset = ValueNotifier(0.0);
  final ValueNotifier<bool> _isRefreshing = ValueNotifier(false);
  final ValueNotifier<bool> _showIndicator = ValueNotifier(false);

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
    _dragOffset.dispose();
    _isRefreshing.dispose();
    _showIndicator.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (notification is ScrollUpdateNotification) {
        if (!_isRefreshing.value) {
          final double offset = _scrollController.offset;
          if (offset < 0) {
            _dragOffset.value = -offset;
            _showIndicator.value = true;
          } else {
            if (_dragOffset.value != 0.0) {
              _dragOffset.value = 0.0;
              _showIndicator.value = false;
            }
          }
        }
      } else if (notification is UserScrollNotification &&
          notification.direction == ScrollDirection.idle) {
        if (!_isRefreshing.value && _scrollController.offset <= -90.0) {
          _triggerRefresh();
        } else if (!_isRefreshing.value && _dragOffset.value > 0.0) {
          _dragOffset.value = 0.0;
          _showIndicator.value = false;
        }
      }
    });
    return false;
  }

  Future<void> _triggerRefresh() async {
    if (_isRefreshing.value) return;

    _isRefreshing.value = true;
    _showIndicator.value = true;
    _dragOffset.value = 90.0;
    _spinController.repeat();

    try {
      ref.invalidate(userLocationProvider);
      await ref.read(userLocationProvider.future);
      await ref.read(discoverFeedCacheProvider.notifier).refresh();
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      _isRefreshing.value = false;
      _showIndicator.value = false;
      _dragOffset.value = 0.0;
      _spinController.stop();
    }
  }

  void _handleDiscoverTabTap() {
    if (_isRefreshing.value) return;

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

  double _getIndicatorTop(
    double topPadding,
    double maskHeight,
    double dragOffset,
    bool isRefreshing,
  ) {
    const double indicatorHeight = 42.0;
    final double hiddenPosition =
        topPadding + maskHeight - indicatorHeight - 10.0;

    if (isRefreshing) {
      return topPadding + maskHeight + 16.0;
    }

    final double dragAmount = dragOffset.clamp(0.0, 120.0);
    return hiddenPosition + dragAmount;
  }

  Widget _buildReloadIndicator(double topPadding, double maskHeight) {
    return AnimatedBuilder(
      animation: Listenable.merge([_dragOffset, _isRefreshing, _showIndicator]),
      builder: (context, _) {
        final dragOffset = _dragOffset.value;
        final isRefreshing = _isRefreshing.value;
        final showIndicator = _showIndicator.value;

        if (!showIndicator && !isRefreshing) {
          return const SizedBox.shrink();
        }

        final double pullProgress = (dragOffset / 90.0).clamp(0.0, 1.0);

        final double indicatorTop = _getIndicatorTop(
          topPadding,
          maskHeight,
          dragOffset,
          isRefreshing,
        );
        final double opacity = isRefreshing ? 1.0 : pullProgress;
        final double scale = isRefreshing ? 1.0 : (0.6 + 0.4 * pullProgress);

        const Color iconColor = Colors.white;

        return AnimatedPositioned(
          duration: isRefreshing
              ? const Duration(milliseconds: 200)
              : Duration.zero,
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
                        child: isRefreshing
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeFilter = ref.watch(discoverCategoryFilterProvider);
    final cacheAsync = ref.watch(discoverFeedCacheProvider);
    final verticalFeedEvents = ref.watch(discoverVerticalFeedProvider);
    final topPadding = MediaQuery.of(context).padding.top;
    final isDiscoverTab = ref.watch(mainShellIndexProvider) == 1;

    ref.listen(discoverTabTapProvider, (previous, next) {
      if (next > 0) {
        _handleDiscoverTabTap();
      }
    });

    ref.listen(mainShellIndexProvider, (previous, next) {
      if (next == 1) {
        ref.read(discoverFeedCacheProvider.notifier).refreshIfNeeded();
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
                SliverToBoxAdapter(child: SizedBox(height: topPadding + 120)),

                // Spotlight carousels (Only show when "All" is selected)
                if (activeFilter == 'All') ...[
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        ...[
                          (
                            'Weekend Forecast',
                            'weekend-forecast',
                            discoverWeekendForecastEventsProvider,
                          ),
                          (
                            'Meet New People',
                            'Community',
                            discoverCommunityEventsProvider,
                          ),
                          ('After Hours', 'Music', discoverMusicEventsProvider),
                          ('Silver Screen', 'Film', discoverFilmEventsProvider),
                          (
                            'Modern Renaissance',
                            'Arts',
                            discoverArtsEventsProvider,
                          ),
                          (
                            'Peak Performance',
                            'Fitness',
                            discoverFitnessEventsProvider,
                          ),
                          (
                            'Feast & Flavor',
                            'Food',
                            discoverFoodEventsProvider,
                          ),
                          (
                            'Feed your curiosity',
                            'Education',
                            discoverEducationEventsProvider,
                          ),
                        ].map(
                          (c) => _buildRealCarousel(
                            ref: ref,
                            title: c.$1,
                            routeCategory: c.$2,
                            eventsProvider: c.$3,
                          ),
                        ),
                      ],
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

                // Vertical feed (loading / error / list / empty)
                if (cacheAsync.isLoading && isDiscoverTab)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: BloomLoadingIndicator(size: 40)),
                  )
                else if (cacheAsync.hasError && isDiscoverTab)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.cloud_off_outlined,
                              color: Colors.white38,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Could not load events',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _discoverErrorMessage(cacheAsync.error),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 24),
                            BloomButton(
                              text: 'Try again',
                              onPressed: () => ref
                                  .read(discoverFeedCacheProvider.notifier)
                                  .refresh(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (verticalFeedEvents.isEmpty)
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
                              'Try browsing another category or pull to refresh.',
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
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final event = verticalFeedEvents[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: EventMediumCard(
                          event: event,
                          onTap: () => pushEventDetail(context, event.id),
                        ),
                      );
                    }, childCount: verticalFeedEvents.length),
                  ),
                  const SliverToBoxAdapter(child: DiscoverCreateEventCTA()),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
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
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      fullscreenDialog: true,
                                      builder: (context) =>
                                          const DiscoverSearchScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              BloomIconButton(
                                icon: Icons.tune,
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) =>
                                        const AdvancedFilterSheet(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Builder(
                    builder: (context) {
                      final filterState = ref.watch(discoverFilterProvider);
                      final List<String> displayCategories = List.from(
                        discoverCategories,
                      );
                      if (filterState.hasFilters) {
                        displayCategories.insert(0, 'Filter');
                      }

                      return SizedBox(
                        height: 35,
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          itemCount: displayCategories.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8.0),
                          itemBuilder: (context, index) {
                            final category = displayCategories[index];
                            final isSelected = activeFilter == category;

                            final lowerCat = category.toLowerCase();
                            final iconPath = const {
                              'all': 'assets/icons/discover/all_icon.svg',
                              'community':
                                  'assets/icons/discover/community_icon.svg',
                              'music': 'assets/icons/discover/music_icon.svg',
                              'film': 'assets/icons/discover/movie_icon.svg',
                              'arts': 'assets/icons/discover/art_icon.svg',
                              'fitness':
                                  'assets/icons/discover/fitness_icon.svg',
                              'food': 'assets/icons/discover/food_icon.svg',
                              'education':
                                  'assets/icons/discover/education_icon.svg',
                            }[lowerCat];

                            String displayText = category;
                            if (category == 'Filter') {
                              displayText = 'Filter ';
                            }

                            return GestureDetector(
                              onTap: () {
                                if (category == 'Filter' &&
                                    activeFilter == 'Filter') {
                                  // Open sheet again if already active and clicked
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) =>
                                        const AdvancedFilterSheet(),
                                  );
                                } else {
                                  ref
                                      .read(
                                        discoverCategoryFilterProvider.notifier,
                                      )
                                      .setCategory(category);
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14.0,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(
                                    alpha: isSelected ? 0.30 : 0.08,
                                  ),
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
                                        width: lowerCat == 'community'
                                            ? 15
                                            : 20,
                                        height: lowerCat == 'community'
                                            ? 15
                                            : 20,
                                        colorFilter: const ColorFilter.mode(
                                          Colors.white,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    if (category == 'Filter') ...[
                                      const Icon(
                                        Icons.tune,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      displayText,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
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
    final carouselEvents = eventsForCarousel(events);

    if (carouselEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        _buildSpotlightCarousel(
          ref: ref,
          title: title,
          routeCategory: routeCategory,
          events: carouselEvents,
          showChevron: routeCategory != 'weekend-forecast',
        ),
        const SizedBox(height: 1),
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
    if (activeFilter.toLowerCase() == 'education') {
      title = 'Feed your curiosity';
    }

    final carouselEvents = ref.watch(
      discoverCategoryCarouselProvider(activeFilter),
    );
    final displayEvents = eventsForCarousel(carouselEvents);

    if (displayEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        _buildSpotlightCarousel(
          ref: ref,
          title: title,
          routeCategory: activeFilter,
          events: displayEvents,
          showChevron: false,
        ),
        const SizedBox(height: 1),
      ],
    );
  }

  Widget _buildSpotlightCarousel({
    required WidgetRef ref,
    required String title,
    required String routeCategory,
    required List<Event> events,
    bool showChevron = true,
  }) {
    final cardMap = ref.watch(discoverFeedCardMapProvider);

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
                    fontSize: 20,
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
                        ref
                            .read(discoverCategoryFilterProvider.notifier)
                            .setCategory(routeCategory);
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: EventCardLarge.carouselHeight,
          child: RepaintBoundary(
            child: ListView.separated(
              key: PageStorageKey('discover_${title}_list'),
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              addRepaintBoundaries: false,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: events.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8.0),
              itemBuilder: (context, index) {
                final event = events[index];
                final card = cardMap[event.id];
                final scheduledEvent = ScheduledEvent(
                  id: event.id,
                  title: event.title,
                  posterUrl: event.visuals.posterUrl,
                  startTime: event.timing.startDate ?? DateTime.now(),
                  endTime:
                      event.timing.effectiveEndDate ??
                      (event.timing.startDate ?? DateTime.now()).add(
                        const Duration(hours: 3),
                      ),
                  hostName: card?.hostUsername ?? '',
                  hostId: event.metadata.hostId,
                  hostImageUrl: card?.hostAvatarUrl,
                  auroraColors: event.visuals.auroraColors,
                  locationName: event.location?.displayName ?? 'Bloom Event',
                  coHostIds: event.coHostIds,
                );
                return EventCardLarge(event: scheduledEvent);
              },
            ),
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
          style: TextStyle(color: Colors.white54, fontSize: 14),
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
        SizedBox(height: 56 + MediaQuery.of(context).padding.bottom + 32),
      ],
    );
  }
}
