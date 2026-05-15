import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/calendar/scheduled_event.dart';

class ScheduledEventCard extends StatelessWidget {
  final ScheduledEvent event;
  final bool isHost;
  final VoidCallback? onTap;

  const ScheduledEventCard({
    super.key,
    required this.event,
    required this.isHost,
    this.onTap,
  });


  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: event.isPast ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(left: 5, top: 5, bottom: 5, right: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            // Poster
            Hero(
              tag: 'event_poster_${event.id}',
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  image: event.posterUrl != null
                      ? DecorationImage(
                          image: NetworkImage(event.posterUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            const SizedBox(width: 10), // Preserved 10dp gap
            // Info Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Host Profile Picture with ripple
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            debugPrint('Navigate to host profile: ${event.hostId}');
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: CircleAvatar(
                            radius: 12,
                            backgroundImage: event.hostImageUrl != null
                                ? NetworkImage(event.hostImageUrl!)
                                : null,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            child: event.hostImageUrl == null
                                ? const Icon(Icons.person,
                                    size: 14, color: Colors.white70)
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Menu Button
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.more_vert,
                            size: 22,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                          offset: const Offset(0, 35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          itemBuilder: (context) {
                            if (isHost) {
                              return [
                                const PopupMenuItem(
                                    value: 'edit', child: Text('Edit')),
                                const PopupMenuItem(
                                    value: 'cancel', child: Text('Cancel')),
                                const PopupMenuItem(
                                    value: 'delete', child: Text('Delete')),
                                const PopupMenuItem(
                                    value: 'reminders',
                                    child: Text('Reminders')),
                              ];
                            }
                            return [
                              const PopupMenuItem(
                                  value: 'report', child: Text('Report')),
                            ];
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10), // Preserved 10dp gap
                  // Time - Dynamic logic preserved
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_month,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      _buildDynamicDateTime(event),
                    ],
                  ),
                  const SizedBox(height: 5), // Preserved 5dp gap
                  // Location
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        event.locationName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
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

  Widget _buildDynamicDateTime(ScheduledEvent event) {
    if (event.isOngoing) {
      return const Text(
        'LIVE NOW',
        style: TextStyle(
          color: Color(0xFF32D74B),
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      );
    }

    final startTime = event.startTime;
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

    return Text(
      '$datePart • $timePart',
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 13,
      ),
    );
  }
}
