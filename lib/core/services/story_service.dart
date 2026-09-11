import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../../shared/models/story_model.dart';

class StoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _collection = 'stories';
  static const Duration _ttl = Duration(hours: 24);

  Stream<List<SellerStories>> activeStoriesStream() {
    final now = Timestamp.now();
    return _firestore
        .collection(_collection)
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt', descending: true)
        .snapshots()
        .map((snap) {
          final stories = snap.docs
              .map((d) => StoryModel.fromFirestore(d))
              .toList();
          final bySeller = <String, SellerStories>{};
          final order = <String>[];
          for (final s in stories) {
            if (!bySeller.containsKey(s.sellerId)) {
              order.add(s.sellerId);
              bySeller[s.sellerId] = SellerStories(
                sellerId: s.sellerId,
                sellerName: s.sellerName,
                sellerPhoto: s.sellerPhoto,
                stories: [s],
              );
            } else {
              bySeller[s.sellerId]!.stories.add(s);
            }
          }
          for (final ss in bySeller.values) {
            ss.stories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          }
          return order.map((id) => bySeller[id]!).toList();
        });
  }

  Future<void> createStory({
    required String sellerId,
    required String sellerName,
    String? sellerPhoto,
    File? imageFile,
    Uint8List? imageBytes,
    String? caption,
    String? productId,
    String? productTitle,
  }) async {
    final now = DateTime.now();
    final ref = _storage.ref().child(
      'stories/$sellerId/${now.millisecondsSinceEpoch}.jpg',
    );

    final metadata = SettableMetadata(contentType: 'image/jpeg');
    if (kIsWeb && imageBytes != null) {
      await ref.putData(imageBytes, metadata);
    } else if (imageFile != null) {
      await ref.putFile(imageFile, metadata);
    } else if (imageBytes != null) {
      await ref.putData(imageBytes, metadata);
    } else {
      throw ArgumentError('No image provided for story');
    }
    final imageUrl = await ref.getDownloadURL();

    final story = StoryModel(
      id: '',
      sellerId: sellerId,
      sellerName: sellerName,
      sellerPhoto: sellerPhoto,
      imageUrl: imageUrl,
      caption: caption,
      productId: productId,
      productTitle: productTitle,
      createdAt: now,
      expiresAt: now.add(_ttl),
    );
    await _firestore.collection(_collection).add(story.toFirestore());
  }

  Future<void> deleteStory(String storyId) async {
    await _firestore.collection(_collection).doc(storyId).delete();
  }
}
