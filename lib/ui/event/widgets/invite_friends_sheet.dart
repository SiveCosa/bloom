import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import '../../../domain/event/event.dart';
import '../../../domain/friendship/friendship_providers.dart';
import '../../../domain/chat/chat_send_helper.dart';
import '../../shared/widgets/custom_text_fields.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final inviteFriendsProfilesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final friendsConnections = await ref.watch(friendsMadeProvider.future);
  if (friendsConnections.isEmpty) return [];

  final firestore = FirebaseFirestore.instance;
  final futures = friendsConnections.map((conn) => firestore.collection('users').doc(conn['uid'] as String).get());
  final snaps = await Future.wait(futures);

  return snaps.where((snap) => snap.exists && snap.data() != null).map((snap) => snap.data()!).toList();
});

class InviteFriendsSheet extends ConsumerStatefulWidget {
  final Event event;

  const InviteFriendsSheet({super.key, required this.event});

  @override
  ConsumerState<InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends ConsumerState<InviteFriendsSheet> {
  final Set<String> _selectedFriends = {};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _toggleSelection(String uid) {
    setState(() {
      if (_selectedFriends.contains(uid)) {
        _selectedFriends.remove(uid);
      } else {
        _selectedFriends.add(uid);
      }
    });
  }

  Future<void> _sendInvites() async {
    if (_selectedFriends.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    final messageText = _messageController.text.trim();

    try {
      for (final uid in _selectedFriends) {
        final customData = {
          'eventId': widget.event.id,
          'eventName': widget.event.title,
          'posterUrl': widget.event.visuals.posterUrl ?? '',
          'attachedMessage': messageText,
        };

        final message = CustomMessage(
          receiverUid: uid,
          receiverType: CometChatReceiverType.user,
          type: 'event_invite',
          customData: customData,
        );

        await sendCustomMessageSafe(message);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invites sent successfully!')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(inviteFriendsProfilesProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E), // Updated to match general dark sheet color
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle and Title
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Invite friends',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RoundedTextField(
                controller: _searchController,
                hintText: 'Search friends',
                prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Friend List
            Expanded(
              child: friendsAsync.when(
                data: (friends) {
                  final filteredFriends = friends.where((friend) {
                    final name = (friend['name'] as String? ?? '').toLowerCase();
                    final username = (friend['username'] as String? ?? '').toLowerCase();
                    return name.contains(_searchQuery) || username.contains(_searchQuery);
                  }).toList();

                  if (filteredFriends.isEmpty) {
                    return const Center(
                      child: Text(
                        'No friends found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredFriends.length,
                    itemBuilder: (context, index) {
                      final friend = filteredFriends[index];
                      final uid = friend['uid'] as String;
                      final isSelected = _selectedFriends.contains(uid);

                      return _FriendListItem(
                        uid: uid,
                        userProfile: friend,
                        isSelected: isSelected,
                        onTap: () => _toggleSelection(uid),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.blue),
                ),
                error: (e, st) => Center(
                  child: Text(
                    'Error loading friends: $e',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),

            // Bottom Action Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _selectedFriends.isEmpty
                  ? _buildCopyShareBar()
                  : _buildChatInputBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyShareBar() {
    final eventUrl = 'https://www.bloomapp.software/event/${widget.event.id}';

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: eventUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied to clipboard')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF25282D),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      eventUrl,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.copy, color: Colors.white70, size: 20),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () {
            Share.share(eventUrl);
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xFFE91E63),
                  Color(0xFF9C27B0),
                  Color(0xFFFF9800),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.share, color: Colors.white, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildChatInputBar() {
    return ListenableBuilder(
      listenable: _messageController,
      builder: (context, _) {
        final hasText = _messageController.text.isNotEmpty;
        return Container(
          constraints: const BoxConstraints(minHeight: 50),
          decoration: BoxDecoration(
            color: const Color(0xFF25282D),
            borderRadius: BorderRadius.circular(25),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Row(
              crossAxisAlignment:
                  hasText ? CrossAxisAlignment.end : CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    minLines: 1,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Color(0xFF8A8F98)),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.only(
                        left: 12,
                        right: 8,
                        top: 8,
                        bottom: 8,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: _isSending ? null : _sendInvites,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0086D8),
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FriendListItem extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> userProfile;
  final bool isSelected;
  final VoidCallback onTap;

  const _FriendListItem({
    required this.uid,
    required this.userProfile,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = userProfile['profile_image_url'] as String? ?? '';
    final name = userProfile['name'] as String? ?? 'Unknown';
    final username = userProfile['username'] as String? ?? '';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[800],
              ),
              child: ClipOval(
                child: avatarUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, error, stackTrace) => const Icon(
                          Icons.person,
                          color: Colors.white54,
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        color: Colors.white54,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    username.startsWith('@') ? username : '@$username',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? Colors.blue : Colors.white54,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
