import 'package:flutter/material.dart';
import 'dart:math' as math;

class StackedPosters extends StatelessWidget {
  const StackedPosters({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      width: double.infinity,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Poster 1 (Far Left)
          _buildPosterCard(
            assetPath: 'assets/images/home-posters/poster_1.webp',
            height: 60,
            width: 44,
            angle: -20 * (math.pi / 180),
            offset: const Offset(-85, 15),
          ),
          // Poster 5 (Far Right)
          _buildPosterCard(
            assetPath: 'assets/images/home-posters/poster_5.webp',
            height: 60,
            width: 44,
            angle: 20 * (math.pi / 180),
            offset: const Offset(85, 15),
          ),
          // Poster 2 (Mid Left)
          _buildPosterCard(
            assetPath: 'assets/images/home-posters/poster_2.webp',
            height: 80,
            width: 58,
            angle: -10 * (math.pi / 180),
            offset: const Offset(-45, 8),
          ),
          // Poster 4 (Mid Right)
          _buildPosterCard(
            assetPath: 'assets/images/home-posters/poster_4.webp',
            height: 80,
            width: 58,
            angle: 10 * (math.pi / 180),
            offset: const Offset(45, 8),
          ),
          // Poster 3 (Center - Front)
          _buildPosterCard(
            assetPath: 'assets/images/home-posters/poster_3.webp',
            height: 100,
            width: 72,
            angle: 0,
            offset: Offset.zero,
            isFront: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPosterCard({
    required String assetPath,
    required double height,
    required double width,
    required double angle,
    required Offset offset,
    bool isFront = false,
  }) {
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF0B0E12), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isFront ? 0.4 : 0.2),
                blurRadius: isFront ? 12 : 6,
                spreadRadius: isFront ? 1 : 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.white.withValues(alpha: 0.05),
                child: const Icon(Icons.broken_image, color: Colors.white10),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
