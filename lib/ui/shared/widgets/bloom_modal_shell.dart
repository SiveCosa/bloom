import 'package:flutter/material.dart';

class BloomModalShell extends StatelessWidget {
  final String title;
  final Widget child;
  final double? height;
  final bool useSafeArea;
  final bool hasDragHandle;

  // Left action (e.g. Cancel / Clear)
  final String? leftActionText;
  final VoidCallback? onLeftActionPressed;
  final Color? leftActionColor;

  // Right action (e.g. Save)
  final String? rightActionText;
  final VoidCallback? onRightActionPressed;
  final Color? rightActionColor;

  final double headerBottomSpacing;

  final EdgeInsetsGeometry? contentPadding;

  const BloomModalShell({
    super.key,
    required this.title,
    required this.child,
    this.height,
    this.useSafeArea = false,
    this.hasDragHandle = true,
    this.leftActionText,
    this.onLeftActionPressed,
    this.leftActionColor,
    this.rightActionText,
    this.onRightActionPressed,
    this.rightActionColor,
    this.headerBottomSpacing = 20,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final themeBackground = const Color(0xFF191B1D);
    final borderRadiusVal = const BorderRadius.vertical(top: Radius.circular(25));

    Widget content = Container(
      width: double.infinity,
      height: height,
      padding: contentPadding,
      decoration: BoxDecoration(
        color: themeBackground,
        borderRadius: borderRadiusVal,
      ),
      child: Column(
        mainAxisSize: height == null ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (hasDragHandle) ...[
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ] else ...[
            const SizedBox(height: 20),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (leftActionText != null && onLeftActionPressed != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onLeftActionPressed,
                      child: Text(
                        leftActionText!,
                        style: TextStyle(
                          color: leftActionColor ?? Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (rightActionText != null && onRightActionPressed != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onRightActionPressed,
                      child: Text(
                        rightActionText!,
                        style: TextStyle(
                          color: rightActionColor ?? const Color(0xFF6C8EEF),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: headerBottomSpacing),

          if (height != null)
            Expanded(child: child)
          else
            child,
        ],
      ),
    );

    if (useSafeArea) {
      content = SafeArea(
        top: true,
        bottom: false,
        child: ClipRRect(
          borderRadius: borderRadiusVal,
          child: content,
        ),
      );
    }

    return content;
  }
}
