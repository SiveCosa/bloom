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
                // Layer 1: Base Text (Always Visible White Numbers)
                CustomPaint(
                  painter: ClockNumbersPainter(
                    color: Colors.white,
                    fontWeight: FontWeight.normal,
                  ),
                  size: const Size(240, 240),
                ),

                // Layer 2 & 3: Selector and Clipped Black Text
                if (!widget.isTbd)
                  Stack(
                    children: [
                      // Layer 2: The Selector (White Arm and Circle)
                      CustomPaint(
                        painter: ClockSelectorPainter(
                          angle: _currentAngle - pi / 2,
                          radius: 100.0,
                        ),
                        size: const Size(240, 240),
                      ),
                      // Layer 3: The Black Text Mask (Clipped)
                      ClipPath(
                        clipper: SelectorClipper(
                          angle: _currentAngle - pi / 2,
                          radius: 100.0,
                        ),
                        child: CustomPaint(
                          painter: ClockNumbersPainter(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            selectedHour: widget.selectedHour,
                          ),
                          size: const Size(240, 240),
                        ),
                      ),
                    ],
                  ),

                // Center Anchor / TBD Button
                Container(
                  width: widget.isTbd ? 40 : 8,
                  height: widget.isTbd ? 40 : 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: widget.isTbd 
                    ? const Text('TBD', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold))
                    : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ClockNumbersPainter extends CustomPainter {
  final Color color;
  final FontWeight fontWeight;
  final int? selectedHour;

  ClockNumbersPainter({
    required this.color,
    required this.fontWeight,
    this.selectedHour,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    for (int i = 0; i < 12; i++) {
      final hour = i + 1;
      final numberAngle = (hour * 30 - 90) * (pi / 180);
      const numberRadius = 100.0;
      final x = center.dx + numberRadius * cos(numberAngle);
      final y = center.dy + numberRadius * sin(numberAngle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '$hour',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: selectedHour == hour ? FontWeight.bold : fontWeight,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ClockNumbersPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.fontWeight != fontWeight ||
      oldDelegate.selectedHour != selectedHour;
}

class ClockSelectorPainter extends CustomPainter {
  final double angle;
  final double radius;

  ClockSelectorPainter({required this.angle, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final endPoint = Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );

    final whitePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    if (radius > 2) {
      canvas.drawLine(center, endPoint, whitePaint);
      canvas.drawCircle(endPoint, 16, whitePaint);
    }
  }

  @override
  bool shouldRepaint(covariant ClockSelectorPainter oldDelegate) =>
      oldDelegate.angle != angle || oldDelegate.radius != radius;
}

class SelectorClipper extends CustomClipper<Path> {
  final double angle;
  final double radius;

  SelectorClipper({required this.angle, required this.radius});

  @override
  Path getClip(Size size) {
    final center = size.center(Offset.zero);
    final endPoint = Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );
    return Path()..addOval(Rect.fromCircle(center: endPoint, radius: 16));
  }

  @override
  bool shouldReclip(SelectorClipper oldClipper) =>
      oldClipper.angle != angle || oldClipper.radius != radius;
}
