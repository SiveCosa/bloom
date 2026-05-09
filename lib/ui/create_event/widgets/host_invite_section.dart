import 'dart:ui';
import 'package:flutter/material.dart';
import 'event_section_card.dart';
import '../../../core/media/image_loader_helper.dart';

class HostInviteSection extends StatelessWidget {
  final Map<String, dynamic>? userProfile;
  final List<Map<String, dynamic>> coHosts;
  final VoidCallback onAddCoHost;
  final bool showInviteFriends;

  const HostInviteSection({
    super.key,
    this.userProfile,
    this.coHosts = const [],
    required this.onAddCoHost,
    this.showInviteFriends = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showInviteFriends) {
      return EventSectionCard(
        headerIcon: Icons.workspace_premium,
        title: 'Hosted by',
        body: Row(
          children: [
            _CreationHostAvatar(userProfile: userProfile),
            const SizedBox(width: 20),
            _CreationAddCohostButton(onTap: onAddCoHost),
          ],
        ),
      );
    }

    // Preview Layout: Stacked full-width cards
    return Column(
      children: [
        _InviteFriendsCardPreview(),
        const SizedBox(height: 16),
        _HostedByCardPreview(userProfile: userProfile, coHosts: coHosts),
      ],
    );
  }
}

class _HostedByCardPreview extends StatelessWidget {
  final Map<String, dynamic>? userProfile;
  final List<Map<String, dynamic>> coHosts;

  const _HostedByCardPreview({this.userProfile, this.coHosts = const []});

  @override
  Widget build(BuildContext context) {
    return _PreviewBaseCard(
      title: 'Hosted by',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AvatarWithLabel(
              imageUrl: userProfile?['profile_image_url'],
              label: userProfile?['username'] ?? 'username',
              isHost: true,
            ),
            ...coHosts.map(
              (coHost) => Padding(
                padding: const EdgeInsets.only(left: 20),
                child: _AvatarWithLabel(
                  imageUrl: coHost['profile_image_url'],
                  label: coHost['username'] ?? 'username',
                  isHost: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteFriendsCardPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _PreviewBaseCard(
      title: 'Invite Friends',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1A1D21),
                  title: const Text(
                    'Invite Friends',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    'Coming Soon',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'OK',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            },
            child: Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                color: Colors.white.withValues(alpha: 0.05),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'sent 0 invites',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewBaseCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _PreviewBaseCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarWithLabel extends StatelessWidget {
  final String? imageUrl;
  final String label;
  final bool isHost;

  const _AvatarWithLabel({
    this.imageUrl,
    required this.label,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAvatar(imageUrl: imageUrl, isHost: isHost),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _CreationHostAvatar extends StatelessWidget {
  final Map<String, dynamic>? userProfile;

  const _CreationHostAvatar({this.userProfile});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAvatar(imageUrl: userProfile?['profile_image_url'], isHost: true),
        const SizedBox(height: 8),
        Text(
          userProfile?['username'] ?? 'username',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CreationAddCohostButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreationAddCohostButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add Cohost',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildAvatar({String? imageUrl, required bool isHost}) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: buildAvatarImage(
          source: imageUrl,
          radius: 30,
        ),
      ),
      Positioned(
        right: -2,
        bottom: -2,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isHost ? Colors.white : Colors.black,
            shape: BoxShape.circle,
            border: Border.all(
              color: isHost
                  ? Colors.black
                  : Colors.white.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: Icon(
            Icons.workspace_premium,
            size: 14,
            color: isHost ? Colors.black : Colors.white,
          ),
        ),
      ),
    ],
  );
}
