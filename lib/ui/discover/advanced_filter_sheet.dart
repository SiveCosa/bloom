import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'filter_tag_selection_screen.dart';

// --- Filter State Model ---
// This holds all the filter values the user can select
class DiscoverFilter {
  final String? dateFilter;
  final double distanceKm;
  final List<String> visibilityFilters;
  final List<String> tags;

  const DiscoverFilter({
    this.dateFilter,
    this.distanceKm = 40,
    this.visibilityFilters = const [],
    this.tags = const [],
  });

  // Creates a copy with updated values
  DiscoverFilter copyWith({
    String? dateFilter,
    double? distanceKm,
    List<String>? visibilityFilters,
    List<String>? tags,
  }) {
    return DiscoverFilter(
      dateFilter: dateFilter ?? this.dateFilter,
      distanceKm: distanceKm ?? this.distanceKm,
      visibilityFilters: visibilityFilters ?? this.visibilityFilters,
      tags: tags ?? this.tags,
    );
  }
}

// --- Filter Provider ---
class DiscoverFilterNotifier extends Notifier<DiscoverFilter> {
  @override
  DiscoverFilter build() => const DiscoverFilter();

  void update(DiscoverFilter filter) => state = filter;
}

// Stores the current filter state so the rest of the app can access it
final discoverFilterProvider =
    NotifierProvider<DiscoverFilterNotifier, DiscoverFilter>(
      () => DiscoverFilterNotifier(),
    );

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
    return Scaffold(
      // Full screen background color
      backgroundColor: const Color(0xFF0B0E12),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Clear button - resets all filters
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _localFilter = const DiscoverFilter();
                      });
                    },
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  const Text(
                    'Filter Search',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Done button - saves filters and closes sheet
                  TextButton(
                    onPressed: () {
                      ref.read(discoverFilterProvider.notifier).update(_localFilter);
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Done',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white10),

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
                        final isSelected = _localFilter.dateFilter == option;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              // Toggle — tap again to deselect
                              _localFilter = _localFilter.copyWith(
                                dateFilter: isSelected ? null : option,
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
                    // Add tag button
                    GestureDetector(
                      onTap: () async {
                        // Opens tag selection and waits for result
                        final selectedTags = await Navigator.of(context)
                            .push<List<String>>(
                              MaterialPageRoute(
                                fullscreenDialog: true,
                                builder: (context) => FilterTagSelectionScreen(
                                  initialTags: _localFilter.tags,
                                ),
                              ),
                            );
                        // If user saved tags, update our filter
                        if (selectedTags != null) {
                          setState(() {
                            _localFilter = _localFilter.copyWith(
                              tags: selectedTags,
                            );
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'add tag',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
