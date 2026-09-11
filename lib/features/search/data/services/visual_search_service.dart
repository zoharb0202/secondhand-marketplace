import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../shared/models/product_model.dart';
import 'ai_search_service.dart';

class VisualSearchService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AISearchService _aiSearchService = AISearchService();

  Future<String> analyzeImage(XFile image) async {
    try {
      if (kDebugMode) {
        print('🖼️ [VISUAL SEARCH] Starting image analysis for: ${image.path}');
      }

      final bytes = await image.readAsBytes();
      final fileName =
          'visual_search_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = _storage.ref().child('temp_visual_search/$fileName');

      if (kDebugMode) {
        print('📤 [VISUAL SEARCH] Uploading image to storage...');
      }
      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final imageUrl = await storageRef.getDownloadURL();

      if (kDebugMode) {
        print('✅ [VISUAL SEARCH] Image uploaded: $imageUrl');
      }

      if (kDebugMode) {
        print('🤖 [VISUAL SEARCH] Calling AI vision function...');
      }
      final callable = _functions.httpsCallable('analyzeProductImage');
      final result = await callable.call({
        'imageUrl': imageUrl,
        'mode': 'search',
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final description = data['description'] as String;

      if (kDebugMode) {
        print('✅ [VISUAL SEARCH] AI description: $description');
      }

      Future.delayed(const Duration(minutes: 5), () {
        storageRef.delete().catchError((e) {
          if (kDebugMode) {
            print('⚠️ [VISUAL SEARCH] Failed to delete temp image: $e');
          }
        });
      });

      return description;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [VISUAL SEARCH] Image analysis failed: $e');
      }
      throw Exception('Failed to analyze image: $e');
    }
  }

  Future<List<ProductModel>> searchByDescription(String description) async {
    try {
      if (kDebugMode) {
        print(
          '🔍 [VISUAL SEARCH] Searching products with description: $description',
        );
      }

      final searchResult = await _aiSearchService.searchProducts(
        query: description,
        limit: 8,
      );

      final products = searchResult.products.map((productData) {
        final id = productData['id'] as String? ?? '';
        return ProductModel.fromMap(productData, id);
      }).toList();

      if (kDebugMode) {
        print('✅ [VISUAL SEARCH] Found ${products.length} matching products');
      }

      return products;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [VISUAL SEARCH] Search failed: $e');
      }
      throw Exception('Failed to search products: $e');
    }
  }

  Future<VisualSearchResult> searchByImage(XFile image) async {
    try {
      final description = await analyzeImage(image);

      final products = await searchByDescription(description);

      return VisualSearchResult(
        detectedDescription: description,
        products: products,
      );
    } catch (e) {
      throw Exception('Visual search failed: $e');
    }
  }
}

class VisualSearchResult {
  final String detectedDescription;
  final List<ProductModel> products;

  VisualSearchResult({
    required this.detectedDescription,
    required this.products,
  });
}
