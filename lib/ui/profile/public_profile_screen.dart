import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../domain/auth/auth_providers.dart';
import '../../domain/friendship/friendship_models.dart';
import '../../domain/friendship/friendship_providers.dart';
import '../../domain/event/event_providers.dart';
import '../../domain/calendar/scheduled_event.dart';
import '../../data/connection_repository.dart';
import '../../core/media/image_loader_helper.dart';
import '../shared/widgets/gradient_top_bar.dart';
import '../widgets/scheduled_event_card.dart';

class PublicProfileScreen extends ConsumerWidget {
  final String userId;

  const PublicProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileFutureProvider(userId));
    final connectionState = ref.watch(connectionStateProvider(userId)).value ?? FriendshipState.none;
    final hostedEventsAsync = ref.watch(publicHostedEventsProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E12),
      body: Stack(
        children: [
          // Background Gradient
          const GradientTopBar(height: 120, showDarkOverlay: false),
          
          profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0086D8))),
            error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white70))),
            data: (doc) {
              if (doc == null) return const Center(child: Text('User not found', style: TextStyle(color: Colors.white)));
              
              final username = doc['username']?.toString() ?? '—';
              final name = doc['name']?.toString() ?? 'Anonymous';
              final bio = doc['bio']?.toString() ?? 'No bio yet.';
              final imageUrl = doc['profile_image_url']?.toString();

              final counts = doc['counts'] as Map<String, dynamic>?;
              final friendsCount = (counts?['friends'] ?? 0).toString();
              final hostedCount = (counts?['hosted'] ?? 0).toString();
              final joinedCount = (counts?['joined'] ?? 0).toString();

              final socialLinks = doc['social_links'] as Map<String, dynamic>?;

              return CustomScrollView(
                slivers: [
                  // Task 2: SliverAppBar
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    pinned: true,
                    titleSpacing: 5,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      onPressed: () => context.pop(),
                    ),
                    title: Text(
                      username,
                      style: const TextStyle(
                        fontSize: 24, // Username font size
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    centerTitle: false,
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 15.0),
                        child: _buildTopIcon(
                          icon: Icons.menu,
                          onTap: () {
                            // TODO: Report/Block actions
                          },
                        ),
                      ),
                    ],
                  ),

                  // Profile Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          
                          // Avatar & Display Name (Centered per Design but with Start Alignment in prompt?)
                          // Prompt says "Bio aligns to the start", "Avatar: Centered".
                          Center(
                            child: Column(
                              children: [
                                buildAvatarImage(source: imageUrl, radius: 58),
                                const SizedBox(height: 15),
                                Text(
                                  name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 25),
                          
                          // Stats Row
                          Row(
                            children: [
                              Expanded(child: _buildStatItem('Friends made', friendsCount, () {})),
                              _buildDivider(),
                              Expanded(child: _buildStatItem('Hosted events', hostedCount, () {
                                context.push('/profile/$userId/hosted', extra: name);
                              })),
                              _buildDivider(),
                              Expanded(child: _buildStatItem('Joined events', joinedCount, () {
                                context.push('/profile/$userId/joined', extra: name);
                              })),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Task 3: Social Links
                          if (socialLinks != null && socialLinks.isNotEmpty)
                            _buildSocialLinksRow(socialLinks),
                          
                          const SizedBox(height: 15),
                          
                          // Bio (Left Justified)
                          Text(
                            bio,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.start,
                          ),
                          const SizedBox(height: 30),
                          
                          // Action Buttons
                          _buildConnectionActionBar(context, ref, connectionState),
                          const SizedBox(height: 30),
                          
                          // "Hosted Events" Section Title
                          const Text(
                            'HOSTED EVENTS',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 15),
                        ],
                      ),
                    ),
                  ),

                  // Task 4: Hosted Events Feed
                  hostedEventsAsync.when(
                    loading: () => const SliverToBoxAdapter(
                      child: Center(child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(color: Color(0xFF0086D8)),
                      )),
                    ),
                    error: (e, _) => SliverToBoxAdapter(
                      child: Center(child: Text('Error loading events: $e', style: const TextStyle(color: Colors.white70))),
                    ),
                    data: (events) {
                      if (events.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: Center(child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Text('No public events hosted yet.', style: TextStyle(color: Colors.white38)),
                          )),
                        );
                      }
                      
                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 15.0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final event = events[index];
                              
                              // Map Event to ScheduledEvent
                              final scheduledEvent = ScheduledEvent(
                                id: event.id,
                                title: event.title,
                                posterUrl: event.visuals.posterUrl,
                                startTime: event.timing.startDate ?? DateTime.now(),
                                endTime: event.timing.effectiveEndDate ?? DateTime.now(),
                                hostName: name, // We use the name from profile doc
                                hostId: event.metadata.hostId,
                                auroraColors: event.visuals.auroraColors,
                                locationName: event.location?.displayName ?? 'Bloom Event',
                              );

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: ScheduledEventCard(
                                  event: scheduledEvent,
                                  isHost: false,
                                  onTap: () => context.push('/event/${event.id}'),
                                ),
                              );
                            },
                            childCount: events.length,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  // Bottom Padding
                  const SliverToBoxAdapter(child: SizedBox(height: 50)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLinksRow(Map<String, dynamic> links) {
    final instagram = links['instagram']?.toString();
    final x = links['x']?.toString();
    final snapchat = links['snapchat']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          if (instagram != null && instagram.isNotEmpty)
            _buildSocialItem('assets/icons/profile/instagram_icon.svg', instagram),
          if (x != null && x.isNotEmpty)
            _buildSocialItem('assets/icons/profile/x_icon.svg', x),
          if (snapchat != null && snapchat.isNotEmpty)
            _buildSocialItem('assets/icons/profile/snapchat_icon.svg', snapchat),
        ],
      ),
    );
  }

  Widget _buildSocialItem(String iconPath, String handle) {
    return Padding(
      padding: const EdgeInsets.only(right: 15.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(iconPath, width: 14, height: 14, colorFilter: const ColorFilter.mode(Colors.white54, BlendMode.srcIn)),
          const SizedBox(width: 5),
          Text(
            handle,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 50, color: Colors.white12);
  }

  Widget _buildConnectionActionBar(BuildContext context, WidgetRef ref, FriendshipState state) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: _buildBaseButton(
              label: 'Message',
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              textColor: Colors.white,
              onTap: () {
                // TODO: Message logic
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildReactiveConnectionButton(context, ref, state),
          ),
        ],
      ),
    );
  }

  Widget _buildReactiveConnectionButton(BuildContext context, WidgetRef ref, FriendshipState state) {
    switch (state) {
      case FriendshipState.none:
        return _buildBaseButton(
          label: 'Add Friend',
          backgroundColor: const Color(0xFF0086D8),
          textColor: Colors.white,
          onTap: () => ref.read(connectionRepositoryProvider).sendRequest(userId),
        );
      case FriendshipState.pending:
        return _buildBaseButton(
          label: 'Requested',
          backgroundColor: Colors.white.withValues(alpha: 0.05),
          textColor: Colors.white54,
          onTap: () => _showCancelRequestModal(context, ref),
        );
      case FriendshipState.connected:
        return _buildBaseButton(
          label: 'Friends',
          backgroundColor: Colors.white.withValues(alpha: 0.05),
          textColor: Colors.white,
          trailingIcon: Icons.keyboard_arrow_down,
          onTap: () => _showManageFriendModal(context, ref),
        );
    }
  }

  Widget _buildBaseButton({
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onTap,
    IconData? trailingIcon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 4),
              Icon(trailingIcon, color: textColor, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  void _showCancelRequestModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF191B1D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.close, color: Colors.white),
              title: const Text('Cancel Request', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                ref.read(connectionRepositoryProvider).removeConnection(userId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showManageFriendModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF191B1D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.redAccent),
              title: const Text('Remove Friend', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                ref.read(connectionRepositoryProvider).removeConnection(userId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopIcon({
    IconData? icon,
    String? assetPath,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Center(
          child: assetPath != null
              ? assetPath.endsWith('.svg')
                    ? SvgPicture.asset(
                        assetPath,
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      )
                    : Image.asset(
                        assetPath,
                        width: 20,
                        height: 20,
                        color: Colors.white,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          icon ?? Icons.error,
                          color: Colors.white,
                          size: 22,
                        ),
                      )
              : Icon(icon ?? Icons.error, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

