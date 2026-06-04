import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class TempFileManager {
  /// Deletes a specific file immediately after it is no longer needed
  /// Use this after uploading a cropped image to Firebase Storage, for example.
  static Future<void> deleteFile(File? file) async {
    if (file == null) return;
    
    try {
      if (await file.exists()) {
        await file.delete();
        debugPrint('Securely deleted temp file.');
      }
    } catch (e) {
      // Intentionally swallow the error in production so we don't leak file paths
      debugPrint('Failed to delete temp file: $e'); 
    }
  }

  /// Clears the entire temporary directory.
  /// Call this during app initialization or when the user logs out.
  static Future<void> clearEntireCache() async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      
      if (await tempDir.exists()) {
        // Recursively list and delete all files in the cache directory
        tempDir.listSync(recursive: true).forEach((FileSystemEntity entity) {
          if (entity is File) {
            entity.deleteSync();
          }
        });
        debugPrint('Cleared all temporary cache files.');
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
}
