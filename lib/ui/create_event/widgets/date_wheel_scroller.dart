import 'package:flutter/material.dart';

class CustomDateWheelScroller extends StatefulWidget {
  final List<String> items;
  final int initialIndex;
  final Function(int) onSelectedItemChanged;
  final double width;
  final double itemHeight;

  const CustomDateWheelScroller({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.onSelectedItemChanged,
    this.width = 60,
    this.itemHeight = 45,
  });

  @override
  State<CustomDateWheelScroller> createState() =>
      _CustomDateWheelScrollerState();
}

class _CustomDateWheelScrollerState extends State<CustomDateWheelScroller> {
  late FixedExtentScrollController _controller;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _controller = FixedExtentScrollController(initialItem: widget.initialIndex);
  }

  @override
  void didUpdateWidget(CustomDateWheelScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only jump if the provided index differs from our current selection
    // to avoid interrupting active scrolls or causing redundant jumps.
    if (widget.initialIndex != _selectedIndex &&
        widget.initialIndex >= 0 &&
        widget.initialIndex < widget.items.length) {
      _selectedIndex = widget.initialIndex;
      _controller.jumpToItem(widget.initialIndex);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Up Chevron
          Icon(
            Icons.keyboard_arrow_up,
            size: 20,
            color: Colors.white.withValues(
              alpha: _selectedIndex == 0 ? 0.3 : 0.6,
            ),
          ),

          SizedBox(
            height: widget.itemHeight * 3,
            child: ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: widget.itemHeight,
              squeeze: 1.0,
              diameterRatio: 10.0,
              offAxisFraction: 0.0,
              physics: const FixedExtentScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              onSelectedItemChanged: (index) {
                setState(() => _selectedIndex = index);
                widget.onSelectedItemChanged(index);
              },
              childDelegate: ListWheelChildLoopingListDelegate(
                children: List.generate(widget.items.length, (index) {
                  final isSelected = index == _selectedIndex;

                  return Center(
                    child: Text(
                      widget.items[index],
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                        fontSize: isSelected ? 16 : 15,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // Down Chevron
          Icon(
            Icons.keyboard_arrow_down,
            size: 15,
            color: Colors.white.withValues(
              alpha: _selectedIndex == widget.items.length - 1 ? 0.3 : 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
