import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/event/create_event_state.dart';
import '../../../domain/event/event_visibility.dart';

class VisibilitySelectionModal extends ConsumerWidget {
  const VisibilitySelectionModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedVisibility = ref.watch(createEventProvider).visibility;
    final menuOrder = [
      EventVisibility.public,
      EventVisibility.private,
      EventVisibility.friendsOnly,
      EventVisibility.friendsOfFriends,
      EventVisibility.maleOnly,
      EventVisibility.femaleOnly,
    ];

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF191B1D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Visibility',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: menuOrder.map((visibility) {
                final isSelected = selectedVisibility == visibility;
                return _VisibilityOptionRow(
                  visibility: visibility,
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
          ),
          const SizedBox(height: 40), // Bottom padding
        ],
      ),
    );
  }
}

class _VisibilityOptionRow extends StatelessWidget {
  final EventVisibility visibility;
  final bool isSelected;
  final VoidCallback onTap;

  const _VisibilityOptionRow({
    required this.visibility,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Center(child: visibility.filledIcon),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visibility.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    visibility.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              )
            else
              const SizedBox(width: 28, height: 28),
          ],
        ),
      ),
    );
  }
}
