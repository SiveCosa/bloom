import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../../core/theme/app_theme.dart';

class GradientTopBar extends StatelessWidget {
  final double height;
  final bool showDarkOverlay;
  final double darkOverlayHeight;

  const GradientTopBar({
    super.key,
    this.height = 100,
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
            child: Container(
              height: height,
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
        if (showDarkOverlay)
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: darkOverlayHeight,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x000B0E12), Color(0xFF0B0E12)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
