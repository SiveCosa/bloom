import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageCompressionHelper {
  /// Compresses image bytes to WebP format with 80% quality.
  static Future<Uint8List> compressToWebP(Uint8List bytes, {int quality = 80}) async {
    return await FlutterImageCompress.compressWithList(
      bytes,
      quality: quality,
      format: CompressFormat.webp,
    );
  }
}
