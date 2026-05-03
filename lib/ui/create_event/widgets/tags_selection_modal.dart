import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/event/create_event_state.dart';

class TagsSelectionModal extends ConsumerStatefulWidget {
  const TagsSelectionModal({super.key});

  @override
  ConsumerState<TagsSelectionModal> createState() => _TagsSelectionModalState();
}

class _TagsSelectionModalState extends ConsumerState<TagsSelectionModal> {
  final List<String> _suggestedTags = [
    'Party', 'Networking', 'Music', 'Art', 'Food', 'Sport', 'Education', 'Tech', 'Wellness', 'Fashion'
  ];
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createEventProvider);
    final notifier = ref.read(createEventProvider.notifier);

    final filteredTags = _suggestedTags
        .where((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

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
            'Event Tags',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search or add tag...',
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Selected Tags
          if (state.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                children: state.tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    onDeleted: () {
                      final newTags = List<String>.from(state.tags)..remove(tag);
                      notifier.updateTags(newTags);
                    },
                    deleteIcon: const Icon(Icons.close, size: 14),
                    backgroundColor: Colors.white10,
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                  );
                }).toList(),
              ),
            ),
          const Divider(color: Colors.white12, height: 32),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: filteredTags.length,
              itemBuilder: (context, index) {
                final tag = filteredTags[index];
                final isSelected = state.tags.contains(tag);
                return ListTile(
                  title: Text(tag, style: const TextStyle(color: Colors.white)),
                  trailing: Icon(
                    isSelected ? Icons.check_circle : Icons.add_circle_outline,
                    color: isSelected ? Colors.white : Colors.white24,
                  ),
                  onTap: () {
                    if (isSelected) {
                      final newTags = List<String>.from(state.tags)..remove(tag);
                      notifier.updateTags(newTags);
                    } else if (state.tags.length < 5) {
                      final newTags = List<String>.from(state.tags)..add(tag);
                      notifier.updateTags(newTags);
                    }
                  },
                );
              },
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
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
