import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/event/create_event_state.dart';

class PosterModule extends ConsumerWidget {
  final VoidCallback onEditPoster;

  const PosterModule({
    super.key,
    required this.onEditPoster,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(createEventProvider);
    final aspectRatio = state.visuals.aspectRatio;
    final posterUrl = state.visuals.posterUrl;

    final screenWidth = MediaQuery.of(context).size.width;

    final targetWidth = screenWidth * 0.7;
    final targetHeight = targetWidth / aspectRatio;

    return Column(
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            width: targetWidth,
            height: targetHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withValues(alpha: 0.1),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              image: posterUrl != null
                  ? DecorationImage(
                      image: NetworkImage(posterUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: GestureDetector(
              onTap: (posterUrl == null && state.customPosterBytes == null)
                  ? onEditPoster
                  : null,
              child: Stack(
                children: [
                  if (state.customPosterBytes != null)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          state.customPosterBytes!,
                          key: ValueKey(state.customPosterBytes),
                          fit: BoxFit.cover,
                          cacheWidth: 800,
                        ),
                      ),
                    ),
                  if (posterUrl == null && state.customPosterBytes == null && !state.isGeneratingPoster)
                    const Center(
                      child: Icon(Icons.image, color: Colors.white24, size: 48),
                    ),
                  if (state.isGeneratingPoster)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    ),
                // Aspect Ratio Toggle (Bottom Right)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => ref.read(createEventProvider.notifier).toggleAspectRatio(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white10),
                      ),
                      child: AnimatedRotation(
                        duration: const Duration(milliseconds: 400),
                        turns: aspectRatio == 1.0 ? 0 : 0.25,
                        child: const Icon(
                          Icons.crop_free,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!state.isGeneratingPoster)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: GestureDetector(
                      onTap: onEditPoster,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_outlined, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Edit poster',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
],
);
}
}
