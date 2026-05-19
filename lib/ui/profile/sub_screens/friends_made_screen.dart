import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/media/image_loader_helper.dart';
import '../../../domain/friendship/friendship_providers.dart';
import '../../../domain/auth/auth_providers.dart';
import '../../../data/connection_repository.dart';
import '../../shared/widgets/gradient_top_bar.dart';
import '../../shared/widgets/container_placeholder.dart';

class FriendsMadeScreen extends ConsumerStatefulWidget {
  final String? targetUserId;
  final String? targetUsername;

  const FriendsMadeScreen({
    super.key,
    this.targetUserId,
    this.targetUsername,
  });

  @override
  ConsumerState<FriendsMadeScreen> createState() => _FriendsMadeScreenState();
}

class _FriendsMadeScreenState extends ConsumerState<FriendsMadeScreen> {
  void _showUnfriendOptions(BuildContext context, String friendUid, String displayName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF191B1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.redAccent),
              title: Text(
                'Unfriend $displayName',
                style: const TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(context);
                ref.read(connectionRepositoryProvider).removeConnection(friendUid);
                ref.invalidate(recommendedFriendsProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendRow(Map<String, dynamic> friend, {required bool isMutual, required bool isCurrentUserList}) {
    final friendUid = friend['uid'] as String;
    final profileAsync = ref.watch(userProfileStreamProvider(friendUid));

    return GestureDetector(
      onTap: () {
        ref.invalidate(recommendedFriendsProvider);
        context.push('/profile/$friendUid');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Row(
          children: [
            profileAsync.when(
              data: (profile) {
                final avatarUrl = profile?['profile_image_url'] ?? profile?['avatarUrl'] ?? profile?['avatar_url'] as String?;
                return buildAvatarImage(source: avatarUrl, radius: 24);
              },
              loading: () => const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFF1A1D24),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white24),
                  ),
                ),
              ),
              error: (err, stack) => const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFF1A1D24),
                child: Icon(Icons.person, color: Colors.white24, size: 24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  profileAsync.when(
                    data: (profile) => Text(
                      profile?['name'] as String? ?? profile?['username'] as String? ?? 'Bloom User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    loading: () => const ContainerPlaceholder(width: 80, height: 14),
                    error: (err, stack) => const Text(
                      'User',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  profileAsync.when(
                    data: (profile) {
                      final username = profile?['username'] as String?;
                      return Text(
                        username != null && username.isNotEmpty
                            ? '@$username'
                            : 'bloom member',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                    loading: () => const ContainerPlaceholder(width: 120, height: 12),
                    error: (err, stack) => Text(
                      'bloom member',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isMutual) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0086D8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Mutual',
                  style: TextStyle(
                    color: Color(0xFF0086D8),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (isCurrentUserList) ...[
              GestureDetector(
                onTap: () {
                  final profile = profileAsync.value;
                  final name = profile?['name'] as String? ?? profile?['username'] as String? ?? 'this user';
                  _showUnfriendOptions(context, friendUid, name);
                },
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.more_vert,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 20,
                  ),
                ),
              ),
            ] else ...[
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.3),
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0E12),
      child: Stack(
        children: [
          // Atmospheric Gradient Background
          const GradientTopBar(
            height: 100,
            showDarkOverlay: false,
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text(
                'Friends Made',
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
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: widget.targetUserId != null ? _buildTargetFriendsBody() : _buildCurrentUserFriendsBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetFriendsBody() {
    final targetFriendsAsync = ref.watch(userFriendsProvider(widget.targetUserId!));
    final currentFriendsAsync = ref.watch(friendsMadeProvider);

    return targetFriendsAsync.when(
      data: (targetFriends) {
        return currentFriendsAsync.when(
          data: (currentFriends) {
            final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
            
            // Filter out target user being friends with the current user themselves
            final filteredTargetFriends = targetFriends.where((f) => f['uid'] != currentUid).toList();

            if (filteredTargetFriends.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      color: Colors.white24,
                      size: 64,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No friends yet.',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            final currentUserFriendUids = currentFriends.map((f) => f['uid'] as String).toSet();

            // Separate into mutual and other
            final mutualFriends = <Map<String, dynamic>>[];
            final otherFriends = <Map<String, dynamic>>[];

            for (final friend in filteredTargetFriends) {
               final friendUid = friend['uid'] as String;
               if (currentUserFriendUids.contains(friendUid)) {
                 mutualFriends.add(friend);
               } else {
                 otherFriends.add(friend);
               }
            }

            final children = <Widget>[];

            if (mutualFriends.isNotEmpty) {
              children.add(
                const Padding(
                  padding: EdgeInsets.only(top: 8.0, bottom: 12.0),
                  child: Text(
                    'MUTUAL FRIENDS',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              );
              for (int i = 0; i < mutualFriends.length; i++) {
                children.add(_buildFriendRow(mutualFriends[i], isMutual: true, isCurrentUserList: false));
                if (i < mutualFriends.length - 1) {
                  children.add(const SizedBox(height: 12));
                }
              }
              if (otherFriends.isNotEmpty) {
                children.add(const SizedBox(height: 24));
              }
            }

            if (otherFriends.isNotEmpty) {
              if (mutualFriends.isNotEmpty) {
                children.add(
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      'OTHER FRIENDS',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                );
              }
              for (int i = 0; i < otherFriends.length; i++) {
                children.add(_buildFriendRow(otherFriends[i], isMutual: false, isCurrentUserList: false));
                if (i < otherFriends.length - 1) {
                  children.add(const SizedBox(height: 12));
                }
              }
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: children,
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0086D8)),
            ),
          ),
          error: (err, stack) => Center(
            child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent)),
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0086D8)),
        ),
      ),
      error: (err, stack) => Center(
        child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent)),
      ),
    );
  }

  Widget _buildCurrentUserFriendsBody() {
    final friendsAsync = ref.watch(friendsMadeProvider);

    return friendsAsync.when(
      data: (friends) {
        if (friends.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline_rounded,
                  color: Colors.white24,
                  size: 64,
                ),
                SizedBox(height: 16),
                Text(
                  'No friends yet.',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: friends.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildFriendRow(friends[index], isMutual: false, isCurrentUserList: true);
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0086D8)),
        ),
      ),
      error: (err, stack) => Center(
        child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent)),
      ),
    );
  }
}
