import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Spinner using the same blue as [BloomButton] / [AppTheme.primaryButton].
class BloomLoadingIndicator extends StatelessWidget {
  final double size;
  final double strokeWidth;

  const BloomLoadingIndicator({
    super.key,
    this.size = 32,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryButton),
      ),
    );
  }
}