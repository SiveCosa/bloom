import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/event/create_event_state.dart';
import 'bloom_toggle.dart';
import '../../../domain/event/event_visibility.dart';
import '../../shared/widgets/bloom_modal_shell.dart';

class AudienceModal extends ConsumerWidget {
  final String title;
  const AudienceModal({super.key, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(createEventProvider);
    final notifier = ref.read(createEventProvider.notifier);

    return BloomModalShell(
      title: title,
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildOptionSection(
                  title: 'Visibility',
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: Row(
                      children: EventVisibility.values.map((v) {
                        final isSelected = state.audience.visibility == v;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(v.title),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) notifier.updateVisibility(v);
                            },
                            selectedColor: Colors.white,
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontSize: 12,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildOptionSection(
                  title: 'Available Spots',
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Unlimited', style: TextStyle(color: Colors.white70)),
                          BloomToggle(
                            value: state.audience.capacity == null,
                            onChanged: (val) {
                              notifier.updateSpots(val ? null : 50);
                            },
                          ),
                        ],
                      ),
                      if (state.audience.capacity != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Limit:', style: TextStyle(color: Colors.white)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Slider(
                                value: state.audience.capacity!.toDouble(),
                                min: 1,
                                max: 500,
                                activeColor: Colors.white,
                                inactiveColor: Colors.white12,
                                onChanged: (val) => notifier.updateSpots(val.toInt()),
                              ),
                            ),
                            Text('${state.audience.capacity}', style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildOptionSection(
                  title: 'Plus Ones',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Allow guests to bring plus ones', style: TextStyle(color: Colors.white70)),
                      BloomToggle(
                        value: state.audience.maxPlusOnes > 0,
                        onChanged: (val) => notifier.setMaxPlusOnes(val ? 1 : 0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C8EEF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}
