import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/calendar/calendar_filter.dart';
import '../../../domain/calendar/calendar_providers.dart';
import '../../shared/widgets/bloom_modal_shell.dart';
import '../../shared/widgets/bloom_selection_tile.dart';

class CalendarFilterSheet extends ConsumerStatefulWidget {
  const CalendarFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CalendarFilterSheet(),
    );
  }

  @override
  ConsumerState<CalendarFilterSheet> createState() => _CalendarFilterSheetState();
}

class _CalendarFilterSheetState extends ConsumerState<CalendarFilterSheet> {
  late Set<CalendarFilterCategory> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<CalendarFilterCategory>.from(ref.read(calendarFilterProvider));
  }

  void _handleReset() {
    setState(() {
      _selected = Set<CalendarFilterCategory>.from(defaultCalendarFilters);
    });
  }

  void _handleDone() {
    ref.read(calendarFilterProvider.notifier).setFilters(_selected);
    Navigator.pop(context);
  }

  void _toggleCategory(CalendarFilterCategory category) {
    setState(() {
      if (_selected.contains(category)) {
        _selected.remove(category);
      } else {
        _selected.add(category);
      }
    });
  }

  Widget _buildCategoryLeading(CalendarFilterCategory category) {
    switch (category) {
      case CalendarFilterCategory.myEvents:
        return _FilterBadge(
          backgroundColor: const Color(0xFFFFD60A),
          icon: Icons.workspace_premium,
          iconColor: Colors.white,
        );
      case CalendarFilterCategory.attending:
        return _FilterBadge(
          backgroundColor: const Color(0xFF32D74B),
          icon: Icons.check,
          iconColor: Colors.white,
        );
      case CalendarFilterCategory.deciding:
        return _FilterBadge(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF9F0A), Color(0xFFFF375F)],
          ),
          icon: Icons.question_mark,
          iconColor: Colors.white,
        );
      case CalendarFilterCategory.notGoing:
        return _FilterBadge(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF453A), Color(0xFFFF2D55)],
          ),
          icon: Icons.close,
          iconColor: Colors.white,
        );
      case CalendarFilterCategory.waitingOnHost:
        return _FilterBadge(
          backgroundColor: const Color(0xFFBF5AF2),
          icon: Icons.schedule,
          iconColor: Colors.white,
        );
    }
  }

  Widget _buildFilterRow(CalendarFilterCategory category) {
    final isSelected = _selected.contains(category);

    return BloomSelectionTile(
      leading: _buildCategoryLeading(category),
      title: category.title,
      subtitle: category.subtitle,
      isSelected: isSelected,
      useSolidCheck: true,
      verticalPadding: 14,
      onTap: () => _toggleCategory(category),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BloomModalShell(
      title: 'Filter Calendar',
      leftActionText: 'Reset',
      onLeftActionPressed: _handleReset,
      rightActionText: 'Done',
      onRightActionPressed: _handleDone,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterRow(CalendarFilterCategory.myEvents),
            _buildDivider(),
            _buildFilterRow(CalendarFilterCategory.attending),
            _buildFilterRow(CalendarFilterCategory.deciding),
            _buildFilterRow(CalendarFilterCategory.notGoing),
            _buildDivider(),
            _buildFilterRow(CalendarFilterCategory.waitingOnHost),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _FilterBadge extends StatelessWidget {
  static const double size = 25;
  static const double iconSize = 14;

  final LinearGradient? gradient;
  final Color? backgroundColor;
  final IconData icon;
  final Color iconColor;

  const _FilterBadge({
    this.gradient,
    this.backgroundColor,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient,
          color: gradient == null ? backgroundColor : null,
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: iconSize,
        ),
      ),
    );
  }
}