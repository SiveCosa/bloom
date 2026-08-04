import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'bloom_image_processor.dart';

/// Result containing the local paths for the large, medium, and small variants.
class AvatarProcessResult {
  final String largePath;
  final String mediumPath;
  final String smallPath;

  AvatarProcessResult({
    required this.largePath,
    required this.mediumPath,
    required this.smallPath,
  });
}

/// Picks from camera/gallery, then uses smart face-centric cropping and WebP compression.
/// Returns a [AvatarProcessResult], or `null` if the user cancels or an error occurs.
/// Throws an exception if NSFW content is detected.
Future<AvatarProcessResult?> pickAndProcessAvatar(ImageSource source) async {
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
    strategy: CropStrategy.profile,
  );

  // Save the variants to temporary files
  final dir = await getTemporaryDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  
  final largeFile = File('${dir.path}/avatar_${timestamp}_large.webp');
  final mediumFile = File('${dir.path}/avatar_${timestamp}_medium.webp');
  final smallFile = File('${dir.path}/avatar_${timestamp}_small.webp');

  await largeFile.writeAsBytes(variants.large);
  await mediumFile.writeAsBytes(variants.medium);
  await smallFile.writeAsBytes(variants.small);

  return AvatarProcessResult(
    largePath: largeFile.path,
    mediumPath: mediumFile.path,
    smallPath: smallFile.path,
  );
}

Future<void> showAvatarSourceSheet(
  BuildContext context, {
  required void Function(ImageSource source) onChosen,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF191B1D),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(
              Icons.photo_library_outlined,
              color: Colors.white70,
            ),
            title: const Text(
              'Choose from gallery',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(ctx);
              onChosen(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white70,
            ),
            title: const Text(
              'Take a photo',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(ctx);
              onChosen(ImageSource.camera);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
