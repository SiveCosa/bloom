import 'dart:math';
import 'package:flutter/material.dart';

class CustomAnimatedClockWidget extends StatefulWidget {
  final int? selectedHour;
  final Function(int) onHourSelected;
  final Function()? onTbdReset;
  final bool isTbd;
  final double size;

  const CustomAnimatedClockWidget({
    super.key,
    required this.selectedHour,
    required this.onHourSelected,
    this.onTbdReset,
    this.isTbd = true,
    this.size = 220,
  });

  @override
  State<CustomAnimatedClockWidget> createState() =>
      _CustomAnimatedClockWidgetState();
}

class _CustomAnimatedClockWidgetState extends State<CustomAnimatedClockWidget> {
  double _currentAngle = 0;

  @override
  void didUpdateWidget(CustomAnimatedClockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedHour != null &&
        widget.selectedHour != oldWidget.selectedHour) {
      _calculateTargetAngle(widget.selectedHour!);
    }
  }

  void _calculateTargetAngle(int hour) {
    double targetAngle = (hour % 12) * (2 * pi / 12);
    double diff = (targetAngle - (_currentAngle % (2 * pi)));
    if (diff > pi) diff -= 2 * pi;
    if (diff < -pi) diff += 2 * pi;

    setState(() {
      _currentAngle += diff;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double radius = widget.size / 2;
    final double numberRadius = radius * 0.82; // Relative radius for numbers

    return Column(
      children: [
        GestureDetector(
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox;
            final center = box.size.center(Offset.zero);
            final touchPos = details.localPosition;
            final dx = touchPos.dx - center.dx;
            final dy = touchPos.dy - center.dy;

            final distance = sqrt(dx * dx + dy * dy);
            if (distance < (radius * 0.25)) {
              // Relative TBD area
              if (widget.onTbdReset != null) widget.onTbdReset!();
              return;
            }

            double angle = atan2(dy, dx) + pi / 2;
            if (angle < 0) angle += 2 * pi;

            int hour = ((angle / (2 * pi)) * 12).round();
            if (hour == 0) hour = 12;

            widget.onHourSelected(hour);
          },
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  painter: ClockNumbersPainter(
                    color: Colors.white,
                    fontWeight: FontWeight.normal,
                    numberRadius: numberRadius,
                  ),
                  size: Size(widget.size, widget.size),
                ),

                if (!widget.isTbd)
                  Stack(
                    children: [
                      CustomPaint(
                        painter: ClockSelectorPainter(
                          angle: _currentAngle - pi / 2,
                          radius: numberRadius,
                          selectorRadius:
                              (radius * 0.18) - 2, // 2dp gap from edge
                        ),
                        size: Size(widget.size, widget.size),
                      ),
                      ClipPath(
                        clipper: SelectorClipper(
                          angle: _currentAngle - pi / 2,
                          radius: numberRadius,
                          selectorRadius: (radius * 0.18) - 2,
                        ),
                        child: CustomPaint(
                          painter: ClockNumbersPainter(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            selectedHour: widget.selectedHour,
                            numberRadius: numberRadius,
                          ),
                          size: Size(widget.size, widget.size),
                        ),
                      ),
                    ],
                  ),

                Container(
                  width: widget.isTbd ? (radius * 0.4) : 8,
                  height: widget.isTbd ? (radius * 0.4) : 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: widget.isTbd
                      ? Text(
                          'TBD',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: radius * 0.12,
                            fontWeight: FontWeight.bold,
                          ),
                        )
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
  final double numberRadius;

  ClockNumbersPainter({
    required this.color,
    required this.fontWeight,
    required this.numberRadius,
    this.selectedHour,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final fontSize = size.width * 0.07; // Scaled font size

    for (int i = 0; i < 12; i++) {
      final hour = i + 1;
      final numberAngle = (hour * 30 - 90) * (pi / 180);
      final x = center.dx + numberRadius * cos(numberAngle);
      final y = center.dy + numberRadius * sin(numberAngle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '$hour',
          style: TextStyle(
            color: color,
            fontSize: fontSize,
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
      oldDelegate.selectedHour != selectedHour ||
      oldDelegate.numberRadius != numberRadius;
}

class ClockSelectorPainter extends CustomPainter {
  final double angle;
  final double radius;
  final double selectorRadius;

  ClockSelectorPainter({
    required this.angle,
    required this.radius,
    required this.selectorRadius,
  });

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
      canvas.drawCircle(endPoint, selectorRadius, whitePaint);
    }
  }

  @override
  bool shouldRepaint(covariant ClockSelectorPainter oldDelegate) =>
      oldDelegate.angle != angle ||
      oldDelegate.radius != radius ||
      oldDelegate.selectorRadius != selectorRadius;
}

class SelectorClipper extends CustomClipper<Path> {
  final double angle;
  final double radius;
  final double selectorRadius;

  SelectorClipper({
    required this.angle,
    required this.radius,
    required this.selectorRadius,
  });

  @override
  Path getClip(Size size) {
    final center = size.center(Offset.zero);
    final endPoint = Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );
    return Path()
      ..addOval(Rect.fromCircle(center: endPoint, radius: selectorRadius));
  }

  @override
  bool shouldReclip(SelectorClipper oldClipper) =>
      oldClipper.angle != angle ||
      oldClipper.radius != radius ||
      oldClipper.selectorRadius != selectorRadius;
}
