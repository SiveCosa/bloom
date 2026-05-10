import 'package:flutter/material.dart';
import '../../create_event/widgets/date_wheel_scroller.dart';

class MonthYearPickerModal extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onDateSelected;

  const MonthYearPickerModal({
    super.key,
    required this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<MonthYearPickerModal> createState() => _MonthYearPickerModalState();
}

class _MonthYearPickerModalState extends State<MonthYearPickerModal> {
  late int _selectedMonth;
  late int _selectedYear;

  final List<String> _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
  ];

  late List<String> _years;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialDate.month;
    _selectedYear = widget.initialDate.year;
    
    // Generate years from 5 years ago to 10 years in the future
    final currentYear = DateTime.now().year;
    _years = List.generate(20, (i) => (currentYear - 5 + i).toString());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350,
      decoration: const BoxDecoration(
        color: Color(0xFF191B1D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
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
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      widget.onDateSelected(DateTime.now());
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Today',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const Text(
                  'Select Date',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      widget.onDateSelected(
                        DateTime(_selectedYear, _selectedMonth),
                      );
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Go now',
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
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomDateWheelScroller(
                width: 100,
                items: _months,
                initialIndex: _selectedMonth - 1,
                onSelectedItemChanged: (index) {
                  setState(() {
                    _selectedMonth = index + 1;
                  });
                },
              ),
              const SizedBox(width: 20),
              CustomDateWheelScroller(
                width: 100,
                items: _years,
                initialIndex: _years.indexOf(_selectedYear.toString()),
                onSelectedItemChanged: (index) {
                  setState(() {
                    _selectedYear = int.parse(_years[index]);
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
