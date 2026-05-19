import 'package:flutter/material.dart';

class ContainerPlaceholder extends StatelessWidget {
  final double width;
  final double height;

  const ContainerPlaceholder({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
