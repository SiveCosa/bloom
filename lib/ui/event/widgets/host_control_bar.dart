import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/domain/event/event.dart';
import 'package:bloom/domain/event/event_providers.dart';

class HostControlBar extends ConsumerWidget {
  final Event event;
  final Function(String?) onGoingPressed;
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = event.visuals.auroraColors.map((c) => _parseHexColor(c)).toList();
    
    List<Color> gradientColors;
    if (colors.length >= 2) {
      gradientColors = [colors[0], colors[1]];
    } else if (colors.length == 1) {
      gradientColors = [colors[0], colors[0].withValues(alpha: 0.8)];
    } else {
      gradientColors = [const Color(0xFF6366f1), const Color(0xFFa855f7)];
    }

    final guestsAsync = ref.watch(eventGuestsProvider(event.id));
    final guests = guestsAsync.value ?? [];
    
    final goingCount = guests.isEmpty 
        ? event.liveCounts.going 
        : guests.where((g) => g['status'] == 'going' || g['rsvp_status'] == 'going').length;
        
    final requestedCount = guests.where((g) => g['status'] == 'requested' || g['rsvp_status'] == 'requested').length;

    return Container(
      height: 75,
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

          Expanded(
            child: GestureDetector(
              onTap: () {
                final isRequestsActive = event.audience.requireApproval && requestedCount > 0;
                onGoingPressed(isRequestsActive ? 'Requests' : 'Going');
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(34),
                ),
                child: (event.audience.requireApproval && requestedCount > 0)
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedCounterText(
                            value: requestedCount,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                          const Text(
                            'Requests',
                            key: ValueKey('Requests'),
                            style: TextStyle(
                              color: Color(0xFF4B5563),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedCounterText(
                            value: goingCount,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                          const Text(
                            'Going',
                            key: ValueKey('Going'),
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
            Icon(icon, color: Colors.white, size: 25),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedCounterText extends StatelessWidget {
  final int value;
  final TextStyle style;

  const AnimatedCounterText({
    super.key,
    required this.value,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final isEntering = (child.key as ValueKey<int>?)?.value == value;
        return SlideTransition(
          position: Tween<Offset>(
            begin: isEntering ? const Offset(0.0, 0.6) : const Offset(0.0, -0.6),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: Text(
        '$value',
        key: ValueKey<int>(value),
        style: style,
      ),
    );
  }
}
