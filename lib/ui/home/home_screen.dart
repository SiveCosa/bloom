import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:bloom/domain/location/location_service.dart';
import 'package:bloom/domain/event/event_providers.dart';
import 'package:bloom/domain/home/home_schedule_filter.dart';
import 'package:bloom/domain/home/home_schedule_providers.dart';
import 'package:bloom/domain/navigation/navigation_providers.dart';
import 'package:bloom/domain/chat/chat_providers.dart';
import 'package:bloom/domain/calendar/scheduled_event.dart';
import 'package:bloom/domain/notification/notification_providers.dart';
import 'package:bloom/ui/event/widgets/event_card_large.dart';
import '../shared/widgets/gradient_top_bar.dart';
import 'widgets/create_event_cta.dart';
import 'widgets/discover_more_widget.dart';
import 'upcoming_events.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _spinController;
  final ValueNotifier<double> _dragOffset = ValueNotifier(0.0);
  final ValueNotifier<bool> _isRefreshing = ValueNotifier(false);
  final ValueNotifier<bool> _showIndicator = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController = ScrollController();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(locationServiceProvider).updateUserLocation();
      if (mounted) {
        ref.invalidate(eventsInAreaRawFeedProvider);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _spinController.dispose();
    _dragOffset.dispose();
    _isRefreshing.dispose();
    _showIndicator.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(locationServiceProvider).updateUserLocation();
    }
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
      await ref.read(locationServiceProvider).updateUserLocation();
      ref.invalidate(forYouRawFeedProvider);
      ref.invalidate(eventsInAreaRawFeedProvider);
      ref.invalidate(friendsAndMutualsRawFeedProvider);
      await Future.wait([
        ref.read(forYouRawFeedProvider.future),
        ref.read(eventsInAreaRawFeedProvider.future),
        ref.read(friendsAndMutualsRawFeedProvider.future),
      ]);
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      _isRefreshing.value = false;
      _showIndicator.value = false;
      _dragOffset.value = 0.0;
      _spinController.stop();
    }
  }

  void _handleHomeTabTap() {
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

  double _getIndicatorTop(double topPadding, double maskHeight, double dragOffset, bool isRefreshing) {
    const double indicatorHeight = 42.0;
    final double hiddenPosition = topPadding + maskHeight - indicatorHeight - 10.0;

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

        final double indicatorTop = _getIndicatorTop(topPadding, maskHeight, dragOffset, isRefreshing);
        final double opacity = isRefreshing ? 1.0 : pullProgress;
        final double scale = isRefreshing ? 1.0 : (0.6 + 0.4 * pullProgress);

        const Color iconColor = Colors.white;

        return AnimatedPositioned(
          duration: isRefreshing ? const Duration(milliseconds: 200) : Duration.zero,
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
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const maskHeight = 120.0;

    ref.listen(homeTabTapProvider, (previous, next) {
      if (next > 0) {
        _handleHomeTabTap();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E12),
      body: Stack(
        children: [
          // 1. Scrollable Content
          NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                top: topPadding + maskHeight + 20,
                bottom: 56 + bottomPadding + 32, // Nav bar height (56) + bottom safe area + premium breathing room
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CreateEventCTA(),
                  const UpcomingEventsSection(),
                  const SizedBox(height: 24),
                  HomeFeedCarouselSection(
                    key: const ValueKey('carousel_for_you'),
                    title: 'For You',
                    subtitle: 'Your social life curated',
                    iconAsset: 'assets/icons/home/fyp_icon.svg',
                    detailRoute: '/home/for-you',
                    rawFeedProvider: forYouRawFeedProvider,
                    scheduledEventsProvider: forYouScheduledEventsProvider,
                    errorPrefix: 'Error loading For You feed',
                  ),
                  const SizedBox(height: 24),
                  HomeFeedCarouselSection(
                    key: const ValueKey('carousel_in_your_area'),
                    title: 'In your Area',
                    subtitle: 'The Streets are calling',
                    iconAsset: 'assets/icons/home/area_icon.svg',
                    detailRoute: '/home/in-your-area',
                    rawFeedProvider: eventsInAreaRawFeedProvider,
                    scheduledEventsProvider: eventsInAreaScheduledEventsProvider,
                    errorPrefix: 'Error loading In your Area feed',
                  ),
                  const SizedBox(height: 24),
                  HomeFeedCarouselSection(
                    key: const ValueKey('carousel_friends_and_mutuals'),
                    title: 'Friends & Mutuals',
                    subtitle: 'Your inner circle’s outer circle',
                    iconAsset: 'assets/icons/home/FriAndMut_icon.svg',
                    detailRoute: '/home/friends-and-mutuals',
                    rawFeedProvider: friendsAndMutualsRawFeedProvider,
                    scheduledEventsProvider: friendsAndMutualsScheduledEventsProvider,
                    errorPrefix: 'Error loading Friends & Mutuals feed',
                  ),
                  const SizedBox(height: 24),
                  const DiscoverMoreWidget(),
                ],
              ),
            ),
          ),

          // Custom Reload Indicator (Emerges from below the app header)
          _buildReloadIndicator(topPadding, maskHeight),

          // 2. Solid Masking Layer (Sharp cut-off 5dp below pills)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPadding + maskHeight,
            child: Container(color: const Color(0xFF0B0E12)),
          ),

          // 3. Atmospheric Gradient Background (Stays at original height)
          const GradientTopBar(height: 100, showDarkOverlay: false),

          // 4. Header UI Components
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopRow(context),
                const SizedBox(height: 20),
                _buildFilterChips(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Messages (inbox_line)
          Consumer(
            builder: (context, ref, _) {
              final count = ref.watch(totalUnreadCountProvider);
              return GestureDetector(
                onTap: () => context.push('/messages'),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Badge(
                    isLabelVisible: count > 0,
                    backgroundColor: const Color(0xFFF04A9F),
                    label: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/nav/inbox_line.svg',
                      width: 24,
                      height: 24,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Center: Main Logo
          SvgPicture.asset('assets/logos/main_logo.svg', height: 40),

          // Right: Notifications
          Consumer(
            builder: (context, ref, _) {
              final unreadCount = ref.watch(unreadNotificationsCountProvider).maybeWhen(
                data: (v) => v,
                orElse: () => 0,
              );
              return GestureDetector(
                onTap: () => context.push('/notifications'),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Badge(
                    isLabelVisible: unreadCount > 0,
                    backgroundColor: const Color(0xFF0086D8), // Blue circle for notifications
                    smallSize: 10,
                    child: SvgPicture.asset(
                      'assets/icons/nav/bell_line.svg',
                      width: 24,
                      height: 24,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    const filters = HomeScheduleFilter.values;
    const labels = ['Upcoming', 'Hosting', 'Invites', 'Attending'];
    final counts = ref.watch(homeFilterCountsProvider);
    final activeFilter = ref.watch(homeScheduleFilterProvider);

    return SizedBox(
      height: 35,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isActive = activeFilter == filter;
          final count = counts[filter] ?? 0;

          return GestureDetector(
            onTap: () {
              ref.read(homeScheduleFilterProvider.notifier).setFilter(filter);
            },
             child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isActive ? 0.30 : 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07),
                  width: 0.5,
                ),
              ),
              alignment: Alignment.center,
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                  children: [
                    TextSpan(text: labels[index]),
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: '$count',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

}

class HomeFeedCarouselSection extends ConsumerWidget {
  static const double _carouselIconSize = 30;

  final String title;
  final String subtitle;
  final String iconAsset;
  final String detailRoute;
  final FutureProvider<List<Map<String, dynamic>>> rawFeedProvider;
  final Provider<List<ScheduledEvent>> scheduledEventsProvider;
  final String errorPrefix;

  const HomeFeedCarouselSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.detailRoute,
    required this.rawFeedProvider,
    required this.scheduledEventsProvider,
    required this.errorPrefix,
  });

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => context.push(detailRoute),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            SvgPicture.asset(
              iconAsset,
              width: _carouselIconSize,
              height: _carouselIconSize,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.5),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 16),
        SizedBox(
          height: EventCardLarge.carouselHeight,
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawFeedAsync = ref.watch(rawFeedProvider);

    return rawFeedAsync.when(
      skipLoadingOnRefresh: true,
      data: (rawList) {
        if (rawList.isEmpty) {
          return const SizedBox.shrink();
        }

        final events = ref.watch(scheduledEventsProvider);
        if (events.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          key: ValueKey('${title}_column'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            SizedBox(
              height: EventCardLarge.carouselHeight,
              child: RepaintBoundary(
                child: ListView.separated(
                  key: PageStorageKey('${title}_list'),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  addRepaintBoundaries: false,
                  itemCount: events.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return EventCardLarge(
                      event: events[index],
                      onOptionTap: () {},
                      onInterestedTap: () {},
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
      loading: () => _buildLoadingState(context),
      error: (err, stack) {
        debugPrint('$errorPrefix: $err');
        return const SizedBox.shrink();
      },
    );
  }
}
