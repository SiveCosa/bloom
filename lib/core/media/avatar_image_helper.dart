import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Picks from camera/gallery with initial compression, then opens a locked 1:1 cropper.
/// Returns a local file path, or `null` if the user cancels or an error occurs.
Future<String?> pickAndCropSquareAvatar(ImageSource source) async {
  if (kIsWeb) return null;
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null) return null;

    final cropper = ImageCropper();
    final cropped = await cropper.cropImage(
      sourcePath: picked.path,
      maxWidth: 512,
      maxHeight: 512,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 80,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop photo',
          toolbarColor: const Color(0xFF0B0E12),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFF0086D8),
          backgroundColor: const Color(0xFF0B0E12),
          statusBarLight: false,
          navBarLight: false,
          lockAspectRatio: true,
          initAspectRatio: CropAspectRatioPreset.square,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
          cropStyle: CropStyle.rectangle,
        ),
        IOSUiSettings(
          title: 'Crop photo',
          aspectRatioLockEnabled: true,
          aspectRatioPickerButtonHidden: true,
          resetAspectRatioEnabled: false,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
        ),
      ],
    );
    if (cropped == null) return null;
    return cropped.path;
  } catch (e, st) {
    debugPrint('pickAndCropSquareAvatar failed: $e\n$st');
    return null;
  }
}

Future<void> showAvatarSourceSheet(
  BuildContext context, {
  required void Function(ImageSource source) onChosen,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1A1D24),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: Colors.white70),
            title: const Text('Choose from gallery', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              onChosen(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: Colors.white70),
            title: const Text('Take a photo', style: TextStyle(color: Colors.white)),
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
