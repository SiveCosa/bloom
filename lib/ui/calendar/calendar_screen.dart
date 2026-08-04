import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../domain/auth/auth_providers.dart';
import '../../domain/calendar/calendar_providers.dart';
import '../../domain/calendar/scheduled_event.dart';
import '../shared/widgets/gradient_top_bar.dart';
import '../../core/theme/app_theme.dart';
import './widgets/calendar_filter_sheet.dart';
import './widgets/month_year_picker_modal.dart';
import '../shared/widgets/bloom_icon_button.dart';
import '../../domain/navigation/navigation_providers.dart';
import '../../core/routing/event_navigation.dart';
import '../widgets/scheduled_event_card.dart';
import '../shared/widgets/past_events_divider.dart';
import 'package:skeletonizer/skeletonizer.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  final ValueNotifier<double> _sheetExtent = ValueNotifier(0.35);
  bool _isListView = false;
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
    ref.read(visibleMonthProvider.notifier).updateMonth(now);

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
    final scheduleAsync = ref.watch(filteredScheduleProvider);

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
        ((screenHeight - estimatedWeekViewHeight) / screenHeight).clamp(
          0.4,
          0.95,
        );

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E12),
      body: Stack(
        children: [
          const GradientTopBar(height: 100, showDarkOverlay: false),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                const SizedBox(height: 15),
                _buildNavigationToggle(),
                if (!_isListView) ...[
                  const SizedBox(height: 10),
                  _buildWeekdayHeaders(),
                  Expanded(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _sheetExtent,
                      builder: (context, extent, child) {
                        // Normalize extent from initialSize to maxChildSize
                        final collapseProgress =
                            ((extent - initialSize) /
                                    (maxChildSize - initialSize))
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
                            ref
                                .read(visibleMonthProvider.notifier)
                                .updateMonth(newMonth);
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
                ] else
                  Expanded(child: _buildListView(scheduleAsync)),
              ],
            ),
          ),
          if (!_isListView)
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

          final monthDiff =
              (selectedDate.year - now.year) * 12 +
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
                onTap: () => context.push('/calendar/search'),
              ),
              const SizedBox(width: 12),
              BloomIconButton(
                icon: Icons.tune,
                onTap: () => CalendarFilterSheet.show(context),
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
            child: InkWell(
              onTap: () => setState(() => _isListView = false),
              child: Center(
                child: _buildToggleItem(
                  icon: Icons.calendar_month,
                  isActive: !_isListView,
                  size: 25,
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _isListView = true),
              child: Center(
                child: _buildToggleItem(
                  icon: Icons.list,
                  isActive: _isListView,
                ),
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
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.4),
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
          Column(
            children: List.generate(rowCount, (rowIndex) {
              final rowDays = days.sublist(rowIndex * 7, (rowIndex + 1) * 7);

              // Find if this is the row containing the selected date
              final bool isSelectedRow = rowIndex == selectedRowIndex;

              // Use a curve for smoother transition
              final curvedProgress = Curves.easeInOut.transform(
                collapseProgress,
              );

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

    final eventsByDay = ref.watch(eventsByDayProvider);
    final events = eventsByDay[DateTime(day.year, day.month, day.day)] ?? <ScheduledEvent>[];

    final showQuestionMark = events.any((e) {
      final status = e.rsvpStatus;
      return status == 'maybe' || status == 'interested';
    });

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
                  _buildEventBackground(
                    events,
                    showQuestionMark: showQuestionMark,
                  ),
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
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      child: showQuestionMark
                          ? Icon(
                              Icons.question_mark,
                              color: Colors.white.withValues(alpha: 1.0),
                              size: 18,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.85),
                                  offset: const Offset(0, 1),
                                  blurRadius: 4,
                                ),
                              ],
                            )
                          : Text(
                              DateFormat('dd').format(day),
                              style: TextStyle(
                                color:
                                    isSelected || isToday || events.isNotEmpty
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.8),
                                fontSize: 16,
                                fontWeight:
                                    isSelected || isToday || events.isNotEmpty
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                shadows: events.isNotEmpty && !isToday
                                    ? [
                                        Shadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.8,
                                          ),
                                          offset: const Offset(0, 1),
                                          blurRadius: 4,
                                        ),
                                      ]
                                    : null,
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

  Widget _buildEventBackground(
    List<ScheduledEvent> events, {
    bool showQuestionMark = false,
  }) {
    if (events.isEmpty) return Container();

    if (events.length == 1) {
      return Positioned(
        top: 3,
        left: 3,
        right: 3,
        bottom: 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Opacity(
            opacity: events[0].isPast ? 0.5 : 1.0,
            child: events[0].posterUrl != null
                ? CachedNetworkImage(
                    imageUrl: events[0].posterUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorWidget: (context, url, error) => _buildFallbackFill(),
                  )
                : _buildFallbackFill(),
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
                  child: Opacity(
                    opacity: events[1].isPast ? 0.5 : 1.0,
                    child: _buildMiniPoster(events[1]),
                  ),
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
                  child: Opacity(
                    opacity: events[0].isPast ? 0.5 : 1.0,
                    child: _buildMiniPoster(events[0]),
                  ),
                ),
              ),
            ),
          ),
          if (showQuestionMark)
            Center(
              child: Icon(
                Icons.question_mark,
                color: Colors.white.withValues(alpha: 1.0),
                size: 20,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.85),
                    offset: const Offset(0, 1),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniPoster(ScheduledEvent event) {
    if (event.posterUrl != null) {
      return CachedNetworkImage(
        imageUrl: event.posterUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorWidget: (context, url, error) => _buildFallbackFill(),
      );
    }
    return _buildFallbackFill();
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
                            (e) =>
                                e.startTime != null &&
                                _isSameDay(e.startTime!, selectedDate),
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
                      final currentUserId = ref
                          .watch(firebaseAuthProvider)
                          .currentUser
                          ?.uid;
                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final event = filteredEvents[index];
                            final isHost =
                                currentUserId != null &&
                                (currentUserId == event.hostId ||
                                    event.coHostIds.contains(currentUserId));
                            return ScheduledEventCard(
                              event: event,
                              isHost: isHost,
                              onTap: () {
                                pushEventDetail(context, event.id);
                              },
                            );
                          }, childCount: filteredEvents.length),
                        ),
                      );
                    },
                    loading: () => SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final dummyEvent = ScheduledEvent(
                            id: 'dummy_$index',
                            title: 'Loading Event Title',
                            startTime: DateTime.now(),
                            endTime: DateTime.now().add(const Duration(hours: 2)),
                            hostName: 'Loading Host',
                            hostId: 'dummy_host',
                            auroraColors: ['#333333', '#666666'],
                            locationName: 'Loading Location',
                          );
                          return Skeletonizer(
                            enabled: true,
                            child: ScheduledEventCard(
                              event: dummyEvent,
                              isHost: false,
                              onTap: () {},
                            ),
                          );
                        }, childCount: 3),
                      ),
                    ),
                    error: (e, _) => SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('Error: $e')),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                ],
              ),
            ),
          );
        },
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

  Widget _buildListView(AsyncValue<List<ScheduledEvent>> scheduleAsync) {
    return scheduleAsync.when(
      data: (events) {
        final now = DateTime.now();
        final upcoming = events
            .where(
              (e) =>
                  e.startTime == null ||
                  e.startTime!.isAfter(now) ||
                  _isSameDay(e.startTime!, now),
            )
            .toList();
        final past = events
            .where(
              (e) =>
                  e.startTime != null &&
                  e.startTime!.isBefore(now) &&
                  !_isSameDay(e.startTime!, now),
            )
            .toList();

        // Task 1: Sorting
        upcoming.sort((a, b) {
          if (a.startTime == null && b.startTime == null) return 0;
          if (a.startTime == null) return -1;
          if (b.startTime == null) return 1;
          return a.startTime!.compareTo(b.startTime!);
        });
        past.sort((a, b) => b.startTime!.compareTo(a.startTime!));

        // Task 1: Grouping
        final upcomingGrouped = _groupEventsByDay(upcoming);
        final pastGrouped = _groupEventsByDay(past);

        final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            ..._buildEventList(upcomingGrouped, currentUserId, "Upcoming"),

            // Task 3: Past Events Divider
            if (past.isNotEmpty)
              const SliverToBoxAdapter(child: PastEventsDivider()),

            // Past Events List
            ..._buildEventList(pastGrouped, currentUserId, "Past"),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  List<Widget> _buildEventList(
    Map<DateTime?, List<ScheduledEvent>> groupedEvents,
    String? currentUserId,
    String type,
  ) {
    final List<Widget> slivers = [];
    final sortedDates = groupedEvents.keys.toList();

    // Dates are already sorted implicitly by the list sorting before grouping,
    // but let's be explicit based on type
    if (type == "Upcoming") {
      sortedDates.sort((a, b) {
        if (a == null && b == null) return 0;
        if (a == null) return -1;
        if (b == null) return 1;
        return a.compareTo(b);
      });
    } else {
      sortedDates.sort((a, b) {
        if (a == null && b == null) return 0;
        if (a == null) return 1;
        if (b == null) return -1;
        return b.compareTo(a);
      });
    }

    for (var date in sortedDates) {
      final events = groupedEvents[date]!;

      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 12,
            ),
            child: _buildGroupHeader(date),
          ),
        ),
      );

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final event = events[index];
              final isHost =
                  currentUserId != null &&
                  (currentUserId == event.hostId ||
                      event.coHostIds.contains(currentUserId));
              return ScheduledEventCard(
                event: event,
                isHost: isHost,
                onTap: () {
                  pushEventDetail(context, event.id);
                },
              );
            }, childCount: events.length),
          ),
        ),
      );
    }
    return slivers;
  }

  Widget _buildGroupHeader(DateTime? date) {
    if (date == null) {
      return const Text(
        "Date TBD",
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600, // Semi-bold
        ),
      );
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final dayLabel = (date == today)
        ? "Today"
        : DateFormat('EEEE').format(date);
    final dateLabel = " • ${DateFormat('d MMMM').format(date)}";

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: dayLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600, // Semi-bold
            ),
          ),
          TextSpan(
            text: dateLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 16,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Map<DateTime?, List<ScheduledEvent>> _groupEventsByDay(
    List<ScheduledEvent> events,
  ) {
    final Map<DateTime?, List<ScheduledEvent>> grouped = {};
    for (var event in events) {
      final date = event.startTime != null
          ? DateTime(
              event.startTime!.year,
              event.startTime!.month,
              event.startTime!.day,
            )
          : null;
      if (grouped[date] == null) grouped[date] = [];
      grouped[date]!.add(event);
    }
    return grouped;
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
