import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/media/image_loader_helper.dart';
import '../../../domain/friendship/friendship_providers.dart';
import '../../../domain/auth/auth_providers.dart';
import '../../../data/connection_repository.dart';
import '../../../domain/notification/notification_providers.dart';
import '../../../domain/notification/notification_model.dart';
import '../../shared/widgets/gradient_top_bar.dart';
import '../../shared/widgets/container_placeholder.dart';
import '../widgets/navigation_tile.dart';
import '../widgets/action_buttons.dart';

class FriendRequestsScreen extends ConsumerStatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  ConsumerState<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends ConsumerState<FriendRequestsScreen> {
  List<Map<String, dynamic>> _localRequests = [];
  bool _isInitialized = false;
  final Set<String> _acceptedUids = {};
  final Set<String> _declinedUids = {};
  final Set<String> _processingUids = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationControllerProvider)?.markAsReadByType([
        NotificationType.friendRequest,
      ]);
    });
  }

  String _getElapsedTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final difference = DateTime.now().difference(dateTime);
    if (difference.inSeconds < 60) {
      return 'now';
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

    return NavigationTile(
      onTap: () => context.push('/notifications/pending-requests'),
      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
      iconBackgroundColor: const Color(0xFFFFB965), // Custom amber/orange circle
      title: 'Pending requests',
      subtitle: outgoingCountAsync.when(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
      incomingRequestsProvider,
      (previous, next) {
        if (next.hasValue) {
          final streamRequests = next.value!;
          setState(() {
            final Map<String, Map<String, dynamic>> mergedMap = {};
            for (var req in streamRequests) {
              mergedMap[req['uid']] = req;
            }
            for (var localReq in _localRequests) {
              final uid = localReq['uid'] as String;
              if ((_acceptedUids.contains(uid) || _declinedUids.contains(uid)) && !mergedMap.containsKey(uid)) {
                mergedMap[uid] = localReq;
              }
            }
            _localRequests = mergedMap.values.toList();
            // Sort by timestamp descending
            _localRequests.sort((a, b) {
              final tsA = a['timestamp'];
              final tsB = b['timestamp'];
              if (tsA == null || tsB == null) return 0;
              final timeA = (tsA is Timestamp) ? tsA.toDate() : DateTime.fromMillisecondsSinceEpoch(tsA);
              final timeB = (tsB is Timestamp) ? tsB.toDate() : DateTime.fromMillisecondsSinceEpoch(tsB);
              return timeB.compareTo(timeA);
            });
            _isInitialized = true;
          });
        }
      },
    );

    final requestsAsync = ref.watch(incomingRequestsProvider);
    if (!_isInitialized && requestsAsync.hasValue) {
      _localRequests = List.from(requestsAsync.value!);
      _isInitialized = true;
    }

    return Container(
      color: const Color(0xFF0B0E12),
      child: Stack(
        children: [
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
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _buildPendingRequestsTile(context),
                ),
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
                  child: !_isInitialized && requestsAsync.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2D8CF0)),
                          ),
                        )
                      : _localRequests.isEmpty
                          ? const Center(
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
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              itemCount: _localRequests.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final request = _localRequests[index];
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
                                                    username.replaceAll('@', ''),
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
                                if (_acceptedUids.contains(requesterUid))
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Text(
                                      'Accepted',
                                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  )
                                else if (_declinedUids.contains(requesterUid))
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Text(
                                      'Declined',
                                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  )
                                else
                                  ActionButtons(
                                    primaryText: 'Accept',
                                    isLoading: _processingUids.contains(requesterUid),
                                    onPrimaryPressed: () async {
                                      setState(() {
                                        _processingUids.add(requesterUid);
                                      });
                                      try {
                                        await ref
                                            .read(connectionRepositoryProvider)
                                            .acceptRequest(requesterUid);
                                        setState(() {
                                          _acceptedUids.add(requesterUid);
                                          _processingUids.remove(requesterUid);
                                        });
                                        invalidateFriendshipCaches(
                                          ref,
                                          requesterUid,
                                        );
                                      } catch (e) {
                                        setState(() {
                                          _processingUids.remove(requesterUid);
                                        });
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
                                    onSecondaryPressed: () async {
                                      setState(() {
                                        _processingUids.add(requesterUid);
                                      });
                                      try {
                                        await ref
                                            .read(connectionRepositoryProvider)
                                            .removeConnection(requesterUid);
                                        setState(() {
                                          _declinedUids.add(requesterUid);
                                          _processingUids.remove(requesterUid);
                                        });
                                        ref.invalidate(recommendedFriendsProvider);
                                      } catch (e) {
                                        setState(() {
                                          _processingUids.remove(requesterUid);
                                        });
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
                                  ),
                              ],
                            ),
                          );
                        },
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

