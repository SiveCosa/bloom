import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/notification/notification_model.dart';
import '../../../domain/notification/notification_providers.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'action_buttons.dart';
import '../../../data/connection_repository.dart';
import '../../../domain/friendship/friendship_providers.dart';

class NotificationTile extends ConsumerWidget {
  final AppNotification notification;

  const NotificationTile({super.key, required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (notification.type) {
      case NotificationType.friendRequest:
        return _FriendRequestTile(notification: notification);
      case NotificationType.eventInvite:
        return _EventInviteTile(notification: notification);
      case NotificationType.friendPostedEvent:
        return _FriendPostedEventTile(notification: notification);
      case NotificationType.eventRsvp:
        return _EventRsvpTile(
          notification: notification,
          isWaitlist: false,
          isRequest: false,
        );
      case NotificationType.eventWaitlist:
        return _EventRsvpTile(
          notification: notification,
          isWaitlist: true,
          isRequest: false,
        );
      case NotificationType.eventRequestToJoin:
        return _EventRsvpTile(
          notification: notification,
          isWaitlist: false,
          isRequest: true,
        );
      case NotificationType.friendRequestAccepted:
        return _FriendRequestAcceptedTile(notification: notification);
      case NotificationType.eventUpdate:
        return _EventUpdateTile(notification: notification);
      case NotificationType.eventReminder:
        return _EventReminderTile(notification: notification);
      case NotificationType.waitlistApproved:
        return _WaitlistApprovedTile(notification: notification);
      case NotificationType.coHostInvite:
        return _CoHostInviteTile(notification: notification);
      case NotificationType.eventNudge:
        return _EventNudgeTile(notification: notification);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _BaseNotificationTile extends ConsumerWidget {
  final AppNotification notification;
  final Widget leading;
  final Widget content;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _BaseNotificationTile({
    required this.notification,
    required this.leading,
    required this.content,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!notification.isRead) {
          ref.read(notificationControllerProvider)?.markAsRead(notification.id);
        }
        if (onTap != null) onTap!();
      },
      child: Container(
        height: 80,
        color: notification.isRead
            ? Colors.transparent
            : Colors.white.withValues(alpha: 0.1),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(child: content),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String? url;
  final Widget? badge;

  const _UserAvatar({this.url, this.badge});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[800],
          backgroundImage: url != null && url!.isNotEmpty
              ? NetworkImage(url!)
              : null,
          child: url == null || url!.isEmpty
              ? const Icon(Icons.person, color: Colors.white, size: 24)
              : null,
        ),
        if (badge != null) Positioned(right: -4, bottom: -4, child: badge!),
      ],
    );
  }
}

class _EventImage extends StatelessWidget {
  final String? url;

  const _EventImage({this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        image: url != null && url!.isNotEmpty
            ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
            : null,
      ),
      child: url == null || url!.isEmpty
          ? const Icon(Icons.event, color: Colors.white)
          : null,
    );
  }
}

class _FriendRequestTile extends ConsumerStatefulWidget {
  final AppNotification notification;

  const _FriendRequestTile({required this.notification});

  @override
  ConsumerState<_FriendRequestTile> createState() => _FriendRequestTileState();
}

class _FriendRequestTileState extends ConsumerState<_FriendRequestTile> {
  bool accepted = false;
  bool processing = false;

