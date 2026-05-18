import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../domain/event/event.dart';

class GuestListCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
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
              _buildAvatarLayout(),
              const SizedBox(height: 24),
              _buildFooterText(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarLayout() {
    final guests = event.previewGuests;
    final int displayCount = guests.length.clamp(0, 6);
    
    // Algorithm based on requirements
    if (displayCount == 0) {
      return _buildAvatarItem(null, 50, isButton: true);
    }

    if (displayCount == 1) {
      // 1 Guest: Avatar 1 (50dp) | Invite Button (50dp)
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAvatarItem(guests[0], 50),
          const SizedBox(width: 12),
          _buildAvatarItem(null, 50, isButton: true),
        ],
      );
    }

    if (displayCount == 2) {
      // 2 Guests: Avatar 1 (40dp) | Invite Button (50dp) | Avatar 2 (40dp)
      return _buildOverlappingLayout([
        _AvatarData(guests[0], 40),
        _AvatarData(null, 50, isButton: true),
        _AvatarData(guests[1], 40),
      ]);
    }

    if (displayCount == 3) {
      // 3 Guests: A1, A2, A3 (50dp) | Button (50dp)
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAvatarItem(guests[0], 50),
          const SizedBox(width: -15),
          _buildAvatarItem(guests[1], 50),
          const SizedBox(width: -15),
          _buildAvatarItem(guests[2], 50),
          const SizedBox(width: 12),
          _buildAvatarItem(null, 50, isButton: true),
        ],
      );
    }

    if (displayCount == 4) {
      // 4 Guests: A4 (30dp), A2 (40dp) | Button (50dp) | A1 (40dp), A3 (30dp)
      return _buildOverlappingLayout([
        _AvatarData(guests[3], 30),
        _AvatarData(guests[1], 40),
        _AvatarData(null, 50, isButton: true),
        _AvatarData(guests[0], 40),
        _AvatarData(guests[2], 30),
      ]);
    }

    // Default / 7+ Guests (Max 6 Avatars visible)
    // A6 (20dp), A4 (30dp), A2 (40dp) | Button (50dp) | A1 (40dp), A3 (30dp), A5 (20dp)
    return _buildOverlappingLayout([
      if (displayCount >= 6) _AvatarData(guests[5], 20),
      if (displayCount >= 4) _AvatarData(guests[3], 30),
      _AvatarData(guests[1], 40),
      _AvatarData(null, 50, isButton: true),
      _AvatarData(guests[0], 40),
      if (displayCount >= 3) _AvatarData(guests[2], 30),
      if (displayCount >= 5) _AvatarData(guests[4], 20),
    ]);
  }

  Widget _buildOverlappingLayout(List<_AvatarData> data) {
    const double overlap = 15.0;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(data.length, (index) {
        final item = data[index];
        final bool isFirst = index == 0;
        
        return Padding(
          padding: EdgeInsets.only(left: isFirst ? 0 : -overlap),
          child: _buildAvatarItem(item.url, item.size, isButton: item.isButton),
        );
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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A1D24),
        border: Border.all(color: const Color(0xFF0B0E12), width: 2),
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

  Widget _buildFooterText() {
    final int capacity = event.audience.capacity ?? 0;
    final int going = event.liveCounts.going;
    final int spotsLeft = capacity - going;
    final int count = mutualFriendsCount > 0 ? mutualFriendsCount : going;
    final String friendLabel = mutualFriendsCount > 0 ? 'mutual friend' : 'friend';
    
    String text;
    
    if (capacity > 0) {
      if (spotsLeft <= 0) {
        text = 'Event is full • $going joining';
      } else if (spotsLeft <= 5) {
        text = 'Only $spotsLeft spots left! • $going joining';
      } else {
        text = '$going joining • $spotsLeft spots left';
      }
    } else {
      if (count == 0) {
        text = 'No one here yet? Invite them.';
      } else if (count == 1) {
        text = '1 $friendLabel will be joining';
      } else {
        text = '$count ${friendLabel}s will be joining';
      }
    }

    return Text(
      text,
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
