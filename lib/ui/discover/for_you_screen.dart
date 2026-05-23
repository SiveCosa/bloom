import 'package:flutter/material.dart';
import 'package:bloom/domain/event/event_providers.dart';
import 'package:bloom/ui/home/widgets/home_event_feed_screen.dart';

class ForYouScreen extends StatelessWidget {
  const ForYouScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HomeEventFeedScreen(
      title: 'For You',
      rawFeedProvider: forYouRawFeedProvider,
      eventsProvider: forYouEventsProvider,
      emptyState: const HomeFeedEmptyState(
        icon: Icons.auto_awesome_outlined,
        title: 'No recommendations yet.',
        subtitle:
            'Add more interests to your profile and check back later!',
      ),
      loadErrorTitle: 'Failed to load your feed',
    );
  }
}
