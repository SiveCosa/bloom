import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/calendar/calendar_providers.dart';
import '../../domain/calendar/scheduled_event.dart';
import '../shared/widgets/gradient_top_bar.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  final ValueNotifier<double> _sheetExtent = ValueNotifier(0.35);
  late final PageController _pageController = PageController(
    initialPage: 10000,
  );
  late DateTime _displayedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  @override
  void dispose() {
    _sheetExtent.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final scheduleAsync = ref.watch(scheduleStreamProvider);

    final days = _generateMonthDays(_displayedMonth);
    final int rowCount = (days[35].month == _displayedMonth.month) ? 6 : 5;

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final safeAreaTop = mediaQuery.padding.top;
    // Always position the sheet 15dp below where the 6th week would be
    final double estimatedHeaderHeight = safeAreaTop + 140 + (6 * 46);
    final double initialSize =
        ((screenHeight - estimatedHeaderHeight) / screenHeight).clamp(0.1, 0.6);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E12),
      body: Stack(
        children: [
          const GradientTopBar(
            height: 100,
            showDarkOverlay: true,
            darkOverlayHeight: 200,
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                _buildNavigationToggle(),
                _buildWeekdayHeaders(),
                Expanded(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _sheetExtent,
                    builder: (context, extent, child) {
                      // Normalize extent from the dynamic min size to initialSize + 0.15
                      final collapseProgress = ((extent - initialSize) / 0.15)
                          .clamp(0.0, 1.0);
                      return PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          final diff = index - 10000;
                          final now = DateTime.now();
                          setState(() {
                            _displayedMonth = DateTime(
                              now.year,
                              now.month + diff,
                              1,
                            );
                          });
                        },
                        itemBuilder: (context, index) {
                          final diff = index - 10000;
                          final now = DateTime.now();
                          final monthDate = DateTime(
                            now.year,
                            now.month + diff,
                            1,
                          );
                          return _buildCalendarGrid(
                            monthDate,
                            collapseProgress,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          _buildDraggableSheet(
            scheduleAsync,
            selectedDate,
            initialSize,
            rowCount,
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final monthName = DateFormat('MMMM').format(_displayedMonth);

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              // Future implementation: Month picker
            },
            child: Row(
              children: [
                Text(
                  monthName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white70,
                  size: 24,
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildIconButton(Icons.search),
              const SizedBox(width: 12),
              _buildIconButton(Icons.tune),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildNavigationToggle() {
    return Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 20),
      child: Row(
        children: [
          Expanded(
            child: Center(child: _buildToggleItem(Icons.calendar_today, true)),
          ),
          Expanded(child: Center(child: _buildToggleItem(Icons.list, false))),
        ],
      ),
    );
  }

  Widget _buildToggleItem(IconData icon, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
          size: 28,
        ),
        if (isActive) ...[
          const SizedBox(height: 8),
          Container(
            width: 32,
            height: 2,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWeekdayHeaders() {
    final weekdays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekdays
            .map(
              (day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(DateTime monthDate, double collapseProgress) {
    final selectedDate = ref.watch(selectedDateProvider);
    final days = _generateMonthDays(monthDate);

    // Find the index of the row containing the selected date
    int selectedIndex = days.indexWhere((d) => _isSameDay(d, selectedDate));
    if (selectedIndex == -1) {
      selectedIndex = days.indexWhere((d) => _isSameDay(d, DateTime.now()));
      if (selectedIndex == -1) selectedIndex = 0;
    }
    final selectedRowIndex = selectedIndex ~/ 7;

    // Determine row count: 6 rows only if the month extends into the 6th week
    final int rowCount = (days[35].month == monthDate.month) ? 6 : 5;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Calendar rows
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rowCount,
              itemBuilder: (context, rowIndex) {
                final rowDays = days.sublist(rowIndex * 7, (rowIndex + 1) * 7);

                // If collapsing, shrink other rows
                final bool isSelectedRow = rowIndex == selectedRowIndex;
                final double rowHeight = isSelectedRow
                    ? 46.0
                    : 46.0 * (1.0 - collapseProgress);
                final double opacity = isSelectedRow
                    ? 1.0
                    : (1.0 - collapseProgress);

                return Opacity(
                  opacity: opacity,
                  child: SizedBox(
                    height: rowHeight,
                    child: Row(
                      children: rowDays
                          .map(
                            (day) => Expanded(
                              child: _buildCalendarDay(
                                day,
                                monthDate,
                                isSelectedRow,
                                collapseProgress,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarDay(
    DateTime day,
    DateTime monthDate,
    bool isSelectedRow,
    double collapseProgress,
  ) {
    final selectedDate = ref.watch(selectedDateProvider);
    final isSelected = _isSameDay(day, selectedDate);
    final isToday = _isSameDay(day, DateTime.now());
    final isOtherMonth = day.month != monthDate.month;

    final scheduleAsync = ref.watch(scheduleStreamProvider);
    final events = scheduleAsync.when(
      data: (data) => data.where((e) => _isSameDay(e.startTime, day)).toList(),
      loading: () => <ScheduledEvent>[],
      error: (err, stack) => <ScheduledEvent>[],
    );

    return GestureDetector(
      onTap: () => ref.read(selectedDateProvider.notifier).updateDate(day),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isSelected ? 10 : 12),
              child: Stack(
                children: [
                  _buildEventBackground(events),
                  Center(
                    child: Text(
                      DateFormat('dd').format(day),
                      style: TextStyle(
                        color: isOtherMonth
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.white,
                        fontSize: 16,
                        fontWeight: isSelected || isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventBackground(List<ScheduledEvent> events) {
    if (events.isEmpty) return Container();

    if (events.length == 1) {
      return Positioned.fill(
        child: Stack(
          children: [
            if (events[0].posterUrl != null)
              Image.network(
                events[0].posterUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) =>
                    _buildFallbackFill(),
              )
            else
              _buildFallbackFill(),
            Container(color: Colors.black.withValues(alpha: 0.3)),
          ],
        ),
      );
    }

    // 2+ events
    return Positioned.fill(
      child: Row(
        children: [
          Expanded(child: _buildMiniPoster(events[0])),
          Expanded(child: _buildMiniPoster(events[1])),
        ],
      ),
    );
  }

  Widget _buildMiniPoster(ScheduledEvent event) {
    return Stack(
      children: [
        if (event.posterUrl != null)
          Image.network(
            event.posterUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => _buildFallbackFill(),
          )
        else
          _buildFallbackFill(),
        Container(color: Colors.black.withValues(alpha: 0.3)),
      ],
    );
  }

  Widget _buildFallbackFill() {
    return Container(color: Colors.white.withValues(alpha: 0.1));
  }

  Widget _buildDraggableSheet(
    AsyncValue<List<ScheduledEvent>> scheduleAsync,
    DateTime selectedDate,
    double initialSize,
    int rowCount,
  ) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _sheetExtent.value = notification.extent;
        });
        return false;
      },
      child: DraggableScrollableSheet(
        key: ValueKey('sheet_$rowCount'),
        initialChildSize: initialSize,
        minChildSize: initialSize,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D21).withValues(alpha: 0.9),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
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
                    Text(
                      _formatSelectedDate(selectedDate),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: scheduleAsync.when(
                        data: (events) {
                          final filteredEvents = events
                              .where(
                                (e) => _isSameDay(e.startTime, selectedDate),
                              )
                              .toList();
                          if (filteredEvents.isEmpty) {
                            return const Center(
                              child: Text(
                                'No events scheduled',
                                style: TextStyle(color: Colors.white54),
                              ),
                            );
                          }
                          return ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredEvents.length,
                            itemBuilder: (context, index) =>
                                _buildEventCard(filteredEvents[index]),
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Error: $e')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEventCard(ScheduledEvent event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: event.posterUrl != null
                  ? DecorationImage(
                      image: NetworkImage(event.posterUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.more_horiz,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Today • ${DateFormat('h a').format(event.startTime).toLowerCase()} - ${DateFormat('h a').format(event.endTime).toLowerCase()}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.alternate_email,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      event.locationName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatSelectedDate(DateTime date) {
    final now = DateTime.now();
    final isToday = _isSameDay(date, now);
    final prefix = isToday ? 'Today • ' : '';
    return '$prefix${DateFormat('d MMMM yyyy').format(date)}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<DateTime> _generateMonthDays(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);

    // Find the first Monday of the week containing the first day of the month
    final int firstDayWeekday = firstDayOfMonth.weekday;
    final int daysToSubtract = firstDayWeekday - 1; // Mon=1
    final startDate = firstDayOfMonth.subtract(Duration(days: daysToSubtract));

    return List.generate(42, (index) => startDate.add(Duration(days: index)));
  }
}
