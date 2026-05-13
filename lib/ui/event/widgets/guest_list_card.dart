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
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Guest List',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildAvatarRow(),
              const SizedBox(height: 24),
              Text(
                mutualFriendsCount > 0
                    ? '$mutualFriendsCount friends will be joining'
                    : 'No friends have RSVP\'d yet. Invite them to join!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarRow() {
    final guests = event.previewGuests;
    final displayGuests = guests.take(5).toList();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Invite Button
        GestureDetector(
          onTap: onInvitePressed,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),
        ),
        if (displayGuests.isNotEmpty) const SizedBox(width: 12),
        // Overlapping avatars
        if (displayGuests.isNotEmpty)
          SizedBox(
            height: 50,
            width: 50 + (displayGuests.length - 1) * 30.0,
            child: Stack(
              children: List.generate(displayGuests.length, (index) {
                return Positioned(
                  left: index * 30.0,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0B0E12), width: 2),
                      image: DecorationImage(
                        image: NetworkImage(displayGuests[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
