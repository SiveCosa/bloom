import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/categories/category_providers.dart';
import '../../../domain/event/create_event_state.dart';
import '../../shared/widgets/custom_text_fields.dart';
import '../../shared/widgets/bloom_modal_shell.dart';

class TagSelectionModal extends ConsumerStatefulWidget {
  const TagSelectionModal({super.key});

  @override
  ConsumerState<TagSelectionModal> createState() => _TagSelectionModalState();
}

class _TagSelectionModalState extends ConsumerState<TagSelectionModal> {
  final _searchController = TextEditingController();
  late List<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    _selectedTags = List<String>.from(ref.read(createEventProvider).tags);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSave() {
    ref.read(createEventProvider.notifier).updateTags(_selectedTags);
    Navigator.pop(context);
  }

  void _handleClear() {
    setState(() {
      _selectedTags.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return BloomModalShell(
      title: 'Event Tags',
      height: MediaQuery.of(context).size.height,
      useSafeArea: true,
      leftActionText: 'Clear',
      onLeftActionPressed: _handleClear,
      rightActionText: 'Save',
      onRightActionPressed: _handleSave,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      child: Expanded(
        child: Column(
          children: [
            Text(
              'Select up to 5 tags (${_selectedTags.length}/5)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            RoundedTextField(
              controller: _searchController,
              hintText: 'Search tags...',
              onChanged: (_) => setState(() {}),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.white54,
                size: 20,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: categoriesAsync.when(
                data: (categories) {
                  final query = _searchController.text.toLowerCase().trim();

                  return ListView.builder(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    itemCount: categories.length + 1,
                    itemBuilder: (context, index) {
                      if (index == categories.length) {
                        return const SizedBox(height: 40);
                      }

                      final category = categories[index];
                      final filteredTags = query.isEmpty
                          ? category.tags
                          : category.tags
                                .where((i) => i.toLowerCase().contains(query))
                                .toList();

                      if (filteredTags.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              category.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 12,
                            children: filteredTags.map((tag) {
                              final isSelected = _selectedTags.contains(tag);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedTags.remove(tag);
                                    } else if (_selectedTags.length < 5) {
                                      _selectedTags.add(tag);
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white.withValues(
                                              alpha: 0.15,
                                            ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        tag,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.black
                                              : Colors.white,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Colors.black,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
