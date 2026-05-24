import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/routing/chat_navigation.dart';
import '../../domain/auth/auth_providers.dart';
import '../../domain/friendship/friendship_providers.dart';
import '../shared/widgets/gradient_top_bar.dart';

class MessagesListScreen extends ConsumerStatefulWidget {
  const MessagesListScreen({super.key});

  @override
  ConsumerState<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends ConsumerState<MessagesListScreen> {
  List<Conversation> _conversations = [];
  bool _loadingConversations = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _loadingConversations = true;
      _error = null;
    });

    try {
      final loggedIn = await CometChat.getLoggedInUser();
      if (loggedIn == null) {
        if (mounted) {
          setState(() {
            _loadingConversations = false;
            _conversations = [];
          });
        }
        return;
      }

      final request = (ConversationsRequestBuilder()..setLimit(50)).build();
      final list = await request.fetchNext(onSuccess: null, onError: null);
      if (mounted) {
        setState(() {
          _conversations = list;
          _loadingConversations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingConversations = false;
          _error = e.toString();
        });
      }
    }
  }

  List<_ChatListEntry> _mergeEntries(List<Map<String, dynamic>> friends) {
    final conversationByUid = <String, Conversation>{};
    for (final conversation in _conversations) {
      if (conversation.conversationType != CometChatConversationType.user) {
        continue;
      }
      final uid = _peerUid(conversation);
      if (uid.isNotEmpty) {
        conversationByUid[uid] = conversation;
      }
    }

    final entries = <_ChatListEntry>[];
    final seen = <String>{};

    for (final friend in friends) {
      final uid = friend['uid']?.toString() ?? '';
      if (uid.isEmpty || seen.contains(uid)) continue;
      seen.add(uid);
      entries.add(_ChatListEntry(
        uid: uid,
        conversation: conversationByUid[uid],
      ));
    }

    for (final conversation in _conversations) {
      if (conversation.conversationType != CometChatConversationType.user) {
        continue;
      }
      final uid = _peerUid(conversation);
      if (uid.isEmpty || seen.contains(uid)) continue;
      seen.add(uid);
      entries.add(_ChatListEntry(uid: uid, conversation: conversation));
    }

    entries.sort((a, b) {
      final aTime = a.sortTime;
      final bTime = b.sortTime;
      if (aTime != null && bTime != null) {
        return bTime.compareTo(aTime);
      }
      if (aTime != null) return -1;
      if (bTime != null) return 1;
      return a.uid.compareTo(b.uid);
    });

    return entries;
  }

  String _peerLabel(Conversation conversation) {
    final withEntity = conversation.conversationWith;
    if (withEntity is User) {
      if (withEntity.name.trim().isNotEmpty) return withEntity.name;
      return withEntity.uid.isNotEmpty ? withEntity.uid : 'User';
    }
    if (withEntity is Group) {
      return withEntity.name.isNotEmpty ? withEntity.name : 'Group';
    }
    return 'Chat';
  }

  String _peerUid(Conversation conversation) {
    final withEntity = conversation.conversationWith;
    if (withEntity is User) return withEntity.uid;
    if (withEntity is Group) return withEntity.guid;
    return '';
  }

  String _preview(Conversation? conversation) {
    final last = conversation?.lastMessage;
    if (last == null) return 'No messages yet';
    if (last is TextMessage) return last.text;
    if (last is MediaMessage) return 'Media';
    if (last is CustomMessage) {
      return last.customData?['eventName']?.toString() ?? 'Event invite';
    }
    return 'Message';
  }

  String _timeLabel(Conversation? conversation) {
    final updated = conversation?.updatedAt ?? conversation?.lastMessage?.sentAt;
    if (updated == null) return '';
    return DateFormat('MMM d').format(updated);
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsMadeProvider);

    return Container(
      color: const Color(0xFF0B0E12),
      child: Stack(
        children: [
          const GradientTopBar(height: 100, showDarkOverlay: false),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text(
                'Messages',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              leadingWidth: 48,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => context.pop(),
              ),
            ),
            body: _buildBody(friendsAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AsyncValue<List<Map<String, dynamic>>> friendsAsync) {
    if (_loadingConversations || friendsAsync.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0086D8)),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.white54),
          textAlign: TextAlign.center,
        ),
      );
    }

    final friends = friendsAsync.value ?? [];
    final entries = _mergeEntries(friends);

    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'No friends to message yet',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      color: const Color(0xFF0086D8),
      child: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          color: Colors.white.withValues(alpha: 0.08),
        ),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final conversation = entry.conversation;
          final unread = conversation?.unreadMessageCount ?? 0;

          return _MessageListTile(
            uid: entry.uid,
            fallbackName: conversation != null ? _peerLabel(conversation) : null,
            preview: _preview(conversation),
            timeLabel: _timeLabel(conversation),
            unread: unread,
            onTap: (name) => openChat(context, uid: entry.uid, username: name),
          );
        },
      ),
    );
  }
}

class _ChatListEntry {
  const _ChatListEntry({
    required this.uid,
    this.conversation,
  });

  final String uid;
  final Conversation? conversation;

  DateTime? get sortTime =>
      conversation?.updatedAt ?? conversation?.lastMessage?.sentAt;
}

class _MessageListTile extends ConsumerWidget {
  const _MessageListTile({
    required this.uid,
    required this.fallbackName,
    required this.preview,
    required this.timeLabel,
    required this.unread,
    required this.onTap,
  });

  final String uid;
  final String? fallbackName;
  final String preview;
  final String timeLabel;
  final int unread;
  final void Function(String name) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileStreamProvider(uid));

    final name = profileAsync.when(
      data: (profile) {
        final profileName = profile?['name']?.toString().trim();
        if (profileName != null && profileName.isNotEmpty) return profileName;
        final username = profile?['username']?.toString().trim();
        if (username != null && username.isNotEmpty) return username;
        return fallbackName ?? 'User';
      },
      loading: () => fallbackName ?? 'User',
      error: (_, _) => fallbackName ?? 'User',
    );

    return ListTile(
      onTap: () => onTap(name),
      title: Text(
        name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (timeLabel.isNotEmpty)
            Text(
              timeLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          if (unread > 0) ...[
            if (timeLabel.isNotEmpty) const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF04A9F),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
