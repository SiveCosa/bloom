import 'package:flutter/material.dart';
import 'package:bloom/domain/event/event.dart';

class HostControlBar extends StatelessWidget {
  final Event event;
  final VoidCallback onGoingPressed;
  final VoidCallback onInvitePressed;
  final VoidCallback onRemindersPressed;

  const HostControlBar({
    super.key,
    required this.event,
    required this.onGoingPressed,
    required this.onInvitePressed,
    required this.onRemindersPressed,
  });

  Color _parseHexColor(String hex) {
    String hexStr = hex.replaceFirst('#', '');
    if (hexStr.length == 6) hexStr = 'FF$hexStr';
    try {
      return Color(int.parse(hexStr, radix: 16));
    } catch (e) {
      return const Color(0xFFAD83FE);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = event.visuals.auroraColors.map((c) => _parseHexColor(c)).toList();
    
    List<Color> gradientColors;
    if (colors.length >= 2) {
      gradientColors = [colors[0], colors[1]];
    } else if (colors.length == 1) {
      gradientColors = [colors[0], colors[0].withValues(alpha: 0.8)];
    } else {
      gradientColors = [const Color(0xFF6366f1), const Color(0xFFa855f7)];
    }

    return Container(
      height: 75, // Updated height to 75dp
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(37.5),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Section: Invite
          Expanded(
            child: Center(
              child: _buildActionItem(
                icon: Icons.add,
                label: 'Invite',
                onTap: onInvitePressed,
                isCircleIcon: false,
              ),
            ),
          ),

          // Center Section: Going (Balanced Island)
          Expanded(
            child: GestureDetector(
              onTap: onGoingPressed,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(34),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${event.liveCounts.going}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const Text(
                      'Going',
                      style: TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right Section: Reminders
          Expanded(
            child: Center(
              child: _buildActionItem(
                icon: Icons.notifications_none_outlined,
                label: 'Reminders',
                onTap: onRemindersPressed,
                isCircleIcon: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isCircleIcon,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isCircleIcon)
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Icon(icon, color: Colors.white, size: 25),
            )
          else
            Icon(icon, color: Colors.white, size: 25), // Exact icon size (25sp)
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12, // Exact font size for labels (12pt)
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
