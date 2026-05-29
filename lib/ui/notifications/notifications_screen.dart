import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shared/widgets/gradient_top_bar.dart';
import '../../domain/notification/notification_model.dart';
import '../../domain/notification/notification_providers.dart';
import '../../domain/friendship/friendship_providers.dart';
import 'widgets/notification_tiles.dart';
import 'widgets/navigation_tile.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final countAsync = ref.watch(incomingRequestsCountProvider);

    return Container(
      color: const Color(0xFF0B0E12),
      child: Stack(
        children: [
          const GradientTopBar(height: 100, showDarkOverlay: false),
          PopScope(
            canPop: true,
            onPopInvokedWithResult: (didPop, result) {
              ref.read(notificationControllerProvider)?.markAllAsRead();
            },
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: const Text(
                  'Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                centerTitle: false,
                leadingWidth: 48,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () {
                    ref.read(notificationControllerProvider)?.markAllAsRead();
                    Navigator.of(context).pop();
                  },
                ),
              ),
              body: notificationsAsync.when(
                data: (notifications) {
                  // Group notifications
                  final now = DateTime.now();
                  final today = <AppNotification>[];
                  final last7Days = <AppNotification>[];
                  final last30Days = <AppNotification>[];
                  int pendingInvitesCount = 0;
                  int unreadInvitesCount = 0;
                  int unreadFriendRequests = 0;

                  for (var n in notifications) {
                    // We still count them for the headers, but we DO NOT skip them for the feed
                    if (n.type == NotificationType.eventInvite ||
                        n.type == NotificationType.coHostInvite) {
                      pendingInvitesCount++;
                      if (!n.isRead) unreadInvitesCount++;
                    }

                    if (n.type == NotificationType.friendRequest && !n.isRead) {
                      unreadFriendRequests++;
                    }

                    final diff = now.difference(n.createdAt);
                    if (diff.inHours < 24 && now.day == n.createdAt.day) {
                      today.add(n);
                    } else if (diff.inDays <= 7) {
                      last7Days.add(n);
                    } else {
                      last30Days.add(n);
                    }
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    children: [
                      // Friend Requests Tile
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: NavigationTile(
                          onTap: () =>
                              context.push('/notifications/friend-requests'),
                          icon: const Icon(
                            Icons.people_alt,
                            color: Colors.white,
                            size: 22,
                          ),
                          iconBackgroundColor: const Color(
                            0xFFF04A9F,
                          ), // Custom pink
                          title: 'Friend requests',
                          subtitle: countAsync.when(
                            data: (count) {
                              final hasUnread = unreadFriendRequests > 0;
                              return Text(
                                hasUnread
                                    ? '$unreadFriendRequests new friend request${unreadFriendRequests > 1 ? 's' : ''}'
                                    : (count > 0
                                          ? '$count pending friend request${count > 1 ? 's' : ''}'
                                          : 'You have no new friend requests'),
                                style: TextStyle(
                                  color: hasUnread
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.38),
                                  fontWeight: hasUnread
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              );
                            },
                            loading: () => Text(
                              'Checking requests...',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.38),
                                fontSize: 14,
                              ),
                            ),
                            error: (err, stack) => Text(
                              'Failed to load requests',
                              style: TextStyle(
                                color: Colors.redAccent.withValues(alpha: 0.8),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Event Invitations Tile
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: NavigationTile(
                          onTap: () =>
                              context.push('/notifications/event-invitations'),
                          icon: const Icon(
                            Icons.mail,
                            color: Colors.white,
                            size: 22,
                          ),
                          iconBackgroundColor: const Color(
                            0xFFB087F5,
                          ), // Custom purple
                          title: 'Event invitations',
                          subtitle: Text(
                            unreadInvitesCount > 0
                                ? '$unreadInvitesCount new invitation${unreadInvitesCount > 1 ? 's' : ''}'
                                : (pendingInvitesCount > 0
                                      ? '$pendingInvitesCount pending invitation${pendingInvitesCount > 1 ? 's' : ''}'
                                      : 'You have no pending invitations'),
                            style: TextStyle(
                              color: unreadInvitesCount > 0
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.38),
                              fontWeight: unreadInvitesCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (today.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: _SectionHeader(title: 'Today'),
                        ),
                        ...today.map((n) => NotificationTile(notification: n)),
                        const SizedBox(height: 16),
                      ],
                      if (last7Days.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: _SectionHeader(title: 'Last 7 days'),
                        ),
                        ...last7Days.map(
                          (n) => NotificationTile(notification: n),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (last30Days.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: _SectionHeader(title: 'Last 30 days'),
                        ),
                        ...last30Days.map(
                          (n) => NotificationTile(notification: n),
                        ),
                      ],

                      if (notifications.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 120),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_off_rounded,
                                  color: Colors.white24,
                                  size: 64,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No new notifications',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                error: (err, stack) => Center(
                  child: Text(
                    'Failed to load notifications: $err',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            ), // Close Scaffold
          ), // Close PopScope
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
