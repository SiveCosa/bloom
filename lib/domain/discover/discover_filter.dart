import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'discover_feed.dart';

// This holds all the filter values the user can select
class DiscoverFilter {
  final List<String> dateFilters;
  final double distanceKm;
  final List<String> visibilityFilters;
  final List<String> tags;

  const DiscoverFilter({
    this.dateFilters = const [],
    this.distanceKm = 40,
    this.visibilityFilters = const [],
    this.tags = const [],
  });

  bool get hasFilters =>
      dateFilters.isNotEmpty ||
      distanceKm != 40 ||
      visibilityFilters.isNotEmpty ||
      tags.isNotEmpty;

  int get filterCount =>
      dateFilters.length +
      (distanceKm != 40 ? 1 : 0) +
      visibilityFilters.length +
      tags.length;

  // Creates a copy with updated values
  DiscoverFilter copyWith({
    List<String>? dateFilters,
    double? distanceKm,
    List<String>? visibilityFilters,
    List<String>? tags,
  }) {
    return DiscoverFilter(
      dateFilters: dateFilters ?? this.dateFilters,
      distanceKm: distanceKm ?? this.distanceKm,
      visibilityFilters: visibilityFilters ?? this.visibilityFilters,
      tags: tags ?? this.tags,
    );
  }

  /// Apply the filter to a list of events.
  List<DiscoverFeedCard> apply(List<DiscoverFeedCard> events) {
    if (!hasFilters) return events;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final next7Days = today.add(const Duration(days: 7));
    final next30Days = today.add(const Duration(days: 30));

    return events.where((event) {
      // 1. Distance filter
      if (event.distanceKm > distanceKm) {
        return false;
      }

      // 2. Tags filter
      if (tags.isNotEmpty) {
        bool hasMatchingTag = false;
        final eventTagsLower = event.tags.map((t) => t.toLowerCase()).toList();
        for (final filterTag in tags) {
          if (eventTagsLower.contains(filterTag.toLowerCase())) {
            hasMatchingTag = true;
            break;
          }
        }
        if (!hasMatchingTag) {
          return false;
        }
      }

      // 3. Date filter
      if (dateFilters.isNotEmpty) {
        if (event.startTime == null) return false;
        final start = event.startTime!;

        bool matchesDate = false;
        for (final dateFilter in dateFilters) {
          if (dateFilter == 'Today' &&
              start.isAfter(today) &&
              start.isBefore(tomorrow)) {
            matchesDate = true;
            break;
          } else if (dateFilter == 'Tomorrow' &&
              start.isAfter(tomorrow) &&
              start.isBefore(tomorrow.add(const Duration(days: 1)))) {
            matchesDate = true;
            break;
          } else if (dateFilter == 'Next 7 days' &&
              start.isAfter(today) &&
              start.isBefore(next7Days)) {
            matchesDate = true;
            break;
          } else if (dateFilter == 'Next 30 days' &&
              start.isAfter(today) &&
              start.isBefore(next30Days)) {
            matchesDate = true;
            break;
          }
        }
        if (!matchesDate) {
          return false;
        }
      }

      // 4. Visibility filter
      // (Assuming visibility filtering is either not fully supported by DiscoverFeedCard or requires specific logic.
      // If DiscoverFeedCard had a visibility property, we would filter here.
      // Currently DiscoverFeedCard does not have visibility info from backend.
      // For now, we'll just allow it if visibilityFilters is not completely overriding.)

      return true;
    }).toList();
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
