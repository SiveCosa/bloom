import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/event/create_event_state.dart';
import 'date_wheel_scroller.dart';
import 'clock_widget.dart';

const double pickerItemHeight = 45.0;

class DateTimeModal extends ConsumerStatefulWidget {
  const DateTimeModal({super.key});

  @override
  ConsumerState<DateTimeModal> createState() => _DateTimeModalState();
}

class _DateTimeModalState extends ConsumerState<DateTimeModal> {
  bool _isSelectingStart = true;

  late DateTime _startDate;
  late bool _startTimeTbd;
  DateTime? _endDate;
  bool _endTimeTbd = true;

  late int _selectedHour;
  bool _isAm = true;

  @override
  void initState() {
    super.initState();
    final state = ref.read(createEventProvider);
    final now = DateTime.now();
    _startDate = state.startDate ?? DateTime(now.year, now.month, now.day, 0, 0);
    _startTimeTbd = state.startTimeTbd;
    _endDate = state.endDate;
    _endTimeTbd = state.endTimeTbd;

    _updateClockFromState();
  }

  void _updateClockFromState() {
    final activeDate = _isSelectingStart
        ? _startDate
        : (_endDate ?? _startDate);
    _selectedHour = activeDate.hour % 12;
    if (_selectedHour == 0) _selectedHour = 12;
    _isAm = activeDate.hour < 12;
  }

  void _onSave() {
    final notifier = ref.read(createEventProvider.notifier);
    notifier.updateStartDate(_startDate);
    notifier.setStartTimeTbd(_startTimeTbd);
    notifier.updateEndDate(_endDate);
    notifier.setEndTimeTbd(_endTimeTbd);
    Navigator.pop(context);
  }

  void _onClearAll() {
    ref.read(createEventProvider.notifier).clearDates();
    Navigator.pop(context);
  }

