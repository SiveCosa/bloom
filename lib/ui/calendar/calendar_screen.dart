import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../domain/calendar/calendar_providers.dart';
import '../../domain/calendar/scheduled_event.dart';
import '../shared/widgets/gradient_top_bar.dart';
import '../../core/theme/app_theme.dart';
import './widgets/month_year_picker_modal.dart';
import '../shared/widgets/bloom_icon_button.dart';
import '../../domain/navigation/navigation_providers.dart';

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

  void _resetToToday() {
    final now = DateTime.now();
    setState(() {
      _displayedMonth = DateTime(now.year, now.month, 1);
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(10000);
    }

    // Also reset the selected date to today
    ref.read(selectedDateProvider.notifier).updateDate(now);
  }

  @override
  Widget build(BuildContext context) {
    // Listen for tab changes to reset the calendar when returning
    ref.listen<int>(mainShellIndexProvider, (previous, next) {
      if (next == 2 && previous != 2) {
        _resetToToday();
      }
    });

    final selectedDate = ref.watch(selectedDateProvider);
    final scheduleAsync = ref.watch(scheduleStreamProvider);

    final days = _generateMonthDays(_displayedMonth);
    final int rowCount = (days[35].month == _displayedMonth.month) ? 6 : 5;

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final safeAreaTop = mediaQuery.padding.top;
    // Always position the sheet 20dp below where the 6th week would be
    final double estimatedHeaderHeight = safeAreaTop + 147 + (6 * 46) + 20;
    final double initialSize =
        ((screenHeight - estimatedHeaderHeight) / screenHeight).clamp(0.1, 0.6);

    // Height of one week view (approx: AppBar 50 + Spacer 15 + Toggle 50 + Spacer 10 + Weekdays 25 + Spacer 16 + Week 46 + Margin 12)
    final double estimatedWeekViewHeight = safeAreaTop + 150 + 46 + 12;
    final double maxChildSize =
        ((screenHeight - estimatedWeekViewHeight) / screenHeight).clamp(0.4, 0.95);

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
                const SizedBox(height: 15),
                _buildNavigationToggle(),
                const SizedBox(height: 10),
                _buildWeekdayHeaders(),
                Expanded(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _sheetExtent,
                    builder: (context, extent, child) {
                      // Normalize extent from initialSize to maxChildSize
                      final collapseProgress =
                          ((extent - initialSize) / (maxChildSize - initialSize))
                              .clamp(0.0, 1.0);
                      return PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          final diff = index - 10000;
                          final now = DateTime.now();
                          final newMonth = DateTime(
                            now.year,
                            now.month + diff,
                            1,
                          );
                          setState(() {
                            _displayedMonth = newMonth;
                          });
                          // Automatically set the 1st of the new month as the active/selected day
                          ref
                              .read(selectedDateProvider.notifier)
                              .updateDate(newMonth);
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
            maxChildSize,
            rowCount,
          ),
        ],
      ),
    );
  }

  void _showMonthYearPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MonthYearPickerModal(
        initialDate: _displayedMonth,
        onDateSelected: (selectedDate) {
          final now = DateTime.now();
          
          // If it's today, also set it as the active/selected day
          if (_isSameDay(selectedDate, now)) {
            ref.read(selectedDateProvider.notifier).updateDate(now);
          }

          final monthDiff = (selectedDate.year - now.year) * 12 +
              (selectedDate.month - now.month);
          final targetPage = 10000 + monthDiff;

          _pageController.animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      ),
    );
  }

  Widget _buildAppBar() {
    final now = DateTime.now();
    final isCurrentYear = _displayedMonth.year == now.year;
    final monthName = isCurrentYear
        ? DateFormat('MMMM').format(_displayedMonth)
        : DateFormat('MMM yyyy').format(_displayedMonth);

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              // Implementation: Month picker
              _showMonthYearPicker();
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
              BloomIconButton(
                icon: Icons.search,
                onTap: () {
                  // Handle search
                },
              ),
              const SizedBox(width: 12),
              BloomIconButton(
                icon: Icons.tune,
                onTap: () {
                  // Handle filter
                },
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildNavigationToggle() {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: _buildToggleItem(
                icon: Icons.calendar_month,
                isActive: true,
                size: 25,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: _buildToggleItem(
                icon: Icons.list,
                isActive: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    IconData? icon,
    String? iconPath,
    required bool isActive,
    double size = 28,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iconPath != null)
          SvgPicture.asset(
            iconPath,
            width: size,
            height: size,
            colorFilter: ColorFilter.mode(
              isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
              BlendMode.srcIn,
            ),
          )
        else
          Icon(
            icon,
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
            size: size,
          ),
        if (isActive) ...[
          const SizedBox(height: 8),
          Container(
            width: 50,
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
          // Calendar rows
          Column(
            children: List.generate(rowCount, (rowIndex) {
              final rowDays = days.sublist(rowIndex * 7, (rowIndex + 1) * 7);

              // Find if this is the row containing the selected date
              final bool isSelectedRow = rowIndex == selectedRowIndex;

              // Use a curve for smoother transition
              final curvedProgress = Curves.easeInOut.transform(collapseProgress);

              // Fade out faster than we shrink
              final double opacity = isSelectedRow
                  ? 1.0
                  : (1.0 - curvedProgress * 1.5).clamp(0.0, 1.0);

              final double rowHeight = isSelectedRow
                  ? 46.0
                  : 46.0 * (1.0 - curvedProgress);

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
            }),
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

    if (isOtherMonth) {
      return const SizedBox.shrink();
    }

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
                  if (isToday)
                    Center(
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryButton,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: events.isNotEmpty
                          ? BoxDecoration(
                              color: _getEventColor(events[0]),
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: Text(
                        DateFormat('dd').format(day),
                        style: TextStyle(
                          color: events.isNotEmpty
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.8),
                          fontSize: 16,
                          fontWeight: isSelected || isToday || events.isNotEmpty
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
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

  Color _getEventColor(ScheduledEvent event) {
    if (event.auroraColors.isEmpty) {
      return const Color(0xFFC151FD); // Fallback to brand purple
    }
    
    // Pick the most suitable color from the palette.
    // Index 0 or 2 are usually good candidates for dominant/vibrant colors.
    return _parseHexColor(event.auroraColors[0]);
  }

  Color _parseHexColor(String hex) {
    String hexStr = hex.replaceFirst('#', '');
    if (hexStr.length == 6) {
      hexStr = 'FF$hexStr';
    } else if (hexStr.length == 8 && hexStr.startsWith('0x')) {
      hexStr = hexStr.substring(2);
    }
    try {
      return Color(int.parse(hexStr, radix: 16));
    } catch (e) {
      return const Color(0xFFC151FD); // Fallback
    }
  }

  Widget _buildEventBackground(List<ScheduledEvent> events) {
    if (events.isEmpty) return Container();

    if (events.length == 1) {
      return Positioned(
        top: 3,
        left: 3,
        right: 3,
        bottom: 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
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
        ),
      );
    }

    // 2+ events
    return Positioned.fill(
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(-0.7, -0.7),
            child: FractionallySizedBox(
              widthFactor: 0.6,
              heightFactor: 0.6,
              child: Transform.rotate(
                angle: -10 * math.pi / 180,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: _buildMiniPoster(events[1]),
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0.7, 0.7),
            child: FractionallySizedBox(
              widthFactor: 0.6,
              heightFactor: 0.6,
              child: Transform.rotate(
                angle: 10 * math.pi / 180,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: _buildMiniPoster(events[0]),
                ),
              ),
            ),
          ),
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
    double maxChildSize,
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
        initialChildSize: initialSize,
        minChildSize: initialSize,
        maxChildSize: maxChildSize,
        snap: true,
        snapSizes: [initialSize, maxChildSize],
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF25282D),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              child: CustomScrollView(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    automaticallyImplyLeading: false,
                    backgroundColor: const Color(0xFF25282D),
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    toolbarHeight: 30,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
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
                          const SizedBox(height: 10),
                          Text(
                            _formatSelectedDate(selectedDate),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  scheduleAsync.when(
                    data: (events) {
                      final filteredEvents = events
                          .where(
                            (e) => _isSameDay(e.startTime, selectedDate),
                          )
                          .toList();
                      if (filteredEvents.isEmpty) {
                        return const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              'No events scheduled',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        );
                      }
                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _buildEventCard(filteredEvents[index]),
                            childCount: filteredEvents.length,
                          ),
                        ),
                      );
                    },
                    loading: () => const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('Error: $e')),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 40),
                  ),
                ],
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
                      Icons.calendar_month,
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
