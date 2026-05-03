import 'package:flutter/material.dart';

class EventSectionCard extends StatelessWidget {
  final IconData? headerIcon;
  final String? title;
  final Widget body;
  final Color? backgroundColor;

  const EventSectionCard({
    super.key,
    this.headerIcon,
    this.title,
    required this.body,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (headerIcon != null || title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (headerIcon != null) ...[
                        Icon(headerIcon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      if (title != null)
                        Text(
                          title!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, (headerIcon != null || title != null) ? 0 : 16, 16, 16),
            child: body,
          ),
        ],
      ),
    );
  }
}
