import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:bloom/domain/location/location_service.dart';
import 'package:bloom/domain/event/event_providers.dart';
import 'package:bloom/ui/event/widgets/event_card_large.dart';
import '../shared/widgets/gradient_top_bar.dart';
import 'widgets/create_event_cta.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _selectedFilterIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationServiceProvider).updateUserLocation();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(locationServiceProvider).updateUserLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const maskHeight = 120.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E12),
      body: Stack(
        children: [
          // 1. Scrollable Content
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              top: topPadding + maskHeight + 20,
              bottom: 56 + bottomPadding + 32, // Nav bar height (56) + bottom safe area + premium breathing room
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CreateEventCTA(),
                const SizedBox(height: 24),
                _buildForYouSection(),
              ],
            ),
          ),

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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Messages
          GestureDetector(
            onTap: () => context.push('/messages'),
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

          // Center: Main Logo
          SvgPicture.asset('assets/logos/main_logo.svg', height: 40),

          // Right: Notifications
          GestureDetector(
            onTap: () => context.push('/notifications'),
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
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final chips = [
      {'label': 'Upcoming', 'count': '0'},
      {'label': 'Hosting', 'count': '0'},
      {'label': 'Invites', 'count': '0'},
      {'label': 'Attending', 'count': '0'},
    ];

    return SizedBox(
      height: 35,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          final isActive = _selectedFilterIndex == index;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilterIndex = index;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isActive ? 0.12 : 0.08),
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
                    TextSpan(text: chip['label']),
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: chip['count'],
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
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

  Widget _buildForYouSection() {
    final rawFeedAsync = ref.watch(forYouRawFeedProvider);

    return rawFeedAsync.when(
      data: (rawList) {
        if (rawList.isEmpty) {
          return const SizedBox.shrink();
        }

        final events = ref.read(forYouScheduledEventsProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () => context.push('/home/for-you'),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/home/fyp_icon.svg',
                      width: 30,
                      height: 30,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'For You',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Your social life curated',
                            style: TextStyle(
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
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 394,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
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
          ],
        );
      },
      loading: () => const SizedBox(
        height: 394,
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFF04A9F),
          ),
        ),
      ),
      error: (err, stack) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Center(
          child: Text(
            'Error loading For You feed: $err',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      ),
    );
  }

}
