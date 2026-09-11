import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerWeb {
  static final ImagePicker _picker = ImagePicker();

  static Future<List<SelectedImage>> pickMultipleImages({
    int maxImages = 5,
  }) async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isEmpty) {
        return [];
      }

      final List<SelectedImage> selectedImages = [];

      final imagesToProcess = images.take(maxImages).toList();

      for (final image in imagesToProcess) {
        final bytes = await image.readAsBytes();

        selectedImages.add(
          SelectedImage(
            name: image.name,
            bytes: bytes,
            mimeType: image.mimeType,
          ),
        );
      }

      return selectedImages;
    } catch (e) {
      throw Exception('Failed to pick images: $e');
    }
  }

  static Future<String> uploadImageToStorage({
    required Uint8List imageBytes,
    required String fileName,
    required String path,
    String? mimeType,
  }) async {
    try {
      if (kDebugMode) {
        print('📤 Uploading $fileName (${imageBytes.length} bytes) to $path');
      }

      final storageRef = FirebaseStorage.instance
          .ref()
          .child(path)
          .child(fileName);

      final metadata = mimeType != null
          ? SettableMetadata(contentType: mimeType)
          : SettableMetadata(contentType: 'image/jpeg');

      final uploadTask = storageRef.putData(imageBytes, metadata);

      uploadTask.snapshotEvents.listen((taskSnapshot) {
        final progress =
            taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
        if (kDebugMode) {
          print(
            '📊 Upload progress for $fileName: ${(progress * 100).toInt()}%',
          );
        }
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (kDebugMode) print('✅ Successfully uploaded $fileName: $downloadUrl');
      return downloadUrl;
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        print('❌ Firebase error uploading $fileName: ${e.code} - ${e.message}');
      }
      throw Exception('Firebase Storage error: ${e.message ?? e.code}');
    } catch (e) {
      if (kDebugMode) print('❌ General error uploading $fileName: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  static Future<List<String>> uploadMultipleImages({
    required List<SelectedImage> images,
    required String basePath,
  }) async {
    final List<String> uploadedUrls = [];

    try {
      if (kDebugMode) {
        print('🔄 Starting upload of ${images.length} images to $basePath');
      }

      for (int i = 0; i < images.length; i++) {
        final image = images[i];
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${timestamp}_$i.${_getFileExtension(image.name)}';

        try {
          if (kDebugMode) {
            print(
              '📤 Uploading image ${i + 1}/${images.length}: ${image.name}',
            );
          }

          final url =
              await uploadImageToStorage(
                imageBytes: image.bytes,
                fileName: fileName,
                path: basePath,
                mimeType: image.mimeType,
              ).timeout(
                const Duration(seconds: 30),
                onTimeout: () {
                  throw Exception('Image upload timed out after 30 seconds');
                },
              );

          uploadedUrls.add(url);
          if (kDebugMode) print('✅ Successfully uploaded image ${i + 1}: $url');
        } catch (e) {
          if (kDebugMode) print('❌ Failed to upload image ${i + 1}: $e');
          continue;
        }
      }

      if (kDebugMode) {
        print(
          '🎉 Upload complete: ${uploadedUrls.length}/${images.length} images uploaded',
        );
      }
      return uploadedUrls;
    } catch (e) {
      if (kDebugMode) print('❌ Error in uploadMultipleImages: $e');
      return uploadedUrls;
    }
  }

  static String _getFileExtension(String fileName) {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last : 'jpg';
  }
}

class SelectedImage {
  final String name;
  final Uint8List bytes;
  final String? mimeType;

  SelectedImage({required this.name, required this.bytes, this.mimeType});
}
