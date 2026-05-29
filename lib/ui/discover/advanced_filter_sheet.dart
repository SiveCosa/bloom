import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/categories/category_providers.dart';
import '../../domain/discover/discover_filter.dart';
import '../../domain/discover/discover_providers.dart';
import '../shared/widgets/custom_text_fields.dart';

// --- Advanced Filter Sheet Widget ---
class AdvancedFilterSheet extends ConsumerStatefulWidget {
  const AdvancedFilterSheet({super.key});

  @override
  ConsumerState<AdvancedFilterSheet> createState() =>
      _AdvancedFilterSheetState();
}

class _AdvancedFilterSheetState extends ConsumerState<AdvancedFilterSheet> {
  // Local state while user is making selections
  late DiscoverFilter _localFilter;

  bool _isTagsExpanded = false;
  bool _showTagSelection = false;
  final TextEditingController _tagSearchController = TextEditingController();
  List<String> _pendingTags = [];


  // Date filter options as per acceptance criteria
  final List<String> _dateOptions = [
    'Today',
    'Tomorrow',
    'Next 7 days',
    'Next 30 days',
  ];

  // Visibility filter options
  // Visibility filter options
  final List<String> _visibilityOptions = [
    'Public',
    'Private',
    'Friends only',
    'Friends of friends',
  ];

  // Stores the current user's gender loaded from Firestore
  String? _userGender;

  @override
  void dispose() {
    _tagSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Load the current filter state when sheet opens
    _localFilter = ref.read(discoverFilterProvider);
    // Load the current user's gender
    _loadUserGender();
  }

  // Fetches the current user's gender from Firestore
  Future<void> _loadUserGender() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _userGender = doc.data()?['gender'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error loading user gender: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      child: Scaffold(
        backgroundColor: const Color(0xFF191B1D),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
            // --- Header ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        const emptyFilter = DiscoverFilter();
                        ref.read(discoverFilterProvider.notifier).update(emptyFilter);
                        final currentCategory = ref.read(discoverCategoryFilterProvider);
                        if (currentCategory == 'Filter') {
                          ref.read(discoverCategoryFilterProvider.notifier).setCategory('All');
                        }
                        Navigator.pop(context);
                      },
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
                    'Filter Search',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        ref.read(discoverFilterProvider.notifier).update(_localFilter);
                        final currentCategory = ref.read(discoverCategoryFilterProvider);
                        if (_localFilter.hasFilters) {
                          ref.read(discoverCategoryFilterProvider.notifier).setCategory('Filter');
                        } else if (currentCategory == 'Filter') {
                          ref.read(discoverCategoryFilterProvider.notifier).setCategory('All');
                        }
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Done',
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
            ),
            const SizedBox(height: 20),

