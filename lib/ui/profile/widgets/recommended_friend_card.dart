import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/media/image_loader_helper.dart';
import '../../../domain/friendship/friendship_providers.dart';
import '../../../domain/friendship/friendship_models.dart';
import '../../../data/connection_repository.dart';

class RecommendedFriendCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onDismiss;

  const RecommendedFriendCard({
    super.key,
    required this.user,
    required this.onDismiss,
  });

  @override
  ConsumerState<RecommendedFriendCard> createState() => _RecommendedFriendCardState();
}

class _RecommendedFriendCardState extends ConsumerState<RecommendedFriendCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _widthAnimation;
  late Animation<double> _opacityAnimation;
  
  bool _isDismissing = false;
  bool? _localRequestedOverride;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _widthAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_isDismissing) return;
    setState(() {
      _isDismissing = true;
    });
    _controller.forward().then((_) {
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.user['uid'] ?? widget.user['id'] ?? '';
    final username = widget.user['username'] ?? 'User';
    final imageUrl = widget.user['profile_image_url']?.toString() ?? widget.user['avatar_url']?.toString();
    final defaultContext = widget.user['known_from'] ?? 'Same institution';

    // Watch real-time connection state
    final connectionStateAsync = ref.watch(connectionStateProvider(uid));
    final isRequested = _localRequestedOverride ?? (connectionStateAsync.value == FriendshipState.pending);

    // Watch dynamic affinity social context
    final affinityAsync = ref.watch(recommendedFriendAffinityProvider(uid));
    final contextText = affinityAsync.value?.isNotEmpty == true 
        ? affinityAsync.value! 
        : defaultContext;

    return SizeTransition(
      axis: Axis.horizontal,
      sizeFactor: _widthAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: ClipRect(
          child: Stack(
            children: [
              // Main Card Body
              GestureDetector(
                onTap: () {
                  if (uid.isNotEmpty) {
                    ref.invalidate(recommendedFriendsProvider);
                    context.push('/profile/$uid');
                  }
                },
                child: Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25282D),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Column(
                      children: [
                        // Avatar (Top)
                        buildAvatarImage(
                          source: imageUrl,
                          radius: 35,
                        ),
                        const SizedBox(height: 8),
                        
                        // Username
                        Text(
                          username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        // Dynamic Context Text (Center)
                        Expanded(
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                contextText,
                                key: ValueKey<String>(contextText),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        
                        // Action Button (Bottom)
                        SizedBox(
                          width: double.infinity,
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (uid.isEmpty) return;
                              final repo = ref.read(connectionRepositoryProvider);

                              if (isRequested) {
                                // Toggle Off: Cancel/Remove request
                                setState(() {
                                  _localRequestedOverride = false;
                                });
                                try {
                                  await repo.removeConnection(uid);
                                } catch (e) {
                                  setState(() {
                                    _localRequestedOverride = null;
                                  });
                                }
                              } else {
                                // Toggle On: Send request
                                setState(() {
                                  _localRequestedOverride = true;
                                });
                                try {
                                  await repo.sendRequest(uid);
                                } catch (e) {
                                  setState(() {
                                    _localRequestedOverride = null;
                                  });
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isRequested ? const Color(0xFF3A3F45) : const Color(0xFF0086D8),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              shape: const StadiumBorder(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isRequested) ...[
                                  const Icon(Icons.check, size: 14, color: Colors.white),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  isRequested ? 'Requested' : 'Add Friend',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Translucent Close "X" Action (Top-Right)
              Positioned(
                top: 6,
                right: 18, // Account for the 12px margin on the card
                child: GestureDetector(
                  onTap: _dismiss,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
