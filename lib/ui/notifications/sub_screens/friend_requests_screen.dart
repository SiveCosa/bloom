import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/media/image_loader_helper.dart';
import '../../../domain/friendship/friendship_providers.dart';
import '../../../domain/auth/auth_providers.dart';
import '../../../data/connection_repository.dart';
import '../../shared/widgets/gradient_top_bar.dart';

class FriendRequestsScreen extends ConsumerStatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  ConsumerState<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends ConsumerState<FriendRequestsScreen> {
  String _getElapsedTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final difference = DateTime.now().difference(dateTime);
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Widget _buildPendingRequestsTile(BuildContext context) {
    final outgoingCountAsync = ref.watch(outgoingRequestsCountProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/notifications/pending-requests'),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.transparent, // Clear background
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFFFFB965), // Custom amber/orange circle
                child: Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pending requests',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    outgoingCountAsync.when(
                      data: (outgoingCount) {
                        final hasRequests = outgoingCount > 0;
                        return Text(
                          hasRequests
                              ? '$outgoingCount Request${outgoingCount > 1 ? 's' : ''} Pending'
                              : 'No Pending Requests Sent',
                          style: TextStyle(
                            color: hasRequests
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.38),
                            fontWeight: hasRequests
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
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.3),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(incomingRequestsProvider);

    return Container(
      color: const Color(0xFF0B0E12),
      child: Stack(
        children: [
          // Atmospheric Gradient Background (Stays at original height)
          const GradientTopBar(
            height: 100,
            showDarkOverlay: false,
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text(
                'Friend Requests',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: Column(
              children: [
                // Pending requests link at the top
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _buildPendingRequestsTile(context),
                ),
                // Section header
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'INCOMING REQUESTS',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                // Incoming list
                Expanded(
                  child: requestsAsync.when(
                    data: (requests) {
                      if (requests.isEmpty) {
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
                                'No pending friend requests',
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
                        itemCount: requests.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final request = requests[index];
                          final requesterUid = request['uid'] as String;
                          final timestamp = request['timestamp'];
                          DateTime? requestedAt;
                          if (timestamp is Timestamp) {
                            requestedAt = timestamp.toDate();
                          } else if (timestamp is int) {
                            requestedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
                          }

                          final profileAsync = ref.watch(userProfileStreamProvider(requesterUid));

                          return Container(
                            height: 80,
                            decoration: const BoxDecoration(
                              color: Colors.transparent,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => context.push('/profile/$requesterUid'),
                              child: Row(
                                children: [
                                  // Avatar image loading or error states handled cleanly
                                  profileAsync.when(
                                    data: (profile) {
                                      final avatarUrl = profile?['profile_image_url'] ?? profile?['avatarUrl'] ?? profile?['avatar_url'] as String?;
                                      return buildAvatarImage(source: avatarUrl, radius: 25);
                                    },
                                    loading: () => const CircleAvatar(
                                      radius: 25,
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
                                      radius: 25,
                                      backgroundColor: Color(0xFF1A1D24),
                                      child: Icon(Icons.person, color: Colors.white24, size: 25),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Username and timestamp
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
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
                                            final elapsed = _getElapsedTime(requestedAt);
                                            return Row(
                                              children: [
                                                if (username != null && username.isNotEmpty) ...[
                                                  Text(
                                                    '@$username',
                                                    style: TextStyle(
                                                      color: Colors.white.withValues(alpha: 0.5),
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  if (elapsed.isNotEmpty) ...[
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '•',
                                                      style: TextStyle(
                                                        color: Colors.white.withValues(alpha: 0.3),
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                  ],
                                                ],
                                                if (elapsed.isNotEmpty)
                                                  Text(
                                                    elapsed,
                                                    style: TextStyle(
                                                      color: Colors.white.withValues(alpha: 0.35),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                          loading: () => const ContainerPlaceholder(width: 120, height: 12),
                                          error: (err, stack) {
                                            final elapsed = _getElapsedTime(requestedAt);
                                            return Text(
                                              elapsed,
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.35),
                                                fontSize: 12,
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                                const SizedBox(width: 8),
                                // Accept and Decline Buttons
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Accept Button (Blue, elegant)
                                    ElevatedButton(
                                      onPressed: () async {
                                        try {
                                          await ref
                                              .read(connectionRepositoryProvider)
                                              .acceptRequest(requesterUid);
                                          ref.invalidate(recommendedFriendsProvider);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Friend request accepted!'),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Failed to accept request: $e'),
                                                backgroundColor: Colors.redAccent,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2D8CF0),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        minimumSize: const Size(0, 36),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        'Accept',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Decline Button (X, grey transparent circle)
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () async {
                                          try {
                                            await ref
                                                .read(connectionRepositoryProvider)
                                                .removeConnection(requesterUid);
                                            ref.invalidate(recommendedFriendsProvider);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Friend request declined.'),
                                                  duration: Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Failed to decline request: $e'),
                                                  backgroundColor: Colors.redAccent,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(18),
                                        child: Ink(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.06),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white70,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2D8CF0)),
                      ),
                    ),
                    error: (err, stack) => Center(
                      child: Text(
                        'Error: $err',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ContainerPlaceholder extends StatelessWidget {
  final double width;
  final double height;

  const ContainerPlaceholder({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

