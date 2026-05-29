import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/auth/auth_providers.dart';

const _previewColor = Color(0xFFA2ABB5);
const _unreadAccent = Color(0xFFF04A9F);

User? conversationPeerUser(Conversation conversation) {
  final withEntity = conversation.conversationWith;
  return withEntity is User ? withEntity : null;
}

String conversationPeerUid(Conversation conversation) {
  return conversationPeerUser(conversation)?.uid ?? '';
}

String conversationPeerName(Conversation conversation) {
  final user = conversationPeerUser(conversation);
  if (user == null) return 'User';
  if (user.name.trim().isNotEmpty) return user.name.trim();
  if (user.uid.isNotEmpty) return user.uid;
  return 'User';
}

String? conversationPeerAvatarUrl(Conversation conversation) {
  final avatar = conversationPeerUser(conversation)?.avatar;
  if (avatar == null || avatar.trim().isEmpty) return null;
  return avatar;
}

String conversationPreviewText(Conversation conversation) {
  final last = conversation.lastMessage;
  if (last == null) return '';
  if (last is TextMessage) return last.text;
  if (last is MediaMessage) return 'Media';
  if (last is CustomMessage) {
    if (last.type == 'event_invite') return 'Shared an event';
    return last.customData?['eventName']?.toString() ?? 'Message';
  }
  return 'Message';
}

DateTime? conversationTimestamp(Conversation conversation) {
  return conversation.lastMessage?.sentAt ?? conversation.updatedAt;
}

String formatConversationTimestamp(DateTime dateTime) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final messageDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
  final yesterday = today.subtract(const Duration(days: 1));

  if (messageDay == today) {
    return DateFormat('h:mm a').format(dateTime).toLowerCase();
  }
  if (messageDay == yesterday) {
    return 'Yesterday';
  }
  return DateFormat('dd/MM/yyyy').format(dateTime);
}

class ConversationTile extends ConsumerWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = conversationPeerUid(conversation);
    final profileAsync = ref.watch(userProfileStreamProvider(uid));

    final avatarUrl =
        profileAsync.maybeWhen(
          data: (profile) => profile?['profile_image_url']?.toString(),
          orElse: () => null,
        ) ??
        conversationPeerAvatarUrl(conversation);

    final name =
        profileAsync.maybeWhen(
          data: (profile) {
            final n = profile?['name']?.toString().trim();
            return (n != null && n.isNotEmpty) ? n : null;
          },
          orElse: () => null,
        ) ??
        conversationPeerName(conversation);

    final unread = conversation.unreadMessageCount;
    final timestamp = conversationTimestamp(conversation);
    final timeLabel = timestamp != null
        ? formatConversationTimestamp(timestamp)
        : '';
    final timestampColor = unread > 0 ? _unreadAccent : _previewColor;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ConversationAvatar(url: avatarUrl),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (timeLabel.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              timeLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: timestampColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            conversationPreviewText(conversation),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: _previewColor,
                            ),
                          ),
                        ),
                        if (unread > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _UnreadBadge(count: unread),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: 50,
        height: 50,
        child: url != null
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _AvatarPlaceholder(),
              )
            : const _AvatarPlaceholder(),
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1A1D24),
      child: Icon(
        Icons.person,
        color: Colors.white.withValues(alpha: 0.4),
        size: 28,
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    final label = count > 99 ? '99+' : '$count';

    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: _unreadAccent,
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Colors.black,
        ),
      ),
    );
  }
}
