import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/event/create_event_state.dart';
import 'bloom_toggle.dart';

class AudienceModal extends ConsumerWidget {
  const AudienceModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(createEventProvider);
    final notifier = ref.read(createEventProvider.notifier);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Audience Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildOptionSection(
                  title: 'Visibility',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['Public', 'Followers', 'Private'].map((v) {
                      final isSelected = state.visibility == v;
                      return ChoiceChip(
                        label: Text(v),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) notifier.updateVisibility(v);
                        },
                        selectedColor: Colors.white,
                        backgroundColor: Colors.white10,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                        ),
                      );
                    }).toList(),
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
                            value: state.availableSpots == null,
                            onChanged: (val) {
                              notifier.updateSpots(val ? null : 50);
                            },
                          ),
                        ],
                      ),
                      if (state.availableSpots != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Limit:', style: TextStyle(color: Colors.white)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Slider(
                                value: state.availableSpots!.toDouble(),
                                min: 1,
                                max: 500,
                                activeColor: Colors.white,
                                inactiveColor: Colors.white12,
                                onChanged: (val) => notifier.updateSpots(val.toInt()),
                              ),
                            ),
                            Text('${state.availableSpots}', style: const TextStyle(color: Colors.white)),
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
                        value: state.allowPlusOnes,
                        onChanged: (val) => notifier.setAllowPlusOnes(val),
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
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
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
