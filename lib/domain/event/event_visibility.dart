import 'package:flutter/material.dart';

enum EventVisibility {
  public,
  friendsOfFriends,
  friendsOnly,
  maleOnly,
  femaleOnly,
  private,
}

extension EventVisibilityExtension on EventVisibility {
  String get title {
    switch (this) {
      case EventVisibility.public:
        return 'Public';
      case EventVisibility.friendsOfFriends:
        return 'Friends of Friends';
      case EventVisibility.friendsOnly:
        return 'Friends Only';
      case EventVisibility.maleOnly:
        return 'Male Only';
      case EventVisibility.femaleOnly:
        return 'Female Only';
      case EventVisibility.private:
        return 'Private';
    }
  }

  String get subtitle {
    switch (this) {
      case EventVisibility.public:
        return 'Events will be visible to all users';
      case EventVisibility.private:
        return 'Events will only be visible to invited users';
      case EventVisibility.friendsOnly:
        return 'Events will only be visible to your connections';
      case EventVisibility.friendsOfFriends:
        return 'Events will be to your connections and their friends';
      case EventVisibility.maleOnly:
        return 'Events will only be visible to male users';
      case EventVisibility.femaleOnly:
        return 'Events will only be visible to female users';
    }
  }

  Widget get filledIcon {
    switch (this) {
      case EventVisibility.public:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF8E2DE2), Color(0xFFF000B8)],
          ).createShader(bounds),
          child: const Icon(Icons.public, color: Colors.white, size: 28),
        );
      case EventVisibility.private:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF815BFF), Color(0xFF6231FF)],
          ).createShader(bounds),
          child: const Icon(Icons.lock, color: Colors.white, size: 28),
        );
      case EventVisibility.friendsOnly:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
          ).createShader(bounds),
          child: const Icon(Icons.favorite, color: Colors.white, size: 28),
        );
      case EventVisibility.friendsOfFriends:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
          ).createShader(bounds),
          child: Stack(
            children: [
              const Icon(Icons.favorite, color: Colors.white, size: 18),
              Transform.translate(
                offset: const Offset(10, 10),
                child: const Icon(Icons.favorite, color: Colors.white, size: 18),
              ),
            ],
          ),
        );
      case EventVisibility.maleOnly:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
          ).createShader(bounds),
          child: const Icon(Icons.celebration, color: Colors.white, size: 28),
        );
      case EventVisibility.femaleOnly:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFee9ca7), Color(0xFFffdde1)],
          ).createShader(bounds),
          child: const Icon(Icons.local_florist, color: Colors.white, size: 28),
        );
    }
  }

  IconData get outlinedIcon {
    switch (this) {
      case EventVisibility.public:
        return Icons.public_outlined;
      case EventVisibility.friendsOfFriends:
        return Icons.favorite_border_outlined;
      case EventVisibility.friendsOnly:
        return Icons.favorite_border_outlined;
      case EventVisibility.maleOnly:
        return Icons.celebration_outlined;
      case EventVisibility.femaleOnly:
        return Icons.local_florist_outlined;
      case EventVisibility.private:
        return Icons.lock_outline;
    }
  }
}
