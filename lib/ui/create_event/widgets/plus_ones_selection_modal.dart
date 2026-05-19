import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/event/create_event_state.dart';
import '../../shared/widgets/bloom_modal_shell.dart';
import '../../shared/widgets/bloom_selection_tile.dart';

class PlusOnesSelectionModal extends ConsumerWidget {
  const PlusOnesSelectionModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxPlusOnes = ref.watch(createEventProvider).audience.maxPlusOnes;
    final options = [0, 1, 2, 3, 4, 5];

    return BloomModalShell(
      title: 'Plus Ones',
      headerBottomSpacing: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              children: options.map((value) {
                final isSelected = maxPlusOnes == value;
                final title = value == 0 ? 'None' : '+$value';
                final subtitle = value == 0
                    ? 'Guests cannot bring plus ones'
                    : 'Guests can bring up to $value plus ones';

                return BloomSelectionTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        value == 0 ? '0' : '+$value',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  title: title,
                  subtitle: subtitle,
                  isSelected: isSelected,
                  onTap: () {
                    ref
                        .read(createEventProvider.notifier)
                        .setMaxPlusOnes(value);
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
