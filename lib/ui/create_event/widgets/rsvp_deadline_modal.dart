import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/event/create_event_state.dart';
import '../../shared/widgets/bloom_modal_shell.dart';
import 'date_wheel_scroller.dart';

class RSVPDeadlineModal extends ConsumerStatefulWidget {
  const RSVPDeadlineModal({super.key});

  @override
  ConsumerState<RSVPDeadlineModal> createState() => _RSVPDeadlineModalState();
}

class _RSVPDeadlineModalState extends ConsumerState<RSVPDeadlineModal> {
  late DateTime _selectedDate;
  late List<String> _selectedReminders;

  @override
  void initState() {
    super.initState();
    final state = ref.read(createEventProvider);
    _selectedDate = state.audience.rsvpDeadline ?? DateTime.now();
    _selectedReminders = List<String>.from(state.rsvpReminders);
  }

  String? _getErrorMessage() {
    final state = ref.read(createEventProvider);
    final finalDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      23,
      59,
    );

    final now = DateTime.now();
    if (finalDate.isBefore(now)) {
      return 'RSVP deadline must be in the future.';
    }

    final startDate = state.timing.startDate;
    if (startDate != null && finalDate.isAfter(startDate)) {
      return 'You can\'t set RSVP date after the event day.';
    }

    return null;
  }

  void _onSave() {
    final errorMessage = _getErrorMessage();
    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return;
    }

    final notifier = ref.read(createEventProvider.notifier);
    final finalDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      23,
      59,
    );
    
    notifier.updateRSVPDeadline(finalDate);
    notifier.updateRSVPReminders(_selectedReminders);
    Navigator.pop(context);
  }

  void _onClear() {
    ref.read(createEventProvider.notifier).clearRSVPDeadline();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, d MMM yyyy');

    return BloomModalShell(
      title: 'RSVP Deadline',
      height: MediaQuery.of(context).size.height,
      useSafeArea: true,
      leftActionText: 'Clear',
      onLeftActionPressed: _onClear,
      rightActionText: 'Save',
      onRightActionPressed: _onSave,
      child: Column(
        children: [
          const SizedBox(height: 30),

          // Selected Date Display
          Text(
            dateFormat.format(_selectedDate),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'at 11:59 PM',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 40),

          // Date Scrollers
          Stack(
            alignment: Alignment.center,
            children: [
              // Selector Boxes Behind
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSelectorBox(75),
                  const SizedBox(width: 10),
                  _buildSelectorBox(75),
                  const SizedBox(width: 10),
                  _buildSelectorBox(75),
                ],
              ),
              // Scrollers on Top
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Day
                  CustomDateWheelScroller(
                    width: 75,
                    items: List.generate(31, (i) => (i + 1).toString().padLeft(2, '0')),
                    initialIndex: (_selectedDate.day - 1).clamp(0, 30),
                    onSelectedItemChanged: (i) {
                      setState(() {
                        // DateTime handles normalization (e.g. Feb 31 -> Mar 3)
                        _selectedDate = DateTime(
                          _selectedDate.year,
                          _selectedDate.month,
                          i + 1,
                        );
                      });
                    },
                  ),
                  const SizedBox(width: 10),
                  CustomDateWheelScroller(
                    width: 75,
                    items: const [
                      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
                      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
                    ],
                    initialIndex: (_selectedDate.month - 1).clamp(0, 11),
                    onSelectedItemChanged: (i) {
                      setState(() {
                        _selectedDate = DateTime(
                          _selectedDate.year,
                          i + 1,
                          _selectedDate.day,
                        );
                      });
                    },
                  ),
                  const SizedBox(width: 10),
                  // Year
                  Builder(
                    builder: (context) {
                      final currentYear = DateTime.now().year;
                      // Ensure we include at least the selected year and current year
                      final startYear = _selectedDate.year < currentYear 
                          ? _selectedDate.year 
                          : currentYear;
                      final yearItems = List.generate(20, (i) => (startYear + i).toString());
                      final yearIndex = (_selectedDate.year - startYear).clamp(0, yearItems.length - 1);

                      return CustomDateWheelScroller(
                        width: 75,
                        items: yearItems,
                        initialIndex: yearIndex,
                        onSelectedItemChanged: (i) {
                          setState(() {
                            _selectedDate = DateTime(
                              startYear + i,
                              _selectedDate.month,
                              _selectedDate.day,
                            );
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),
          if (_getErrorMessage() != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _getErrorMessage()!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          const SizedBox(height: 40),
          const Divider(color: Colors.white12, indent: 20, endIndent: 20),
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Set Reminder Button (Now at top of section)
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (!_selectedReminders.contains(val)) {
                      setState(() {
                        _selectedReminders.add(val);
                      });
                    }
                  },
                  offset: const Offset(0, 50), // Open below the pill
                  color: const Color(0xFF1E2128),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (context) => [
                    _buildPopupItem('Week before'),
                    _buildPopupItem('Day before'),
                    _buildPopupItem('The day of'),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Set Reminder',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down, color: Colors.white.withValues(alpha: 0.5), size: 16),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                
                if (_selectedReminders.isNotEmpty)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedReminders.map((reminder) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              reminder,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedReminders.remove(reminder);
                                });
                              },
                              child: const Icon(Icons.close, color: Colors.white70, size: 14),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value) {
    return PopupMenuItem<String>(
      value: value,
      child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
    );
  }

  Widget _buildSelectorBox(double width) {
    return Container(
      height: 45,
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
}
