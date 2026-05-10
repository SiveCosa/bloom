import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BloomIconButton extends StatelessWidget {
  final IconData? icon;
  final String? iconPath;
  final VoidCallback? onTap;

  const BloomIconButton({
    super.key,
    this.icon,
    this.iconPath,
    this.onTap,
  }) : assert(icon != null || iconPath != null, 'Either icon or iconPath must be provided');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45,
        height: 35,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.07),
            width: 1,
          ),
        ),
        child: Center(
          child: iconPath != null
              ? SvgPicture.asset(
                  iconPath!,
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                )
              : Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
        ),
      ),
    );
  }
}
