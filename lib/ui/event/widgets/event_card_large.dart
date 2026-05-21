import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/core/routing/event_navigation.dart';
import 'package:bloom/domain/calendar/scheduled_event.dart';
import 'package:bloom/domain/event/create_event_state.dart';
import 'package:bloom/domain/auth/auth_providers.dart';

class EventCardLarge extends ConsumerWidget {
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
    return hexColors.map((hex) {
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
    }).where((c) => c != Colors.transparent).toList();
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch real-time host profile info
    final hostProfileAsync = ref.watch(userProfileStreamProvider(event.hostId));

    final hostImageUrl = hostProfileAsync.when(
      data: (profile) => profile?['profile_image_url']?.toString() ??
          profile?['avatar_url']?.toString() ??
          event.hostImageUrl,
      loading: () => event.hostImageUrl,
      error: (err, st) => event.hostImageUrl,
    );

    final hostName = hostProfileAsync.when(
      data: (profile) => profile?['name']?.toString() ??
          profile?['username']?.toString() ??
          event.hostName,
      loading: () => event.hostName,
      error: (err, st) => event.hostName,
    );

    // 1. Extract and process color palette
    final colors = _parseAuroraColors(event.auroraColors);
    final displayColors = colors.isNotEmpty ? colors : CreateEventState.defaultAuroraColors;
    final color1 = displayColors[0];
    final color2 = displayColors.length > 1 ? displayColors[1] : displayColors[0];

    // 2. Opaque gradient for Host Bar, glassmorphic gradient for bottom Info Box
    final hostBarGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color1,
        color2,
      ],
    );

    final infoGradient = LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [
        color1,
        color2,
      ],
    );

    // 3. Structural Container & Clip
    return GestureDetector(
      onTap: () => pushEventDetail(context, event.id),
      child: Container(
        width: 250,
        height: 394,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15), // Fit cleanly inside border
          child: Column(
            children: [
            // 1. Top Item: Host Bar (Height 45, 100% opaque gradient)
            Container(
              height: 45,
              padding: const EdgeInsets.only(left: 12, right: 0),
              decoration: BoxDecoration(
                gradient: hostBarGradient,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: hostImageUrl != null
                        ? NetworkImage(hostImageUrl)
                        : null,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: hostImageUrl == null
                        ? const Icon(Icons.person, size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
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
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.more_vert,
                      size: 20,
                      color: Colors.white,
                    ),
                    onPressed: onOptionTap,
                  ),
                ],
              ),
            ),

            // 2. Remaining Area: Stack containing Poster Image (base) and Info Container (bottom)
            Expanded(
              child: Stack(
                children: [
                  // Poster Image (starts exactly below the Host Bar, shown at 100% opacity)
                  Positioned.fill(
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

                  // Bottom Item: Info Container (100% opaque gradient, zero bottom padding, rounded top corners)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 12,
                        bottom: 0,
                      ),
                      decoration: BoxDecoration(
                        gradient: infoGradient,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Event Title
                          Text(
                            event.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),

                          // Date Row
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_month,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _formatDateTime(event.startTime),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Location Row
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
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
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // "Interested" Button (Clear background text style)
                          Center(
                            child: SizedBox(
                              height: 36,
                              child: TextButton.icon(
                                onPressed: onInterestedTap,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                icon: const Icon(
                                  Icons.star_border,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Interested',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
