import 'package:flutter/material.dart';

class NavigationTile extends StatelessWidget {
  final VoidCallback onTap;
  final Widget icon;
  final Color iconBackgroundColor;
  final String title;
  final Widget subtitle;

  const NavigationTile({
    super.key,
    required this.onTap,
    required this.icon,
    required this.iconBackgroundColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: iconBackgroundColor,
                child: icon,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    subtitle,
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.3),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
