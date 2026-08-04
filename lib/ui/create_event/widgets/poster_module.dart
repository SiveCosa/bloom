import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/event/create_event_state.dart';
import 'dart:io';

class PosterModule extends ConsumerWidget {
  final VoidCallback onEditPoster;

  const PosterModule({super.key, required this.onEditPoster});

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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            width: targetWidth,
            height: targetHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              image:
                  (state.customPosterResult == null &&
                      (posterUrl != null || state.defaultPosterUrl != null))
                  ? DecorationImage(
                      image: NetworkImage(posterUrl ?? state.defaultPosterUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: GestureDetector(
              onTap: (posterUrl == null && state.customPosterResult == null)
                  ? onEditPoster
                  : null,
              child: Stack(
                children: [
                  if (state.isNsfwDetected)
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: Colors.redAccent,
                      ),
                      child: const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'NSFW content detected!\nPlease upload another image or try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (state.customPosterResult != null)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(
                          File(state.customPosterResult!.mediumPath),
                          key: ValueKey(state.customPosterResult!.mediumPath),
                          fit: BoxFit.cover,
                          cacheWidth: 800,
                        ),
                      ),
                    ),
                  if (posterUrl == null &&
                      state.defaultPosterUrl == null &&
                      state.customPosterResult == null &&
                      !state.isGeneratingPoster &&
                      !state.isNsfwDetected)
                    const Center(
                      child: Icon(Icons.image, color: Colors.white24, size: 48),
                    ),
                  if (state.isGeneratingPoster)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(15),
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
                      onTap: () => ref
                          .read(createEventProvider.notifier)
                          .toggleAspectRatio(),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.edit_outlined,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                state.isNsfwDetected ? 'Try again' : 'Edit poster',
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
                  if (state.isNsfwDetected)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: onEditPoster,
                        child: Container(
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
