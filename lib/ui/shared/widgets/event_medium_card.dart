import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/event/event.dart';
import '../../event/widgets/event_interested_button.dart';

class EventMediumCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;

  const EventMediumCard({super.key, required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, d MMM');
    final timeFormat = DateFormat('ha');

    String timingText = 'Date TBD';
    if (event.timing.startDate != null) {
      timingText = dateFormat.format(event.timing.startDate!);
      if (!event.timing.startTimeTbd) {
        timingText +=
            '  ·  ${timeFormat.format(event.timing.startDate!).toLowerCase()}';
      }
    }

    final trimmedDescription = event.description.trim().replaceAll(
      RegExp(r'\n\s*\n'),
      '\n',
    );
    final hasDescription = trimmedDescription.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 210, // Fixed height
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D21),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 85,
                    height: 85,
                    color: Colors.grey[800],
                    child: event.visuals.posterUrl != null
                        ? Image.network(
                            event.visuals.posterUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white24,
                                ),
                          )
                        : const Icon(
                            Icons.image,
                            color: Colors.white24,
                            size: 30,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title and basic info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title.isEmpty ? 'Untitled Event' : event.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timingText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (event.location?.displayName == null ||
                                      event.location!.displayName
                                          .trim()
                                          .isEmpty)
                                  ? 'Location TBD'
                                  : event.location!.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Spacer(),

            if (hasDescription) ...[
              Text(
                trimmedDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const Spacer(),
            ],

            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () {},
                behavior: HitTestBehavior.opaque,
                child: EventInterestedButton(
                  eventId: event.id,
                  iconSize: 22,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