  void _updateTime() {
    int hour = _selectedHour;
    if (!_isAm && hour < 12) hour += 12;
    if (_isAm && hour == 12) hour = 0;

    if (_isSelectingStart) {
      _startDate = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        hour,
        0,
      );
      _startTimeTbd = false;
    } else if (_endDate != null) {
      _endDate = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        hour,
        0,
      );
      _endTimeTbd = false;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, d MMM');

    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(color: Color(0xFF191B1D)),
      child: Column(
        children: [
          const SizedBox(height: 12), // space above the pull bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
            ), // Padding above the segmented view
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _onClearAll,
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ),
                const Text(
                  'Date & Time',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _onSave,
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Color(0xFF4A80F0),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 5),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            height: 80,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.07),
                              ),
                            ),
                            child: Stack(
                              children: [
                                // Background Slider (Bottom Layer)
                                AnimatedAlign(
                                  alignment: _isSelectingStart
                                      ? Alignment.centerLeft
                                      : Alignment.centerRight,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  child: FractionallySizedBox(
                                    widthFactor: 0.44,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.10,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                // Foreground Content (Top Layer)
                                Row(
                                  children: [
                                    _buildSegmentedItem(
                                      title: dateFormat.format(_startDate),
                                      subtitle: _startTimeTbd
                                          ? 'TBD'
                                          : DateFormat(
                                              'h a',
                                            ).format(_startDate).toLowerCase(),
                                      isActive: _isSelectingStart,
                                      onTap: () => setState(() {
                                        _isSelectingStart = true;
                                        _updateClockFromState();
                                      }),
                                    ),
                                    const SizedBox(width: 10),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Colors.white54,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    _buildSegmentedItem(
                                      title: _endDate != null
                                          ? dateFormat.format(_endDate!)
                                          : 'Optional',
                                      subtitle: _endDate == null
                                          ? 'End Date'
                                          : (_endTimeTbd
                                                ? 'TBD'
                                                : DateFormat('h a')
                                                      .format(_endDate!)
                                                      .toLowerCase()),
                                      isActive: !_isSelectingStart,
                                      onTap: () {
                                        if (_endDate == null) {
                                          setState(() {
                                            _endDate = _startDate.add(
                                              const Duration(hours: 2),
                                            );
                                            _endTimeTbd = false;
                                            _isSelectingStart = false;
                                            _updateClockFromState();
                                          });
                                        } else {
                                          setState(() {
                                            _isSelectingStart = false;
                                            _updateClockFromState();
                                          });
                                        }
                                      },
                                      showClear: _endDate != null,
                                      onClear: () {
                                        setState(() {
                                          _endDate = null;
                                          _endTimeTbd = true;
                                          _updateClockFromState();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(
                          height:
                              200.0, // Hard vertical boundary to kill overflow
                          width:
                              double.infinity, // Force full width for centering
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Align(
                                alignment: Alignment.center,
                                child: IgnorePointer(
                                  ignoring: true,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildSelectorBox(75),
                                      const SizedBox(width: 10),
                                      _buildSelectorBox(75),
                                      const SizedBox(width: 10),
                                      _buildSelectorBox(75),
                                    ],
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CustomDateWheelScroller(
                                    width: 75,
                                    itemHeight: pickerItemHeight,
                                    items: List.generate(
                                      31,
                                      (i) => (i + 1).toString().padLeft(2, '0'),
                                    ),
                                    initialIndex:
                                        (_isSelectingStart
                                            ? _startDate.day
                                            : (_endDate?.day ?? 1)) -
                                        1,
                                    onSelectedItemChanged: (i) {
                                      final day = i + 1;
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (mounted) {
                                              setState(() {
                                                if (_isSelectingStart) {
                                                  _startDate = DateTime(
                                                    _startDate.year,
                                                    _startDate.month,
                                                    day,
                                                    _startDate.hour,
                                                    0,
                                                  );
                                                } else if (_endDate != null) {
                                                  _endDate = DateTime(
                                                    _endDate!.year,
                                                    _endDate!.month,
                                                    day,
                                                    _endDate!.hour,
                                                    0,
                                                  );
                                                }
                                              });
                                            }
                                          });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  CustomDateWheelScroller(
                                    width: 75,
                                    itemHeight: pickerItemHeight,
                                    items: [
                                      'JAN',
                                      'FEB',
                                      'MAR',
                                      'APR',
                                      'MAY',
                                      'JUN',
                                      'JUL',
                                      'AUG',
                                      'SEP',
                                      'OCT',
                                      'NOV',
                                      'DEC',
                                    ],
                                    initialIndex:
                                        (_isSelectingStart
                                            ? _startDate.month
                                            : (_endDate?.month ?? 1)) -
                                        1,
                                    onSelectedItemChanged: (i) {
                                      final month = i + 1;
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (mounted) {
                                              setState(() {
                                                if (_isSelectingStart) {
                                                  _startDate = DateTime(
                                                    _startDate.year,
                                                    month,
                                                    _startDate.day,
                                                    _startDate.hour,
                                                    0,
                                                  );
                                                } else if (_endDate != null) {
                                                  _endDate = DateTime(
                                                    _endDate!.year,
                                                    month,
                                                    _endDate!.day,
                                                    _endDate!.hour,
                                                    0,
                                                  );
                                                }
                                              });
                                            }
                                          });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  CustomDateWheelScroller(
                                    width: 75,
                                    itemHeight: pickerItemHeight,
                                    items: List.generate(
                                      10,
                                      (i) =>
                                          (DateTime.now().year + i).toString(),
                                    ),
                                    initialIndex:
                                        (_isSelectingStart
                                            ? _startDate.year
                                            : (_endDate?.year ??
                                                  DateTime.now().year)) -
                                        DateTime.now().year,
                                    onSelectedItemChanged: (i) {
                                      final year = DateTime.now().year + i;
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (mounted) {
                                              setState(() {
                                                if (_isSelectingStart) {
                                                  _startDate = DateTime(
                                                    year,
                                                    _startDate.month,
                                                    _startDate.day,
                                                    _startDate.hour,
                                                    0,
                                                  );
                                                } else if (_endDate != null) {
                                                  _endDate = DateTime(
                                                    year,
                                                    _endDate!.month,
                                                    _endDate!.day,
                                                    _endDate!.hour,
                                                    0,
                                                  );
                                                }
                                              });
                                            }
                                          });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  'Time: ${_isSelectingStart ? (_startTimeTbd ? 'TBD' : DateFormat('h a').format(_startDate).toLowerCase()) : (_endDate == null ? 'TBD' : (_endTimeTbd ? 'TBD' : DateFormat('h a').format(_endDate!).toLowerCase()))}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                            ],
                          ),
                        ),

                        _buildAmPmToggle(),

                        CustomAnimatedClockWidget(
                          selectedHour: _selectedHour,
                          isTbd: _isSelectingStart
                              ? _startTimeTbd
                              : (_endDate == null || _endTimeTbd),
                          onHourSelected: (hour) {
                            setState(() {
                              _selectedHour = hour;
                              _updateTime();
                            });
                          },
                          onTbdReset: () {
                            setState(() {
                              if (_isSelectingStart) {
                                _startTimeTbd = true;
                              } else if (_endDate != null) {
                                _endTimeTbd = true;
                              }
                              _updateClockFromState();
                            });
                          },
                        ),
                      ],
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

  Widget _buildAmPmToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isAm = !_isAm;
          _updateTime();
        });
      },
      child: Container(
        height: 30,
        width: 120,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Stack(
          children: [
            // Sliding Pill
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              alignment: _isAm ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                width: 60,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            // AM Text
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 60,
                child: Center(
                  child: Text(
                    'AM',
                    style: TextStyle(
                      color: _isAm ? Colors.black : Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            // PM Text
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 60,
                child: Center(
                  child: Text(
                    'PM',
                    style: TextStyle(
                      color: !_isAm ? Colors.black : Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorBox(double width) {
    return Container(
      height: pickerItemHeight,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.5),
            width: 0.5,
          ),
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedItem({
    required String title,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
    bool showClear = false,
    VoidCallback? onClear,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.transparent, // Background handled by sliding block
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.54),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.54),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (showClear && onClear != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: onClear,
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.close,
                        color: Colors.black,
                        size: 16,
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
