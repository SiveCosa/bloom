import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'event_share_formatters.dart';

class EventInviteSnippet extends StatelessWidget {
  const EventInviteSnippet({
    super.key,
    required this.eventName,
    required this.subtitle,
    this.posterUrl,
    this.thumbnailSize = 50,
  });

  factory EventInviteSnippet.fromPayload(Map<String, dynamic> data) {
    return EventInviteSnippet(
      eventName: data['eventName']?.toString() ?? 'Event',
      subtitle: formatEventShareSubtitleFromPayload(data),
      posterUrl: data['posterUrl']?.toString(),
    );
  }

  final String eventName;
  final String subtitle;
  final String? posterUrl;
  final double thumbnailSize;

  @override
  Widget build(BuildContext context) {
    final url = posterUrl;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: thumbnailSize,
            height: thumbnailSize,
            child: url != null && url.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => _placeholder(),
                  )
                : _placeholder(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                eventName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.white12,
      child: const Icon(Icons.event, color: Colors.white38, size: 24),
    );
  }
}