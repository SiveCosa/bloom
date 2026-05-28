import 'package:flutter/material.dart';
import '../../../core/media/image_loader_helper.dart';

class HostInviteSection extends StatelessWidget {
  final Map<String, dynamic>? userProfile;
  final List<Map<String, dynamic>> coHosts;
  final VoidCallback onAddCoHost;
  final bool showInviteFriends;
  final bool isFormMode;

  const HostInviteSection({
    super.key,
    this.userProfile,
    this.coHosts = const [],
    required this.onAddCoHost,
    this.showInviteFriends = true,
    this.isFormMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isFormMode) {
      // Form Mode: Just show the hosted by card with form styling
      return _HostedByCardPreview(
        userProfile: userProfile, 
        coHosts: coHosts,
        onAddCoHost: onAddCoHost,
        isFormMode: true,
      );
    }

    if (!showInviteFriends) {
      return _HostedByCardPreview(
        userProfile: userProfile, 
        coHosts: coHosts,
        onAddCoHost: onAddCoHost,
        isFormMode: false,
      );
    }

    // Preview Layout: Stacked full-width cards
    return Column(
      children: [
        _InviteFriendsCardPreview(),
        const SizedBox(height: 16),
        _HostedByCardPreview(
          userProfile: userProfile, 
          coHosts: coHosts,
          onAddCoHost: onAddCoHost,
          isFormMode: false,
        ),
      ],
    );
  }
}

class _HostedByCardPreview extends StatelessWidget {
  final Map<String, dynamic>? userProfile;
  final List<Map<String, dynamic>> coHosts;
  final VoidCallback onAddCoHost;
  final bool isFormMode;

  const _HostedByCardPreview({
    this.userProfile, 
    this.coHosts = const [],
    required this.onAddCoHost,
    this.isFormMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return _PreviewBaseCard(
      title: 'Hosted by',
      isFormMode: isFormMode,
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
            if (isFormMode) ...[
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: onAddCoHost,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Co-Host',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
  final bool isFormMode;

  const _PreviewBaseCard({
    required this.title, 
    required this.child,
    this.isFormMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isFormMode ? 0.15 : 0.05),
        borderRadius: BorderRadius.circular(isFormMode ? 15 : 20),
        border: Border.all(color: Colors.white.withValues(alpha: isFormMode ? 0.15 : 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
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
