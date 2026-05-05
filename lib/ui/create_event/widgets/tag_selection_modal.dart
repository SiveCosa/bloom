import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/auth/auth_providers.dart';
import '../../../domain/event/create_event_state.dart';

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
      _selectedTags = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final signupDataAsync = ref.watch(institutionSignupDataProvider);

    return SafeArea(
      top: true,
      bottom: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          height: MediaQuery.of(context).size.height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF191B1D),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _handleClear,
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    'Event Tags',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _handleSave,
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          color: Color(0xFF6C8EEF),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Select up to 5 tags (${_selectedTags.length}/5)',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 50,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 20,
                    ),
                    hintText: 'Search tags...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: signupDataAsync.when(
                  data: (data) {
                    final query = _searchController.text.toLowerCase().trim();
                    final filtered = query.isEmpty
                        ? data.interests
                        : data.interests.where((i) => i.toLowerCase().contains(query)).toList();

                    return ListView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 12,
                          children: filtered.map((tag) {
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
                                      ? Colors.white.withValues(alpha: 0.10)
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white54
                                        : Colors.white.withValues(alpha: 0.25),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tag,
                                      style: TextStyle(
                                        color: Colors.white,
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
                                        color: Colors.white,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 40),
                      ],
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
      ),
    );
  }
}
