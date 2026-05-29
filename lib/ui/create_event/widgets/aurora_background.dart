import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/event/create_event_state.dart';

class AuroraBackground extends ConsumerWidget {
  final List<Color>? colors;
  final bool showDarkOverlay;

  const AuroraBackground({
    super.key,
    this.colors,
    this.showDarkOverlay = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Color> auroraColors = colors ?? ref.watch(
      createEventProvider.select((state) => state.auroraColors),
    );

    final displayColors = auroraColors.isNotEmpty 
        ? auroraColors 
        : CreateEventState.defaultAuroraColors;

    return Stack(
      children: [
        Positioned.fill(
          child: Stack(
            children: [
              Container(color: const Color(0xFF0B0E12)),
              
              Positioned(
                top: -300 + 25,
                left: -300 + 25,
                child: _AuroraBlob(color: displayColors[0]),
              ),
              
              Positioned(
                top: -300 + 35,
                right: -300 + 20,
                child: _AuroraBlob(color: displayColors[1 % displayColors.length]),
              ),
              
              Positioned(
                bottom: -300 + 30,
                left: -300 + 30,
                child: _AuroraBlob(color: displayColors[2 % displayColors.length]),
              ),
              
              Positioned(
                bottom: -300 + 20,
                right: -300 + 35,
                child: _AuroraBlob(color: displayColors[3 % displayColors.length]),
              ),
              
              // Removed BackdropFilter for performance. 
              // The smooth RadialGradients in _AuroraBlob provide the soft look for free.
              
              if (showDarkOverlay)
                Positioned.fill(
                  child: Container(color: Colors.black.withValues(alpha: 0.2)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuroraBlob extends StatelessWidget {
  final Color color;

  const _AuroraBlob({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1200,
      height: 1200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.5),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}
