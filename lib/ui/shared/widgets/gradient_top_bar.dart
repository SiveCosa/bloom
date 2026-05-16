import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../../core/theme/app_theme.dart';

class GradientTopBar extends StatelessWidget {
  final double height;
  final bool showDarkOverlay;
  final double darkOverlayHeight;

  const GradientTopBar({
    super.key,
    this.height = 160,
    this.showDarkOverlay = false,
    this.darkOverlayHeight = 265,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 80.0, sigmaY: 80.0),
            child: ShaderMask(
              shaderCallback: (rect) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.black, Colors.transparent],
                  stops: [
                    0.0,
                    0.5,
                    1.0,
                  ], // Start fading much earlier (at 20%) for a massive falloff
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: Container(
                height: height + 0, // Extend beyond the requested height
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppTheme.coreGradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.topRight,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showDarkOverlay)
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height:
                  darkOverlayHeight + 30, // Extend beyond the requested height
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.2, 0.5, 0.8, 1.0],
                  colors: [
                    Color(0x000B0E12),
                    Color(0x440B0E12),
                    Color(0x990B0E12),
                    Color(0xFF0B0E12),
                    Color(0xFF0B0E12), // Stays solid until the end
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
