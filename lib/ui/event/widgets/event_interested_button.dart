import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/auth/auth_providers.dart';
import '../../../domain/event/event_providers.dart';
import '../../../data/event/event_repository.dart';

class EventInterestedButton extends ConsumerStatefulWidget {
  final String eventId;
  final double iconSize;
  final EdgeInsetsGeometry padding;

  const EventInterestedButton({
    super.key,
    required this.eventId,
    this.iconSize = 20,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  });

  @override
  ConsumerState<EventInterestedButton> createState() =>
      _EventInterestedButtonState();
}

class _EventInterestedButtonState extends ConsumerState<EventInterestedButton> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(canRequestFocus: false);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rsvpStatus = ref.watch(userEventRsvpProvider(widget.eventId)).value;
    final isGoing = rsvpStatus == 'going';
    final isMaybe = rsvpStatus == 'maybe';
    final isNotGoing = rsvpStatus == 'declined';
    final isWaitlist = rsvpStatus == 'waitlisted';
    final isRequested = rsvpStatus == 'requested';
    final isInterested = rsvpStatus == 'interested';
    final hasActiveRsvp =
        isGoing || isMaybe || isNotGoing || isWaitlist || isRequested;

    final fullEvent = ref.watch(eventStreamProvider(widget.eventId)).value;
    final baseCount = fullEvent?.liveCounts.interested ?? 0;

    int displayCount = baseCount;
    final optMap = ref.watch(optimisticInterestedCountProvider);
    final optData = optMap[widget.eventId];
    if (optData != null && DateTime.now().isBefore(optData.expiresAt)) {
      displayCount = optData.count;
    }

    if (displayCount < 0) displayCount = 0;

    String buttonLabel;
    IconData buttonIcon;

    if (hasActiveRsvp) {
      if (isGoing) {
        buttonLabel = 'Going';
        buttonIcon = Icons.check_circle;
      } else if (isMaybe) {
        buttonLabel = 'Maybe';
        buttonIcon = Icons.help;
      } else if (isRequested) {
        buttonLabel = 'Requested';
        buttonIcon = Icons.pending;
      } else if (isWaitlist) {
        buttonLabel = 'Waitlisted';
        buttonIcon = Icons.hourglass_bottom;
      } else {
        buttonLabel = 'Not going';
        buttonIcon = Icons.cancel;
      }
    } else {
      buttonLabel = displayCount > 0
          ? '$displayCount Interested'
          : 'Interested';
      buttonIcon = isInterested ? Icons.star : Icons.star_border;
    }

    return TextButton.icon(
      focusNode: _focusNode,
      onPressed: hasActiveRsvp
          ? null
          : () {
              final newInterested = !isInterested;
              final newCount = newInterested
                  ? displayCount + 1
                  : displayCount - 1;
              ref
                  .read(optimisticInterestedCountProvider.notifier)
                  .updateCount(
                    widget.eventId,
                    OptimisticCount(
                      newCount < 0 ? 0 : newCount,
                      DateTime.now().add(const Duration(seconds: 5)),
                    ),
                  );

              final userId = ref.read(firebaseAuthProvider).currentUser?.uid;
              if (userId != null) {
                if (newInterested) {
                  ref
                      .read(eventRepositoryProvider)
                      .updateRSVP(widget.eventId, userId, 'interested');
                } else {
                  ref
                      .read(eventRepositoryProvider)
                      .removeRSVP(widget.eventId, userId);
                }
              }
            },
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white.withValues(alpha: 0.9),
        backgroundColor: Colors.transparent,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: Size.zero,
        padding: widget.padding,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      icon: Icon(buttonIcon, size: widget.iconSize),
      label: Text(
        buttonLabel,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}