  @override
  Widget build(BuildContext context) {
    return _BaseNotificationTile(
      notification: widget.notification,
      leading: _UserAvatar(url: widget.notification.actorAvatarUrl),
      content: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 15),
          children: [
            TextSpan(
              text: widget.notification.actorUsername ?? 'Someone',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: ' sent you a friend request '),
            TextSpan(
              text: timeago.format(
                widget.notification.createdAt,
                locale: 'en_short',
              ),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
      trailing: accepted
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Accepted',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : ActionButtons(
              primaryText: 'Accept',
              isLoading: processing,
              onPrimaryPressed: () async {
                setState(() => processing = true);
                try {
                  final actorId = widget.notification.actorId;
                  if (actorId != null) {
                    await ref
                        .read(connectionRepositoryProvider)
                        .acceptRequest(actorId);
                    invalidateFriendshipCaches(ref, actorId);
                  }
                  if (mounted) {
                    setState(() {
                      accepted = true;
                      processing = false;
                    });
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => processing = false);
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to accept request: $e')),
                    );
                  }
                }
              },
              onSecondaryPressed: () async {
                setState(() => processing = true);
                try {
                  final actorId = widget.notification.actorId;
                  if (actorId != null) {
                    await ref
                        .read(connectionRepositoryProvider)
                        .removeConnection(actorId);
                    ref.invalidate(recommendedFriendsProvider);
                    ref.invalidate(incomingRequestsCountProvider);
                    ref.invalidate(notificationsProvider);
                  }
                  if (mounted) {
                    setState(() => processing = false);
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => processing = false);
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to decline request: $e')),
                    );
                  }
                }
              },
            ),
    );
  }
}

class _EventInviteTile extends StatelessWidget {
  final AppNotification notification;

  const _EventInviteTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    return _BaseNotificationTile(
      notification: notification,
      onTap: () {
        if (notification.targetId != null) {
          context.push('/event/${notification.targetId}');
        }
      },
      leading: _UserAvatar(url: notification.actorAvatarUrl),
      content: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 15),
          children: [
            TextSpan(
              text: notification.actorUsername ?? 'Someone',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: ' invited you to the '),
            TextSpan(
              text: '"${notification.targetName ?? 'event'}"',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: ' event '),
            TextSpan(
              text: timeago.format(notification.createdAt, locale: 'en_short'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
      trailing: _EventImage(url: notification.targetImageUrl),
    );
  }
}

class _FriendPostedEventTile extends StatelessWidget {
  final AppNotification notification;

  const _FriendPostedEventTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    return _BaseNotificationTile(
      notification: notification,
      onTap: () {
        if (notification.targetId != null) {
          context.push('/event/${notification.targetId}');
        }
      },
      leading: _UserAvatar(url: notification.actorAvatarUrl),
      content: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 15),
          children: [
            TextSpan(
              text: notification.actorUsername ?? 'Someone',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: ' posted an event\n'),
            TextSpan(
              text: '"${notification.targetName ?? 'event'}" ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: timeago.format(notification.createdAt, locale: 'en_short'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
      trailing: _EventImage(url: notification.targetImageUrl),
    );
  }
}

class _EventRsvpTile extends StatelessWidget {
  final AppNotification notification;
  final bool isWaitlist;
  final bool isRequest;

  const _EventRsvpTile({
    required this.notification,
    required this.isWaitlist,
    required this.isRequest,
  });

