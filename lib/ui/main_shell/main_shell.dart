import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/media/image_loader_helper.dart';

import '../../domain/auth/auth_providers.dart';
import '../../domain/navigation/navigation_providers.dart';

import '../home/home_screen.dart';
import '../discover/discover_screen.dart';
import '../calendar/calendar_screen.dart';
import '../profile/profile_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final List<Widget> _screens = const [
    HomeScreen(),
    DiscoverScreen(),
    // CreateEventScreen() is pushed as a full route to hide bottom nav
    CalendarScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Ghost account protection
    ref.listen(currentUserProfileProvider, (previous, next) async {
      if (next is AsyncData && next.value == null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            await user.delete();
          } catch (_) {}
          await FirebaseAuth.instance.signOut();
          ref.invalidate(authControllerProvider);
        }
      }
    });

    final currentIndex = ref.watch(mainShellIndexProvider);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: currentIndex, children: _screens),
      bottomNavigationBar: _buildBottomNav(currentIndex),
    );
  }

  Widget _buildBottomNav(int currentIndex) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80.0, sigmaY: 80.0),
        child: Container(
          height: 56 + bottomPadding,
          padding: EdgeInsets.only(bottom: bottomPadding),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0E12).withValues(alpha: 0.70),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.07),
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(
                index: 0,
                currentIndex: currentIndex,
                lineIcon: 'assets/icons/nav/home_line.svg',
                fillIcon: 'assets/icons/nav/home_fill.svg',
              ),
              _buildNavItem(
                index: 1,
                currentIndex: currentIndex,
                lineIcon: 'assets/icons/nav/discover_line.svg',
                fillIcon: 'assets/icons/nav/discover_fill.svg',
              ),
              _buildCreateItem(currentIndex),
              _buildNavItem(
                index: 3,
                currentIndex: currentIndex,
                lineIcon: 'assets/icons/nav/calendar_line.svg',
                fillIcon: 'assets/icons/nav/calendar_fill.svg',
              ),
              _buildProfileItem(currentIndex),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required int currentIndex,
    required String lineIcon,
    required String fillIcon,
  }) {
    // Map index to original screens list if we removed one
    final actualIndex = index > 2 ? index - 1 : index;
    final isActive = currentIndex == actualIndex;
    final iconPath = isActive ? fillIcon : lineIcon;

    // Calendar size adjustment
    final double size = index == 3 ? 22.5 : 24.0;

    Widget iconWidget = SvgPicture.asset(
      iconPath,
      width: size,
      height: size,
      colorFilter: isActive
          ? null
          : const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );

    if (isActive) {
      iconWidget = ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [Color(0xFFC151FD), Color(0xFFF04A9F), Color(0xFFFFB965)],
          ).createShader(bounds);
        },
        blendMode: BlendMode.srcIn,
        child: iconWidget,
      );
    }

    return Expanded(
      child: InkWell(
        onTap: () {
          if (isActive && actualIndex == 0) {
            ref.read(homeTabTapProvider.notifier).increment();
          } else {
            ref.read(mainShellIndexProvider.notifier).setIndex(actualIndex);
          }
        },
        child: SizedBox(
          height: double.infinity,
          child: Center(
            child: SizedBox(height: 48, child: Center(child: iconWidget)),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateItem(int currentIndex) {
    // This button now pushes a full-screen route to hide the bottom nav
    return Expanded(
      child: InkWell(
        onTap: () => context.push('/create-event'),
        child: SizedBox(
          height: double.infinity,
          child: Center(
            child: SizedBox(
              height: 40,
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/nav/create_fill.svg',
                  width: 40,
                  height: 40,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileItem(int currentIndex) {
    final isActive = currentIndex == 3; // Shifted index
    final userAsync = ref.watch(currentUserProfileProvider);
    final profileUrl = userAsync.value?['profile_image_url'] as String?;

    return Expanded(
      child: InkWell(
        onTap: () => ref.read(mainShellIndexProvider.notifier).setIndex(3),
        child: SizedBox(
          height: double.infinity,
          child: Center(
            child: SizedBox(
              height: 48,
              child: Center(
                child: Container(
                  width: 29, // 25 + 4 padding for border
                  height: 29,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isActive
                        ? const LinearGradient(
                            colors: [
                              Color(0xFFC151FD),
                              Color(0xFFF04A9F),
                              Color(0xFFFFB965),
                            ],
                          )
                        : null,
                  ),
                  child: Center(
                    child: buildAvatarImage(
                      source: profileUrl,
                      radius: 12.5,
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
}
