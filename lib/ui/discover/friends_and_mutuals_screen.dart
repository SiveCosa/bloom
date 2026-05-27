import 'package:flutter/material.dart';
import 'package:bloom/domain/event/event_providers.dart';
import 'package:bloom/ui/home/widgets/home_event_feed_screen.dart';

class FriendsAndMutualsScreen extends StatelessWidget {
  const FriendsAndMutualsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HomeEventFeedScreen(
      title: 'Friends & Mutuals',
      rawFeedProvider: friendsAndMutualsRawFeedProvider,
      eventsProvider: friendsAndMutualsEventsProvider,
      emptyState: const HomeFeedEmptyState(
        icon: Icons.people_outline,
        title: 'No events found.',
        subtitle:
            'Your friends and mutuals aren\'t hosting any upcoming events right now.',
      ),
      loadErrorTitle: 'Failed to load feed',
    );
  }
}
