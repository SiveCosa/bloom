import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/event/event.dart';
import '../../../domain/event/event_visibility.dart';
import '../../../domain/event/event_providers.dart';
import '../../../domain/auth/auth_providers.dart';

class GuestListCard extends ConsumerWidget {
  final Event event;
  final bool isHost;
  final int mutualFriendsCount;
  final VoidCallback onInvitePressed;

  const GuestListCard({
    super.key,
    required this.event,
    this.isHost = false,
    this.mutualFriendsCount = 0,
    required this.onInvitePressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Guestlist',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          _buildAvatarLayout(ref),
          const SizedBox(height: 24),
          _buildFooterText(ref),
        ],
      ),
    );
  }

  Widget _buildAvatarLayout(WidgetRef ref) {
    final bool canInvite = isHost ||
        (event.audience.visibility != EventVisibility.private &&
            event.audience.visibility != EventVisibility.friendsOnly);

    final guestsListAsync = ref.watch(eventGuestsProvider(event.id));
    final guestsData = guestsListAsync.value ?? [];
    
    final goingUserIds = guestsData
        .where((g) => g['status'] == 'going')
        .map((g) => g['uid'] as String)
        .toList();

    final List<String> guests = [];
    for (int i = 0; i < goingUserIds.length && i < 6; i++) {
      final profileAsync = ref.watch(userProfileStreamProvider(goingUserIds[i]));
      final profile = profileAsync.value;
      if (profile != null) {
        final avatar = profile['avatar_url'] ?? profile['profile_image_url'];
        if (avatar != null && avatar.toString().isNotEmpty) {
          guests.add(avatar.toString());
        }
      }
    }

    final int displayCount = guests.length;
    
    final List<_AvatarData> data = [];

    if (displayCount == 0) {
      data.add(_AvatarData(null, 50, isButton: canInvite));
    } else if (displayCount == 1) {
      data.add(_AvatarData(guests[0], 50));
      if (canInvite) data.add(_AvatarData(null, 50, isButton: true));
    } else if (displayCount == 2) {
      data.add(_AvatarData(guests[0], 45));
      if (canInvite) data.add(_AvatarData(null, 50, isButton: true));
      data.add(_AvatarData(guests[1], 45));
    } else if (displayCount == 3) {
      data.add(_AvatarData(guests[0], 50));
      data.add(_AvatarData(guests[1], 50));
      data.add(_AvatarData(guests[2], 50));
      if (canInvite) data.add(_AvatarData(null, 50, isButton: true));
    } else if (displayCount == 4) {
      data.add(_AvatarData(guests[0], 40));
      data.add(_AvatarData(guests[1], 45));
      if (canInvite) data.add(_AvatarData(null, 50, isButton: true));
      data.add(_AvatarData(guests[2], 45));
      data.add(_AvatarData(guests[3], 40));
    } else if (displayCount == 5) {
      data.add(_AvatarData(guests[0], 40));
      data.add(_AvatarData(guests[1], 40));
      data.add(_AvatarData(guests[2], 40));
      data.add(_AvatarData(guests[3], 40));
      data.add(_AvatarData(guests[4], 40));
      if (canInvite) data.add(_AvatarData(null, 50, isButton: true));
    } else {
      // 6 or more
      data.add(_AvatarData(guests[0], 35));
      data.add(_AvatarData(guests[1], 40));
      data.add(_AvatarData(guests[2], 45));
      if (canInvite) data.add(_AvatarData(null, 50, isButton: true));
      data.add(_AvatarData(guests[3], 45));
      data.add(_AvatarData(guests[4], 40));
      data.add(_AvatarData(guests[5], 35));
    }

    return _buildSpacedLayout(data);
  }

  Widget _buildSpacedLayout(List<_AvatarData> data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(data.length, (index) {
        final item = data[index];
        final bool isLast = index == data.length - 1;
        
        Widget avatar = _buildAvatarItem(item.url, item.size, isButton: item.isButton);
        
        if (!isLast) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              avatar,
              const SizedBox(width: 8),
            ],
          );
        }
        return avatar;
      }),
    );
  }

  Widget _buildAvatarItem(String? url, double size, {bool isButton = false}) {
    if (isButton) {
      return GestureDetector(
        onTap: onInvitePressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 24),
        ),
      );
    }
    
    final bool hasValidImage = url != null && url.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF1A1D24),
      ),
      child: ClipOval(
        child: hasValidImage
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFF1A1D24),
                  child: Icon(Icons.person, color: Colors.white24, size: size * 0.45),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: const Color(0xFF1A1D24),
                    child: Center(
                      child: SizedBox(
                        width: size * 0.4,
                        height: size * 0.4,
                        child: const CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
                        ),
                      ),
                    ),
                  );
                },
              )
            : Icon(Icons.person, color: Colors.white24, size: size * 0.45),
      ),
    );
  }

  Widget _buildFooterText(WidgetRef ref) {
    final int capacity = event.audience.capacity ?? 0;
    
    int totalSpotsTaken = event.liveCounts.going;
    final guestsAsync = ref.watch(eventGuestsProvider(event.id));
    if (guestsAsync.hasValue) {
      final guestsData = guestsAsync.value ?? [];
      int actualGoing = 0;
      for (final g in guestsData) {
        if (g['status'] == 'going' || g['rsvp_status'] == 'going') {
          actualGoing += 1 + ((g['plusOnesCount'] as num?)?.toInt() ?? 0);
        }
      }
      totalSpotsTaken = actualGoing;
    }
    
    final int spotsLeft = capacity - totalSpotsTaken;
    
    final parts = <String>[];
    
    parts.add('$totalSpotsTaken going');
    
    if (mutualFriendsCount > 0) {
      final String friendLabel = mutualFriendsCount == 1 ? 'friend' : 'friends';
      parts.add('$mutualFriendsCount $friendLabel going');
    }

    if (capacity > 0) {
      parts.add('${spotsLeft < 0 ? 0 : spotsLeft} spots left');
    }

    return Text(
      parts.join(' • '),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.8),
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _AvatarData {
  final String? url;
  final double size;
  final bool isButton;
  
  _AvatarData(this.url, this.size, {this.isButton = false});
}
