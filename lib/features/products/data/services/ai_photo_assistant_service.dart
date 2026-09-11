import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../shared/models/photo_quality_result.dart';

class AiPhotoAssistantService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<PhotoQualityResult> analyzePhotoQuality(String imagePath) async {
    try {
      if (kDebugMode) {
        print('🤖 Analyzing photo quality for: $imagePath');
      }

      final imageUrl = await _uploadImageToStorage(imagePath);
      if (kDebugMode) {
        print('📤 Image uploaded: $imageUrl');
      }

      final callable = _functions.httpsCallable('analyzePhotoQuality');
      final result = await callable
          .call({'imageUrl': imageUrl})
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'ניתוח התמונה לוקח יותר מדי זמן. אנא נסה שוב מאוחר יותר.',
              );
            },
          );

      if (kDebugMode) {
        print('✅ AI analysis complete');
      }

      final responseData = result.data;
      final data = _convertToMap(responseData);

      if (data['success'] != true) {
        throw Exception('Analysis failed');
      }

      final analysis = _convertToMap(data['analysis']);
      return PhotoQualityResult.fromMap(analysis);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error analyzing photo quality: $e');
      }
      rethrow;
    }
  }

  Future<String> _uploadImageToStorage(String imagePath) async {
    try {
      final file = File(imagePath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final fileSize = await file.length();
      if (kDebugMode) {
        print(
          '📏 Original image size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB',
        );
      }

      File imageToUpload = file;

      if (fileSize > 500 * 1024) {
        if (kDebugMode) {
          print('🗜️ Compressing image...');
        }
        final dir = await getTemporaryDirectory();
        final targetPath = '${dir.path}/compressed_$timestamp.jpg';

        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          imagePath,
          targetPath,
          quality: 85,
          minWidth: 1024,
          minHeight: 1024,
        );

        if (compressedFile != null) {
          imageToUpload = File(compressedFile.path);
          final compressedSize = await imageToUpload.length();
          if (kDebugMode) {
            print(
              '✅ Compressed to: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB',
            );
          }
        } else {
          if (kDebugMode) {
            print('⚠️ Compression failed, using original');
          }
        }
      }

      final fileName = 'photo_analysis_$timestamp.jpg';

      final storageRef = _storage.ref().child('temp_analysis/$fileName');

      final uploadTask = storageRef.putFile(imageToUpload);
      final snapshot = await uploadTask.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('העלאת התמונה לוקחת יותר מדי זמן. אנא נסה שוב.');
        },
      );

      final downloadUrl = await snapshot.ref.getDownloadURL();
      if (kDebugMode) {
        print('✅ Image uploaded successfully: $downloadUrl');
      }

      if (imageToUpload.path != file.path) {
        try {
          await imageToUpload.delete();
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Failed to delete compressed file: $e');
          }
        }
      }

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error uploading image: $e');
      }
      rethrow;
    }
  }

  Future<bool> isPhotoGoodEnough(String imagePath) async {
    try {
      final result = await analyzePhotoQuality(imagePath);
      return result.isGoodEnough;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking photo quality: $e');
      }
      return true;
    }
  }

  Future<double> getQuickScore(String imagePath) async {
    try {
      final result = await analyzePhotoQuality(imagePath);
      return result.overallScore;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting quick score: $e');
      }
      return 0.0;
    }
  }

  Map<String, dynamic> _convertToMap(dynamic data) {
    if (data is Map) {
      return Map<String, dynamic>.from(
        data.map((key, value) {
          if (value is Map) {
            return MapEntry(key.toString(), _convertToMap(value));
          } else if (value is List) {
            return MapEntry(
              key.toString(),
              value.map((item) {
                if (item is Map) {
                  return _convertToMap(item);
                }
                return item;
              }).toList(),
            );
          }
          return MapEntry(key.toString(), value);
        }),
      );
    }
    throw Exception('Expected Map but got ${data.runtimeType}');
  }
}
