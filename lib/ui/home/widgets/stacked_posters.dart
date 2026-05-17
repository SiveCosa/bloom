import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/firebase_provider.dart';
import 'dart:math' as math;

final homePostersUrlsProvider = FutureProvider<List<String>>((ref) async {
  ref.keepAlive();
  final storage = ref.read(storageProvider);
  final List<String> urls = [];
  
  for (int i = 1; i <= 5; i++) {
    try {
      final refPath = storage.ref('/posters/home-posters/poster_$i.webp');
      final url = await refPath.getDownloadURL();
      urls.add(url);
    } catch (e) {
      debugPrint('Error fetching poster $i: $e');
      urls.add(''); 
    }
  }
  return urls;
});

class StackedPosters extends ConsumerWidget {
  const StackedPosters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlsAsync = ref.watch(homePostersUrlsProvider);

    return urlsAsync.when(
      data: (urls) => _buildStack(urls),
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(color: Colors.white24)),
      ),
      error: (err, stack) => const SizedBox(
        height: 200,
        child: Center(child: Icon(Icons.error_outline, color: Colors.white24)),
      ),
    );
  }

  Widget _buildStack(List<String> urls) {
    return Container(
      height: 140,
      width: double.infinity,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Poster 1 (Far Left)
          if (urls.isNotEmpty && urls[0].isNotEmpty)
            _buildPosterCard(
              url: urls[0],
              height: 60,
              width: 44,
              angle: -20 * (math.pi / 180),
              offset: const Offset(-85, 15),
            ),
          // Poster 5 (Far Right)
          if (urls.length > 4 && urls[4].isNotEmpty)
            _buildPosterCard(
              url: urls[4],
              height: 60,
              width: 44,
              angle: 20 * (math.pi / 180),
              offset: const Offset(85, 15),
            ),
          // Poster 2 (Mid Left)
          if (urls.length > 1 && urls[1].isNotEmpty)
            _buildPosterCard(
              url: urls[1],
              height: 80,
              width: 58,
              angle: -10 * (math.pi / 180),
              offset: const Offset(-45, 8),
            ),
          // Poster 4 (Mid Right)
          if (urls.length > 3 && urls[3].isNotEmpty)
            _buildPosterCard(
              url: urls[3],
              height: 80,
              width: 58,
              angle: 10 * (math.pi / 180),
              offset: const Offset(45, 8),
            ),
          // Poster 3 (Center - Front)
          if (urls.length > 2 && urls[2].isNotEmpty)
            _buildPosterCard(
              url: urls[2],
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
    required String url,
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
            border: Border.all(
              color: const Color(0xFF0B0E12),
              width: 1.5,
            ),
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
              child: Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.white.withValues(alpha: 0.05),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white10,
                        ),
                      ),
                    ),
                  );
                },
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
