import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:bloom/domain/discover/discover_providers.dart';
import 'package:bloom/domain/navigation/navigation_providers.dart';

class DiscoverMoreWidget extends ConsumerWidget {
  const DiscoverMoreWidget({super.key});

  void _onCategoryTap(WidgetRef ref, String category) {
    ref.read(mainShellIndexProvider.notifier).setIndex(1);
    ref.read(discoverCategoryFilterProvider.notifier).setCategory(category);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Cant find what you're looking for?",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "Discover More",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 5,
              runSpacing: 5,
              children: [
                _buildPill(
                  ref,
                  'Community',
                  'assets/icons/discover/community_icon.svg',
                  const Color(0xFF38BDF8),
                ),
                _buildPill(
                  ref,
                  'Music',
                  'assets/icons/discover/music_icon.svg',
                  const Color(0xFFEC4899),
                ),
                _buildPill(
                  ref,
                  'Film',
                  'assets/icons/discover/movie_icon.svg',
                  const Color(0xFFEF4444),
                ),
                _buildPill(
                  ref,
                  'Arts',
                  'assets/icons/discover/art_icon.svg',
                  const Color(0xFFFBBF24),
                ),
                _buildPill(
                  ref,
                  'Fitness',
                  'assets/icons/discover/fitness_icon.svg',
                  const Color(0xFF22C55E),
                ),
                _buildPill(
                  ref,
                  'Food',
                  'assets/icons/discover/food_icon.svg',
                  const Color(0xFFF97316),
                ),
                _buildPill(
                  ref,
                  'Education',
                  'assets/icons/discover/education_icon.svg',
                  const Color(0xFF6366F1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(
    WidgetRef ref,
    String label,
    String iconAsset,
    Color iconColor,
  ) {
    return GestureDetector(
      onTap: () => _onCategoryTap(ref, label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1F222A), // Dark grey background matching UI
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              iconAsset,
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
