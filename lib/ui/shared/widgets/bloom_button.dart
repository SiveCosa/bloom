import 'package:flutter/material.dart';

class BloomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final double? width;
  final Color? backgroundColor;
  final Color? textColor;
  final double borderRadius;
  final Widget? prefixIcon;
  final double fontSize;
  final FontWeight fontWeight;
  final double horizontalPadding;

  const BloomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.height = 48,
    this.width = double.infinity,
    this.backgroundColor = const Color(0xFF0086D8),
    this.textColor = Colors.white,
    this.borderRadius = 15,
    this.prefixIcon,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w600,
    this.horizontalPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          disabledBackgroundColor: backgroundColor?.withValues(alpha: 0.5),
        ),
        child: isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    textColor ?? Colors.white,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (prefixIcon != null) ...[
                    prefixIcon!,
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: fontWeight,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
