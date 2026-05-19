import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/event/create_event_state.dart';
import '../../../domain/event/event_visibility.dart';
import '../../shared/widgets/bloom_modal_shell.dart';
import '../../shared/widgets/bloom_selection_tile.dart';

class VisibilitySelectionModal extends ConsumerWidget {
  const VisibilitySelectionModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedVisibility = ref.watch(createEventProvider).audience.visibility;
    final menuOrder = [
      EventVisibility.public,
      EventVisibility.private,
      EventVisibility.friendsOnly,
      EventVisibility.friendsOfFriends,
      EventVisibility.maleOnly,
      EventVisibility.femaleOnly,
    ];

    return BloomModalShell(
      title: 'Visibility',
      headerBottomSpacing: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              children: menuOrder.map((visibility) {
                final isSelected = selectedVisibility == visibility;
                return BloomSelectionTile(
                  leading: visibility.filledIcon,
                  title: visibility.title,
                  subtitle: visibility.subtitle,
                  isSelected: isSelected,
                  onTap: () {
                    ref
                        .read(createEventProvider.notifier)
                        .updateVisibility(visibility);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 40), // Bottom padding
          ],
        ),
      ),
    );
  }
}
