import 'package:flutter/material.dart';
import 'package:bloom/domain/event/event_providers.dart';
import 'package:bloom/ui/home/widgets/home_event_feed_screen.dart';

class InYourAreaScreen extends StatelessWidget {
  const InYourAreaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HomeEventFeedScreen(
      title: 'In Your Area',
      rawFeedProvider: eventsInAreaRawFeedProvider,
      eventsProvider: eventsInAreaEventsProvider,
      emptyState: const HomeFeedEmptyState(
        icon: Icons.location_on_outlined,
        title: 'No events nearby yet.',
        subtitle:
            'Enable location access and check back when events are happening around you.',
      ),
      loadErrorTitle: 'Failed to load events in your area',
    );
  }
}