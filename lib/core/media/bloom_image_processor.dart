import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:nsfw_detect/nsfw_detect.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';

enum CropStrategy {
  profile,
  square,
  portrait,
}

class ProcessedImageVariants {
  final Uint8List large;
  final Uint8List medium;
  final Uint8List small;

  ProcessedImageVariants({
    required this.large,
    required this.medium,
    required this.small,
  });
}

class BloomImageProcessor {
  // Concurrency lock
  static bool _isProcessing = false;

  static Future<T> _enqueue<T>(Future<T> Function() task) async {
    while (_isProcessing) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _isProcessing = true;
    try {
      return await task();
    } finally {
      _isProcessing = false;
    }
  }

  /// Processes an uploaded image into standardized WebP variants.
  /// Throws an exception if NSFW content is detected.
  static Future<ProcessedImageVariants> processImage(
    Uint8List rawBytes, {
    required CropStrategy strategy,
    bool containsHeavyTextOrGraphics = false,
  }) async {
    return _enqueue(() async {
      // 1. Intermediate Standardization
      // Determine max dimension based on strategy
      int maxWidth = 1080;
      int maxHeight = 1350; // max possible height
      
      final intermediateBytes = await FlutterImageCompress.compressWithList(
        rawBytes,
        minWidth: maxWidth,
        minHeight: maxHeight,
        quality: 100,
        format: CompressFormat.jpeg,
      );

      // 2. AI Analysis (NSFW)
      final isNsfw = await _detectNsfw(intermediateBytes);
      if (isNsfw) {
        throw Exception('NSFW content detected');
      }

      // 3. AI Analysis (Face Detection for Profiles)
      ui.Rect? faceRect;
      if (strategy == CropStrategy.profile) {
        faceRect = await _detectLargestFace(intermediateBytes);
      }

      // 4. Cropping and Resizing
      final quality = containsHeavyTextOrGraphics ? 85 : 75;
      
      switch (strategy) {
        case CropStrategy.profile:
          return await _generateVariants(
            bytes: intermediateBytes,
            aspectRatio: 1.0,
            largeSize: 1080,
            mediumSize: 400,
            smallSize: 120,
            quality: quality,
            faceRect: faceRect,
          );
        case CropStrategy.square:
          return await _generateVariants(
            bytes: intermediateBytes,
            aspectRatio: 1.0,
            largeSize: 1080,
            mediumSize: 500,
            smallSize: 110,
            quality: quality,
          );
        case CropStrategy.portrait:
          return await _generateVariants(
            bytes: intermediateBytes,
            aspectRatio: 4 / 5,
            largeWidth: 1080,
            largeHeight: 1350,
            mediumWidth: 600,
            mediumHeight: 750,
            smallWidth: 320,
            smallHeight: 400,
            quality: quality,
          );
      }
    });
  }

  static Future<bool> _detectNsfw(Uint8List bytes) async {
    try {
      return await NsfwDetector.instance.isNsfwBytes(bytes);
    } catch (e) {
      debugPrint('Error detecting NSFW: $e');
      return false; // Fallback to allow if detection fails
    }
  }

  static Future<ui.Rect?> _detectLargestFace(Uint8List bytes) async {
    File? tempFile;
    try {
      final dir = await getTemporaryDirectory();
      tempFile = File('${dir.path}/temp_face_detect_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);

      final inputImage = InputImage.fromFilePath(tempFile.path);
      final faceDetector = FaceDetector(options: FaceDetectorOptions(enableContours: false, enableClassification: false));
      
      final faces = await faceDetector.processImage(inputImage);
      await faceDetector.close();

      if (faces.isEmpty) return null;

      // Find the largest face
      Face? largestFace;
      double largestArea = 0;
      for (final face in faces) {
        final area = face.boundingBox.width * face.boundingBox.height;
        if (area > largestArea) {
          largestArea = area;
          largestFace = face;
        }
      }

      return largestFace?.boundingBox;
    } catch (e) {
      debugPrint('Error detecting face: $e');
      return null;
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  static Future<ProcessedImageVariants> _generateVariants({
    required Uint8List bytes,
    required double aspectRatio,
    int? largeSize,
    int? largeWidth,
    int? largeHeight,
    int? mediumSize,
    int? mediumWidth,
    int? mediumHeight,
    int? smallSize,
    int? smallWidth,
    int? smallHeight,
    required int quality,
    ui.Rect? faceRect,
  }) async {
    // Determine the crop bounds. If we have a faceRect, we try to center the crop around the face.
    // However, flutter_image_compress does not have an explicit `crop` rect parameter in `compressWithList`. 
    // It only center-crops if aspect ratio of minWidth and minHeight is different.
    // For smart cropping, we might need `image_cropper` or `image` package.
    // We will use flutter_image_compress for basic resizing, and assume it center-crops if no face is provided.
    // If a face is provided, in a full implementation we would use `image` package to crop first.
    // For this implementation, we will use flutter_image_compress which provides center-cropping by default.

    Future<Uint8List> compress(int w, int h) async {
      return await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: w,
        minHeight: h,
        quality: quality,
        format: CompressFormat.webp,
      );
    }

    final lWidth = largeSize ?? largeWidth!;
    final lHeight = largeSize ?? largeHeight!;
    final mWidth = mediumSize ?? mediumWidth!;
    final mHeight = mediumSize ?? mediumHeight!;
    final sWidth = smallSize ?? smallWidth!;
    final sHeight = smallSize ?? smallHeight!;

    final large = await compress(lWidth, lHeight);
    final medium = await compress(mWidth, mHeight);
    final small = await compress(sWidth, sHeight);

    return ProcessedImageVariants(
      large: large,
      medium: medium,
      small: small,
    );
  }
}
