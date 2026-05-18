import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/media/image_loader_helper.dart';
import '../../../domain/friendship/friendship_providers.dart';
import '../../../domain/auth/auth_providers.dart';
import '../../../data/connection_repository.dart';
import '../../shared/widgets/gradient_top_bar.dart';

class PendingRequestsScreen extends ConsumerStatefulWidget {
  const PendingRequestsScreen({super.key});

  @override
  ConsumerState<PendingRequestsScreen> createState() => _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends ConsumerState<PendingRequestsScreen> {
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

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(outgoingRequestsProvider);

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
                'Pending Requests',
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
            body: requestsAsync.when(
              data: (requests) {
                if (requests.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.hourglass_empty_rounded,
                          color: Colors.white24,
                          size: 64,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No pending sent requests',
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
                    final recipientUid = request['uid'] as String;
                    final timestamp = request['timestamp'];
                    DateTime? requestedAt;
                    if (timestamp is Timestamp) {
                      requestedAt = timestamp.toDate();
                    } else if (timestamp is int) {
                      requestedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
                    }

                    final profileAsync = ref.watch(userProfileStreamProvider(recipientUid));

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
                              onTap: () => context.push('/profile/$recipientUid'),
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
                                                Text(
                                                  requestedAt != null
                                                      ? _getElapsedTime(requestedAt)
                                                      : 'Just now',
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.35),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                          loading: () => const ContainerPlaceholder(width: 120, height: 12),
                                          error: (err, stack) => Text(
                                            requestedAt != null
                                                ? _getElapsedTime(requestedAt)
                                                : 'Just now',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.35),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Cancel Button (Red, elegant, matching the design spec)
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 25,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () async {
                              try {
                                await ref
                                    .read(connectionRepositoryProvider)
                                    .removeConnection(recipientUid);
                                ref.invalidate(recommendedFriendsProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Friend request cancelled.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to cancel request: $e'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB965)),
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
