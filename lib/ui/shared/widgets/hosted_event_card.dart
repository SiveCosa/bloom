import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:readmore/readmore.dart';
import '../../../domain/event/event.dart';

class HostedEventCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;

  const HostedEventCard({
    super.key,
    required this.event,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, d MMM');
    final timeFormat = DateFormat('hpm');
    
    String timingText = 'TBD';
    if (event.timing.startDate != null) {
      timingText = dateFormat.format(event.timing.startDate!);
      if (!event.timing.startTimeTbd) {
        timingText += '  ·  ${timeFormat.format(event.timing.startDate!).toLowerCase()}';
      }
    }

    final trimmedDescription = event.description.trim().replaceAll(RegExp(r'\n\s*\n'), '\n');

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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Image + Title/Details
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
                              const Icon(Icons.image_not_supported, color: Colors.white24),
                          )
                        : const Icon(Icons.image, color: Colors.white24, size: 30),
                  ),
                ),
                const SizedBox(width: 12),
                // Title and basic info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
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
                      // Timing Row
                      Row(
                        children: [
                          const Icon(Icons.calendar_month_outlined, color: Colors.white, size: 18),
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
                      // Location Row
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              event.location?.displayName ?? 'TBD',
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
            
            // Description
            ReadMoreText(
              trimmedDescription,
              trimLines: 2,
              colorClickableText: const Color(0xFF4A90E2),
              trimMode: TrimMode.Line,
              trimCollapsedText: '...Read more',
              trimExpandedText: ' show less',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                height: 1.4,
              ),
              moreStyle: const TextStyle(
                fontSize: 13, 
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A90E2),
              ),
            ),
            
            const Spacer(),
            
            // Footer: Interested Button + Attendee Avatars
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Interested Button
                Row(
                  children: [
                    const Icon(Icons.star_border, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Interested',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                
                // Attendee Avatars (Mock for now)
                _buildAttendeeAvatars(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendeeAvatars() {
    // This would normally come from a separate attendees provider
    return SizedBox(
      height: 32,
      width: 70,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            child: _buildAvatarCircle(0),
          ),
          Positioned(
            right: 18,
            child: _buildAvatarCircle(1),
          ),
          Positioned(
            right: 36,
            child: _buildAvatarCircle(2),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCircle(int index) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF1A1D21), width: 2),
        color: Colors.grey[800],
      ),
      child: const ClipOval(
        child: Icon(Icons.person, size: 20, color: Colors.white24),
      ),
    );
  }
}
