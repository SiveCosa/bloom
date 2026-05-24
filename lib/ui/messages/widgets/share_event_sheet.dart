import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/chat/chat_share_providers.dart';
import '../../../domain/event/event.dart';

Future<void> showShareEventSheet(
  BuildContext context, {
  required void Function(Event event) onEventSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1A1F26),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Consumer(
            builder: (context, ref, _) {
              final eventsAsync = ref.watch(chatShareableEventsProvider);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      'Share an event',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: eventsAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF0086D8),
                        ),
                      ),
                      error: (e, _) => Center(
                        child: Text(
                          'Could not load events',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                        ),
                      ),
                      data: (events) {
                        if (events.isEmpty) {
                          return Center(
                            child: Text(
                              'No shareable events',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: events.length,
                          itemBuilder: (context, index) {
                            final event = events[index];
                            return _ShareEventTile(
                              event: event,
                              onTap: () {
                                Navigator.pop(context);
                                onEventSelected(event);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}

class _ShareEventTile extends StatelessWidget {
  const _ShareEventTile({required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date TBD';
    return DateFormat('EEE, MMM d • ha').format(date).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final posterUrl = event.visuals.posterUrl;

    return ListTile(
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: posterUrl != null && posterUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: posterUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => _placeholder(),
                )
              : _placeholder(),
        ),
      ),
      title: Text(
        event.title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _formatDate(event.timing.startDate),
        style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.white12,
      child: const Icon(Icons.event, color: Colors.white38, size: 24),
    );
  }
}
