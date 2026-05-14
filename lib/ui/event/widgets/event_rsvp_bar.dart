import 'dart:ui' as ui;
import 'package:bloom/domain/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/event/event_providers.dart';
import '../../../data/event/event_repository.dart';
import '../../../domain/auth/auth_providers.dart';

class EventRsvpBar extends ConsumerWidget {
  final String eventId;

  const EventRsvpBar({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventStreamProvider(eventId));
    final rsvpStatusAsync = ref.watch(userEventRsvpProvider(eventId));
    final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;

    return eventAsync.when(
      data: (event) {
        if (event == null) return const SizedBox.shrink();
        return rsvpStatusAsync.when(
          data: (status) => _buildBar(context, ref, userId, status, event),
          loading: () => _buildLoadingBar(),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
      loading: () => _buildLoadingBar(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildBar(
    BuildContext context,
    WidgetRef ref,
    String? userId,
    String? currentStatus,
    Event event,
  ) {
    final bool isFull = event.isFull;
    final bool showWaitlist = event.shouldShowWaitlist;
    final bool isAlreadyGoing = currentStatus == 'going';
    final bool isAlreadyWaitlisted = currentStatus == 'waitlisted';
    final requireApproval = event.audience.requireApproval;
    final allowMaybe = event.audience.allowMaybe;

    return ClipRRect(
      borderRadius: BorderRadius.circular(requireApproval ? 25 : 32.5),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: requireApproval ? 50 : 65,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(requireApproval ? 25 : 32.5),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: requireApproval
              ? GestureDetector(
                  onTap: (isFull && !showWaitlist && !isAlreadyGoing && currentStatus != 'requested') 
                      ? null 
                      : () => _handleRsvp(ref, userId, 'requested'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        currentStatus == 'requested'
                            ? Icons.check_circle
                            : (isFull && !showWaitlist && !isAlreadyGoing) 
                                ? Icons.block 
                                : Icons.add_circle_outline,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        currentStatus == 'requested'
                            ? 'Requested'
                            : (isFull && !isAlreadyGoing)
                                ? (showWaitlist ? 'Join Waitlist' : 'Event Full')
                                : 'Get on the list',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    if (isAlreadyGoing)
                      _RsvpButton(
                        label: 'Going',
                        icon: Icons.check_circle,
                        isSelected: true,
                        onPressed: () => _handleRsvp(ref, userId, 'going'),
                      )
                    else if (isAlreadyWaitlisted)
                      _RsvpButton(
                        label: 'Waitlisted',
                        icon: Icons.access_time_filled_rounded,
                        isSelected: true,
                        onPressed: () => _handleRsvp(ref, userId, 'waitlisted'),
                      )
                    else if (isFull)
                      _RsvpButton(
                        label: showWaitlist ? 'Waitlist' : 'Event Full',
                        icon: showWaitlist ? Icons.access_time_rounded : Icons.block,
                        isSelected: false,
                        isDisabled: !showWaitlist,
                        onPressed: showWaitlist 
                            ? () => _handleRsvp(ref, userId, 'waitlisted')
                            : () {},
                      )
                    else
                      _RsvpButton(
                        label: 'Going',
                        icon: currentStatus == 'going'
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        isSelected: currentStatus == 'going',
                        onPressed: () => _handleRsvp(ref, userId, 'going'),
                      ),
                    
                    if (allowMaybe && (!isFull || isAlreadyGoing || isAlreadyWaitlisted)) ...[
                      _buildRSVPDivider(),
                      _RsvpButton(
                        label: 'Maybe',
                        icon: currentStatus == 'maybe'
                            ? Icons.help
                            : Icons.help_outline,
                        isSelected: currentStatus == 'maybe',
                        onPressed: () => _handleRsvp(ref, userId, 'maybe'),
                      ),
                    ],
                    _buildRSVPDivider(),
                    _RsvpButton(
                      label: 'Decline',
                      icon: currentStatus == 'declined'
                          ? Icons.highlight_off_rounded
                          : Icons.highlight_off,
                      isSelected: currentStatus == 'declined',
                      onPressed: () => _handleRsvp(ref, userId, 'declined'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildRSVPDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildLoadingBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      ),
    );
  }

  Future<void> _handleRsvp(WidgetRef ref, String? userId, String status) async {
    if (userId == null) return;
    await ref.read(eventRepositoryProvider).updateRSVP(eventId, userId, status);
  }
}

class _RsvpButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onPressed;

  const _RsvpButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.isDisabled = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: isDisabled ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: isDisabled 
                    ? Colors.white.withValues(alpha: 0.2)
                    : isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDisabled 
                      ? Colors.white.withValues(alpha: 0.2)
                      : isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
