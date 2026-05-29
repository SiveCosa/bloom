import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:bloom/domain/event/event.dart';

class EventMapCard extends StatefulWidget {
  final Event event;
  final Color themeColor;

  const EventMapCard({
    super.key,
    required this.event,
    required this.themeColor,
  });

  @override
  State<EventMapCard> createState() => _EventMapCardState();
}

class _EventMapCardState extends State<EventMapCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Uint8List? _mapImageBytes;
  bool _isLoadingMap = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _fetchStaticMap();
  }

  @override
  void didUpdateWidget(covariant EventMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.location?.latitude != widget.event.location?.latitude ||
        oldWidget.event.location?.longitude !=
            widget.event.location?.longitude ||
        oldWidget.themeColor != widget.themeColor) {
      _fetchStaticMap();
    }
  }

  Future<void> _fetchStaticMap() async {
    final location = widget.event.location;
    // Missing lat/lng fallback gracefully handles incomplete locations
    if (location == null) {
      if (mounted) {
        setState(() => _isLoadingMap = false);
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingMap = true;
    });

    try {
      final hexColor = widget.themeColor
          .toARGB32()
          .toRadixString(16)
          .padLeft(8, '0')
          .substring(2)
          .toUpperCase();

      final result =
          await FirebaseFunctions.instanceFor(
            region: 'africa-south1',
          ).httpsCallable('googleMapsProxy').call({
            'endpoint': 'staticmap',
            'params': {
              'center': '${location.latitude},${location.longitude}',
              'zoom': 15,
              'size': '600x300',
              'scale': 2,
              'color': hexColor,
            },
          });

      if (!mounted) return;

      final data = result.data as Map<String, dynamic>;
      if (data['status'] == 'OK' && data['image'] != null) {
        final decodedBytes = base64Decode(data['image']);
        setState(() {
          _mapImageBytes = decodedBytes;
          _isLoadingMap = false;
        });
      } else {
        debugPrint('Google Maps Proxy Static Map error: ${data['status']}');
        setState(() {
          _isLoadingMap = false;
        });
      }
    } catch (e) {
      debugPrint('Exception fetching static map: $e');
      if (mounted) {
        setState(() {
          _isLoadingMap = false;
        });
      }
    }
  }

  Future<void> _launchMap(double lat, double lng, String label) async {
    final String appleUri = 'maps://?q=$lat,$lng';
    final String fallbackUri =
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

    try {
      final bool launched = await launchUrl(Uri.parse(appleUri));
      if (!launched) {
        await launchUrl(
          Uri.parse(fallbackUri),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      debugPrint('Error launching map: $e');
      await launchUrl(
        Uri.parse(fallbackUri),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Widget _buildMapBackground() {
    if (_isLoadingMap) {
      return const _MapShimmer();
    }

    if (_mapImageBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _mapImageBytes!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _MapGridPainter(
            pulseValue: _controller.value,
            themeColor: widget.themeColor,
          ),
          child: Container(),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.event.location == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        if (widget.event.location != null) {
          _launchMap(
            widget.event.location!.latitude,
            widget.event.location!.longitude,
            widget.event.location!.displayName,
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 2.1,
                child: Container(
                  color: const Color(0xFF0F1113),
                  child: Stack(
                    children: [
                      // Static Map Background / Shimmer / Fallback Custom Paint Grid
                      Positioned.fill(child: _buildMapBackground()),

                      if (widget.event.location != null)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 0.5,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.navigation_outlined,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Navigate',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 20),
                child: Column(
                  children: [
                    Text(
                      widget.event.location!.displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.event.location!.formattedAddress,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  final double pulseValue;
  final Color themeColor;

  _MapGridPainter({required this.pulseValue, required this.themeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    paint.color = Colors.white.withValues(alpha: 0.05);
    const double gridSize = 25.0;
    for (double i = 0; i < size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // Draw some stylized neon roads/streets
    paint.strokeWidth = 2.0;
    paint.color = themeColor.withValues(alpha: 0.12);

    // Main horizontal road crossing center
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);
    // Main vertical road crossing center
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      paint,
    );

    // Some diagonal roads
    paint.strokeWidth = 1.0;
    paint.color = themeColor.withValues(alpha: 0.06);
    canvas.drawLine(Offset(0, 0), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), paint);

    // Draw concentric radar-like circles around the event center
    paint.style = PaintingStyle.stroke;
    for (int r = 1; r <= 3; r++) {
      final double radius = r * 45.0;
      paint.color = themeColor.withValues(alpha: 0.08 / r);
      canvas.drawCircle(center, radius, paint);
    }

    // Pulse Circle: expanding out
    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = themeColor.withValues(alpha: (0.45 * (1.0 - pulseValue)))
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 15.0 + (pulseValue * 65.0), pulsePaint);

    final pulseFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = themeColor.withValues(alpha: (0.12 * (1.0 - pulseValue)));
    canvas.drawCircle(center, 15.0 + (pulseValue * 65.0), pulseFillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MapShimmer extends StatefulWidget {
  const _MapShimmer();

  @override
  State<_MapShimmer> createState() => _MapShimmerState();
}

class _MapShimmerState extends State<_MapShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF15181B),
                Color.lerp(
                  const Color(0xFF15181B),
                  const Color(0xFF25292E),
                  _shimmerController.value,
                )!,
                const Color(0xFF15181B),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Center(
            child: Opacity(
              opacity: 0.5,
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
