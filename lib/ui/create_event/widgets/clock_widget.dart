import 'dart:math';
import 'package:flutter/material.dart';

class CustomAnimatedClockWidget extends StatefulWidget {
  final int? selectedHour;
  final Function(int) onHourSelected;
  final Function()? onTbdReset;
  final bool isTbd;

  const CustomAnimatedClockWidget({
    super.key,
    required this.selectedHour,
    required this.onHourSelected,
    this.onTbdReset,
    this.isTbd = true,
  });

  @override
  State<CustomAnimatedClockWidget> createState() => _CustomAnimatedClockWidgetState();
}

class _CustomAnimatedClockWidgetState extends State<CustomAnimatedClockWidget> {
  double _currentAngle = 0;

  @override
  void didUpdateWidget(CustomAnimatedClockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedHour != null && widget.selectedHour != oldWidget.selectedHour) {
      _calculateTargetAngle(widget.selectedHour!);
    }
  }

  void _calculateTargetAngle(int hour) {
    // Map hour to angle (12 = 0, 1 = 30 deg, etc.)
    double targetAngle = (hour % 12) * (2 * pi / 12);
    
    // Shortest rotation path logic
    double diff = (targetAngle - (_currentAngle % (2 * pi)));
    if (diff > pi) diff -= 2 * pi;
    if (diff < -pi) diff += 2 * pi;
    
    setState(() {
      _currentAngle += diff;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Clock Face
        GestureDetector(
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox;
            final center = box.size.center(Offset.zero);
            final touchPos = details.localPosition;
            final dx = touchPos.dx - center.dx;
            final dy = touchPos.dy - center.dy;
            
            // Calculate distance from center to check if "TBD" area was clicked
            final distance = sqrt(dx * dx + dy * dy);
            if (distance < 25) {
              if (widget.onTbdReset != null) widget.onTbdReset!();
              return;
            }

            // Calculate angle for numbers
            double angle = atan2(dy, dx) + pi / 2;
            if (angle < 0) angle += 2 * pi;
            
            // Map angle to hour
            int hour = ((angle / (2 * pi)) * 12).round();
            if (hour == 0) hour = 12;
            
            widget.onHourSelected(hour);
          },
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Clock Arm with Animation
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: widget.isTbd ? 0.0 : 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  builder: (context, factor, child) {
                    if (factor == 0 && widget.isTbd) return const SizedBox.shrink();
                    
                    return TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: _currentAngle, end: _currentAngle),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubic,
                      builder: (context, angle, child) {
                        return CustomPaint(
                          painter: ClockArmPainter(angle - pi/2, 100.0 * factor),
                          size: const Size(240, 240),
                        );
                      },
                    );
                  },
                ),

                // Clock Numbers (Rendered LAST for Z-index visibility)
                ...List.generate(12, (index) {
                  final hour = index + 1;
                  final angle = (hour * 30 - 90) * (pi / 180);
                  const radius = 100.0;
                  final x = radius * cos(angle);
                  final y = radius * sin(angle);
                  
                  final isSelected = widget.selectedHour == hour && !widget.isTbd;

                  return Transform.translate(
                    offset: Offset(x, y),
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      child: Text(
                        '$hour',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),

                // Center TBD Button / Anchor
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: widget.isTbd ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  builder: (context, tbdFactor, child) {
                    final size = 8.0 + (32.0 * tbdFactor); // From 8 to 40
                    return Container(
                      width: size,
                      height: size,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF499E),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: tbdFactor > 0.8 
                        ? const Text('TBD', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
                        : null,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ClockArmPainter extends CustomPainter {
  final double angle;
  final double radius;

  ClockArmPainter(this.angle, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    if (radius < 2) return;
    
    final center = size.center(Offset.zero);
    final endPoint = Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );

    final linePaint = Paint()
      ..color = const Color(0xFFFF499E)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Draw the arm line
    canvas.drawLine(center, endPoint, linePaint);

    // Draw the pink circle at the end
    final circlePaint = Paint()
      ..color = const Color(0xFFFF499E)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(endPoint, 16, circlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