  @override
  Widget build(BuildContext context) {
    String actionText = ' will be going to your event ';
    if (isWaitlist) actionText = ' joined your event waitlist ';
    if (isRequest) actionText = ' requested to join your event ';

    String othersText = '';
    if (notification.groupedCount > 0) {
      othersText = ' +${notification.groupedCount} others';
    }

    final badgeIcon = isWaitlist || isRequest
        ? Icons.question_mark
        : Icons.check;

    return _BaseNotificationTile(
      notification: notification,
      onTap: () {
        if (notification.targetId != null) {
          context.push('/event/${notification.targetId}');
        }
      },
      leading: _UserAvatar(
        url: notification.actorAvatarUrl,
        badge: Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(badgeIcon, color: Colors.black, size: 14),
        ),
      ),
      content: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 15),
          children: [
            TextSpan(
              text: '${notification.actorUsername ?? 'Someone'}$othersText',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: actionText),
            TextSpan(
              text: '"${notification.targetName ?? 'event'}" ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: timeago.format(notification.createdAt, locale: 'en_short'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
      trailing: _EventImage(url: notification.targetImageUrl),
    );
  }
}

class _FriendRequestAcceptedTile extends StatelessWidget {
  final AppNotification notification;
  const _FriendRequestAcceptedTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    return _BaseNotificationTile(
      notification: notification,
      leading: _UserAvatar(url: notification.actorAvatarUrl),
      content: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 15),
          children: [
            TextSpan(
              text: notification.actorUsername ?? 'Someone',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: ' accepted your friend request '),
            TextSpan(
              text: timeago.format(notification.createdAt, locale: 'en_short'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventUpdateTile extends StatelessWidget {
  final AppNotification notification;
  const _EventUpdateTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    return _BaseNotificationTile(
      notification: notification,
      onTap: () {
        if (notification.targetId != null) {
          context.push('/event/${notification.targetId}');
        }
      },
      leading: _UserAvatar(url: notification.actorAvatarUrl),
      content: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 15),
          children: [
            const TextSpan(text: 'Update for '),
            TextSpan(
              text: '"${notification.targetName ?? 'event'}"',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: ': The time or location has changed '),
            TextSpan(
              text: timeago.format(notification.createdAt, locale: 'en_short'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
      trailing: _EventImage(url: notification.targetImageUrl),
    );
  }
}

class _EventReminderTile extends StatelessWidget {
  final AppNotification notification;
  const _EventReminderTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final phase = notification.actorUsername?.toLowerCase() ?? 'today';
    String reminderText = '';
    if (phase == 'live') {
      reminderText = 'Live Now!';
    } else if (phase == 'today') {
      reminderText = 'Today!';
    } else {
      reminderText = 'Tomorrow!';
    }

    return _BaseNotificationTile(
      notification: notification,
      onTap: () {
        if (notification.targetId != null) {
          context.push('/event/${notification.targetId}');
        }
      },
      leading: _UserAvatar(url: notification.actorAvatarUrl),
      content: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 15),
          children: [
            const TextSpan(text: 'Reminder: '),
            TextSpan(
              text: '"${notification.targetName ?? 'event'}"',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: ' is $reminderText '),
            TextSpan(
              text: timeago.format(notification.createdAt, locale: 'en_short'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
      trailing: _EventImage(url: notification.targetImageUrl),
    );
  }
}

class _WaitlistApprovedTile extends StatelessWidget {
  final AppNotification notification;
  const _WaitlistApprovedTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    return _BaseNotificationTile(
      notification: notification,
      onTap: () {
        if (notification.targetId != null) {
          context.push('/event/${notification.targetId}');
        }
      },
      leading: _UserAvatar(url: notification.actorAvatarUrl),
      content: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 15),
          children: [
            const TextSpan(
              text: "You're in! ",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: "You've been moved off the waitlist for "),
            TextSpan(
              text: '"${notification.targetName ?? 'event'}" ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: timeago.format(notification.createdAt, locale: 'en_short'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
      trailing: _EventImage(url: notification.targetImageUrl),
    );
  }
}

class _CoHostInviteTile extends StatelessWidget {
  final AppNotification notification;
  const _CoHostInviteTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    return _BaseNotificationTile(
      notification: notification,
      onTap: () {
        if (notification.targetId != null) {
          context.push('/event/${notification.targetId}');
        }
      },
      leading: _UserAvatar(url: notification.actorAvatarUrl),
      content: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 15),
          children: [
            TextSpan(
              text: notification.actorUsername ?? 'Someone',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: ' made you a co-host for '),
            TextSpan(
              text: '"${notification.targetName ?? 'event'}" ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: timeago.format(notification.createdAt, locale: 'en_short'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
      trailing: _EventImage(url: notification.targetImageUrl),
    );
  }
}

class _EventNudgeTile extends StatelessWidget {
  final AppNotification notification;
  const _EventNudgeTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    return _BaseNotificationTile(
      notification: notification,
      onTap: () {
        if (notification.targetId != null) {
          context.push('/event/${notification.targetId}');
        }
      },
      leading: _UserAvatar(url: notification.actorAvatarUrl),
      content: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 15),
          children: [
            TextSpan(
              text:
                  notification.message ?? 'Nudge nudge. Don\'t forget to RSVP!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: ' '),
            TextSpan(
              text: timeago.format(notification.createdAt, locale: 'en_short'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
      trailing: _EventImage(url: notification.targetImageUrl),
    );
  }
}