            // --- Scrollable Filter Content ---
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // --- Date Filter Section ---
                    const Text(
                      'Date',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _dateOptions.map((option) {
                        final isSelected = _localFilter.dateFilters.contains(option);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              final updated = List<String>.from(_localFilter.dateFilters);
                              if (isSelected) {
                                updated.remove(option);
                              } else {
                                updated.add(option);
                              }
                              _localFilter = _localFilter.copyWith(dateFilters: updated);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  option,
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
                                  const SizedBox(width: 6),
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

                    const SizedBox(height: 32),

                    // --- Distance Filter Section ---
                    const Text(
                      'Distance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '0km',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const Text(
                          '1000km',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    Slider(
                      value: _localFilter.distanceKm,
                      min: 0,
                      // Max is 1000km as per acceptance criteria
                      max: 1000,
                      activeColor: Colors.blue,
                      inactiveColor: Colors.white24,
                      onChanged: (value) {
                        setState(() {
                          _localFilter = _localFilter.copyWith(
                            distanceKm: value,
                          );
                        });
                      },
                    ),
                    // Shows current distance value
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        // If at max (1000km), show "Any distance"
                        _localFilter.distanceKm >= 1000
                            ? 'Any distance'
                            : '${_localFilter.distanceKm.round()}km',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // --- Visibility Filter Section ---
                    const Text(
                      'Visibility',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Static visibility options
                        ..._visibilityOptions.map((option) {
                          final isSelected = _localFilter.visibilityFilters
                              .contains(option);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                final updated = List<String>.from(
                                  _localFilter.visibilityFilters,
                                );
                                if (isSelected) {
                                  updated.remove(option);
                                } else {
                                  updated.add(option);
                                }
                                _localFilter = _localFilter.copyWith(
                                  visibilityFilters: updated,
                                );
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    option,
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
                                    const SizedBox(width: 6),
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
                        }),

                        // Dynamic gender option — only shows if user has a gender set
                        if (_userGender != null)
                          Builder(
                            builder: (context) {
                              // Label changes based on user's gender
                              final genderLabel = _userGender == 'male'
                                  ? 'Male only'
                                  : 'Female only';
                              final isSelected = _localFilter.visibilityFilters
                                  .contains(genderLabel);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    final updated = List<String>.from(
                                      _localFilter.visibilityFilters,
                                    );
                                    if (isSelected) {
                                      updated.remove(genderLabel);
                                    } else {
                                      updated.add(genderLabel);
                                    }
                                    _localFilter = _localFilter.copyWith(
                                      visibilityFilters: updated,
                                    );
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        genderLabel,
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
                                        const SizedBox(width: 6),
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
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 32),

                                        // --- Tags Filter Section ---
                    const Text(
                      'Categories & Tags',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Builder(
                      builder: (context) {
                        bool isExpanded = _isTagsExpanded;
                        List<String> displayTags = _localFilter.tags;
                        bool hasMore = false;
                        int moreCount = 0;
                        if (!isExpanded && displayTags.length > 5) {
                          hasMore = true;
                          displayTags = displayTags.sublist(0, 5);
                        }

                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            // Add tag button (always at front)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _pendingTags = List<String>.from(_localFilter.tags);
                                  _tagSearchController.clear();
                                  _showTagSelection = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text('add tag', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                            
                            // Display selected tags
                            ...displayTags.map((tag) => GestureDetector(
                              onTap: () {
                                setState(() {
                                  final updated = List<String>.from(_localFilter.tags)..remove(tag);
                                  _localFilter = _localFilter.copyWith(tags: updated);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tag,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.close, size: 14, color: Colors.black),
                                  ],
                                ),
                              ),
                            )),
                            
                            // +X more button
                            if (hasMore)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isTagsExpanded = true;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: Text(
                                    '+${_localFilter.tags.length - 5} more',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              )
                            else if (isExpanded && _localFilter.tags.length > 5)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isTagsExpanded = false;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: const Text(
                                    'show less',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        );
                      }
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Tag Selection Overlay
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _showTagSelection ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !_showTagSelection,
              child: Container(
                color: const Color(0xFF191B1D),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _pendingTags.clear();
                                });
                              },
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
                            'Categories',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _localFilter = _localFilter.copyWith(tags: _pendingTags);
                                  _showTagSelection = false;
                                  _isTagsExpanded = false;
                                });
                              },
                              child: const Text(
                                'Done',
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
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Text(
                        'Select tags (${_pendingTags.length})',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: RoundedTextField(
                        controller: _tagSearchController,
                        hintText: 'Search tags...',
                        onChanged: (_) => setState(() {}),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, child) {
                          final categoriesAsync = ref.watch(categoriesProvider);
                          return categoriesAsync.when(
                            data: (categories) {
                              final query = _tagSearchController.text.toLowerCase().trim();
                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: categories.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == categories.length) return const SizedBox(height: 40);
                                  
                                  final category = categories[index];
                                  final filteredTags = query.isEmpty 
                                      ? category.tags 
                                      : category.tags.where((t) => t.toLowerCase().contains(query)).toList();
                                      
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
                                          final isSelected = _pendingTags.contains(tag);
                                          return GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                if (isSelected) {
                                                  _pendingTags.remove(tag);
                                                } else {
                                                  _pendingTags.add(tag);
                                                }
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                              decoration: BoxDecoration(
                                                color: isSelected ? Colors.white : Colors.transparent,
                                                borderRadius: BorderRadius.circular(100),
                                                border: Border.all(
                                                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    tag,
                                                    style: TextStyle(
                                                      color: isSelected ? Colors.black : Colors.white,
                                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                    ),
                                                  ),
                                                  if (isSelected) ...[
                                                    const SizedBox(width: 8),
                                                    const Icon(Icons.close, size: 14, color: Colors.black),
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
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  ),
),
);
}
}
