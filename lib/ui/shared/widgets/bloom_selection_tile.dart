import 'package:flutter/material.dart';

class BloomSelectionTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final double verticalPadding;
  final bool useSolidCheck;

  const BloomSelectionTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.verticalPadding = 16.0,
    this.useSolidCheck = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        child: Row(
          children: [
            if (leading != null) ...[
              SizedBox(width: 44, height: 44, child: Center(child: leading)),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildCheckIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckIndicator() {
    if (useSolidCheck) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
          color: isSelected ? Colors.white : Colors.transparent,
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.black, size: 16)
            : null,
      );
    } else {
      if (isSelected) {
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Center(
            child: Icon(Icons.check, color: Colors.white, size: 18),
          ),
        );
      } else {
        return const SizedBox(width: 28, height: 28);
      }
    }
  }
}
