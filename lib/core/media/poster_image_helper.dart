import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'bloom_image_processor.dart';

/// Result containing the local paths for the large, medium, and small variants.
class PosterProcessResult {
  final String largePath;
  final String mediumPath;
  final String smallPath;

  PosterProcessResult({
    required this.largePath,
    required this.mediumPath,
    required this.smallPath,
  });
}

/// Picks from gallery, then uses smart cropping and WebP compression.
/// Returns a [PosterProcessResult], or `null` if the user cancels or an error occurs.
/// Throws an exception if NSFW content is detected.
Future<PosterProcessResult?> pickAndProcessPoster(ImageSource source) async {
  if (kIsWeb) return null;
  
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: source,
    maxWidth: 2000,
    maxHeight: 2000,
    imageQuality: 100,
  );
  if (picked == null) return null;

  final bytes = await picked.readAsBytes();

  // Process the image using BloomImageProcessor
  final variants = await BloomImageProcessor.processImage(
    bytes,
    strategy: CropStrategy.portrait, // Standard 4:5 ratio for posters
  );

  // Save the variants to temporary files
  final dir = await getTemporaryDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  
  final largeFile = File('${dir.path}/poster_${timestamp}_large.webp');
  final mediumFile = File('${dir.path}/poster_${timestamp}_medium.webp');
  final smallFile = File('${dir.path}/poster_${timestamp}_small.webp');

  await largeFile.writeAsBytes(variants.large);
  await mediumFile.writeAsBytes(variants.medium);
  await smallFile.writeAsBytes(variants.small);

  return PosterProcessResult(
    largePath: largeFile.path,
    mediumPath: mediumFile.path,
    smallPath: smallFile.path,
  );
}
