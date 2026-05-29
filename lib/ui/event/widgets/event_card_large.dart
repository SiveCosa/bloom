import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/core/routing/event_navigation.dart';
import 'package:bloom/domain/calendar/scheduled_event.dart';
import 'package:bloom/domain/event/create_event_state.dart';
import 'package:bloom/domain/auth/auth_providers.dart';
import 'package:bloom/domain/event/event_providers.dart';
import 'package:bloom/data/event/event_repository.dart';

class EventCardLarge extends ConsumerWidget {
  static const double hostBarHeight = 45;
  static const double posterSize = 250;

  /// Details block: padding (24) + title (~22) + rows + Interested control.
  static const double detailsSectionHeight = 154;

  /// ListView viewport — must fit host + poster + details (no vertical overflow).
  static const double carouselHeight =
      hostBarHeight + posterSize + detailsSectionHeight;

  final ScheduledEvent event;
  final VoidCallback? onOptionTap;
  final VoidCallback? onInterestedTap;

  const EventCardLarge({
    super.key,
    required this.event,
    this.onOptionTap,
    this.onInterestedTap,
  });

  List<Color> _parseAuroraColors(List<String> hexColors) {
    if (hexColors.isEmpty) return CreateEventState.defaultAuroraColors;
    return hexColors
        .map((hex) {
          try {
            final cleanHex = hex.replaceAll('#', '');
            if (cleanHex.length == 6) {
              return Color(int.parse('FF$cleanHex', radix: 16));
            } else if (cleanHex.length == 8) {
              return Color(int.parse(cleanHex, radix: 16));
            }
            return Colors.transparent;
          } catch (e) {
            return Colors.transparent;
          }
        })
        .where((c) => c != Colors.transparent)
        .toList();
  }

  String _formatDateTime(DateTime? startTime) {
    if (startTime == null) return 'Date TBD';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(startTime.year, startTime.month, startTime.day);

    String datePart;
    if (eventDate == today) {
      datePart = 'Today';
    } else if (eventDate == today.add(const Duration(days: 1))) {
      datePart = 'Tomorrow';
    } else {
      datePart = DateFormat('EEE, MMM d').format(startTime);
    }

    final timePart = DateFormat('ha').format(startTime).toLowerCase();
    return '$datePart • $timePart';
  }

  /// Discover (and other feeds) often embed host fields from the server; skip
  /// per-card Firestore listeners to avoid dozens of streams on one screen.
  bool get _useEmbeddedHostInfo => event.hostName.trim().isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String hostImageUrl;
    final String hostName;

    if (_useEmbeddedHostInfo) {
      hostImageUrl = event.hostImageUrl ?? '';
      hostName = event.hostName;
    } else {
      final hostProfileAsync = ref.watch(
        userProfileStreamProvider(event.hostId),
      );

      hostImageUrl = hostProfileAsync.when(
        data: (profile) =>
            profile?['profile_image_url']?.toString() ??
            profile?['avatar_url']?.toString() ??
            event.hostImageUrl ??
            '',
        loading: () => event.hostImageUrl ?? '',
        error: (err, st) => event.hostImageUrl ?? '',
      );

      hostName = hostProfileAsync.when(
        data: (profile) =>
            profile?['name']?.toString() ??
            profile?['username']?.toString() ??
            event.hostName,
        loading: () => event.hostName,
        error: (err, st) => event.hostName,
      );
    }

    final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final isCoHost =
        currentUserId != null && event.coHostIds.contains(currentUserId);
    // 1. Extract and process color palette
    final colors = _parseAuroraColors(event.auroraColors);
    final displayColors = colors.isNotEmpty
        ? colors
        : CreateEventState.defaultAuroraColors;
    final color1 = displayColors[0];
    final color2 = displayColors.length > 1
        ? displayColors[1]
        : displayColors[0];

    // 2. Opaque gradient for Host Bar, glassmorphic gradient for bottom Info Box
    final hostBarGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [color1, color2],
    );

    final infoGradient = LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [color1, color2],
    );

    // 3. Structural Container & Clip
    return GestureDetector(
      onTap: () => pushEventDetail(context, event.id),
      child: Container(
        width: 250,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Align(
          alignment: Alignment.topCenter,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              15,
            ), // Fit cleanly inside border
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 0,
              children: [
                // Host bar
                Container(
                  height: hostBarHeight,
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  decoration: BoxDecoration(gradient: hostBarGradient),
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: event.hostId.isNotEmpty
                                ? () => context.push('/profile/${event.hostId}')
                                : null,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundImage: hostImageUrl.isNotEmpty
                                        ? NetworkImage(hostImageUrl)
                                        : null,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.2,
                                    ),
                                    child: hostImageUrl.isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            size: 14,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      hostName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Square poster (250×250), flush below host bar
                SizedBox(
                  width: posterSize,
                  height: posterSize,
                  child: event.posterUrl != null
                      ? CachedNetworkImage(
                          imageUrl: event.posterUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.black.withValues(alpha: 0.2),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.white.withValues(alpha: 0.05),
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.white30,
                              size: 32,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.white.withValues(alpha: 0.05),
                          child: const Icon(
                            Icons.image,
                            color: Colors.white30,
                            size: 32,
                          ),
                        ),
                ),

                // Details container, flush below poster
                Container(
                  decoration: BoxDecoration(
                    gradient: infoGradient,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(15),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 12,
                      bottom: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_month,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _formatDateTime(event.startTime),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                event.locationName.trim().isEmpty
                                    ? 'Location TBD'
                                    : event.locationName,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (!isCoHost) ...[
                          const SizedBox(height: 8),
                          Center(child: _InterestedButton(eventId: event.id)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InterestedButton extends ConsumerStatefulWidget {
  final String eventId;

  const _InterestedButton({required this.eventId});

  @override
  ConsumerState<_InterestedButton> createState() => _InterestedButtonState();
}

class _InterestedButtonState extends ConsumerState<_InterestedButton> {
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      icon: Icon(buttonIcon, size: 20),
      label: Text(
        buttonLabel,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}
