import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../shared/models/chat_model.dart';
import '../../../../shared/models/message_attachment.dart';
import '../../../../shared/models/message_model.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String attachmentsStoragePrefix = 'chat_attachments';

  static String attachmentBasePath({
    required String chatId,
    required String messageId,
  }) => '$attachmentsStoragePrefix/$chatId/$messageId';

  String reserveMessageId() =>
      _firestore.collection(AppConstants.messagesCollection).doc().id;

  Future<ChatModel> getOrCreateChat({
    required String productId,
    required String productTitle,
    required String productImageUrl,
    required String sellerId,
    required String sellerName,
    String? sellerPhotoUrl,
    required String buyerId,
    required String buyerName,
    String? buyerPhotoUrl,
  }) async {
    try {
      final isGeneralChat = productId.isEmpty;
      final chatId = isGeneralChat
          ? 'general_${sellerId}_$buyerId'
          : '${productId}_$buyerId';
      final docRef = _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId);

      final existing = await docRef.get();
      if (existing.exists) {
        return ChatModel.fromFirestore(existing);
      }

      final newChat = ChatModel(
        id: chatId,
        productId: productId,
        sellerId: sellerId,
        buyerId: buyerId,
        productTitle: productTitle,
        productImageUrl: productImageUrl,
        sellerName: sellerName,
        sellerPhotoUrl: sellerPhotoUrl,
        buyerName: buyerName,
        buyerPhotoUrl: buyerPhotoUrl,
        createdAt: DateTime.now(),
      );

      await docRef.set(newChat.toFirestore(), SetOptions(merge: true));

      return newChat;
    } catch (e) {
      debugPrint(
        '❌ getOrCreateChat failed (product=$productId, '
        'seller=$sellerId, buyer=$buyerId): $e',
      );
      rethrow;
    }
  }

  Stream<List<ChatModel>> getUserChats(String userId) {
    try {
      final buyerStream = _firestore
          .collection(AppConstants.chatsCollection)
          .where('buyerId', isEqualTo: userId)
          .orderBy('lastMessageTime', descending: true)
          .limit(50)
          .snapshots();

      final sellerStream = _firestore
          .collection(AppConstants.chatsCollection)
          .where('sellerId', isEqualTo: userId)
          .orderBy('lastMessageTime', descending: true)
          .limit(50)
          .snapshots();

      return _combineChatStreams(buyerStream, sellerStream);
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<ChatModel>> _combineChatStreams(
    Stream<QuerySnapshot<Map<String, dynamic>>> buyerStream,
    Stream<QuerySnapshot<Map<String, dynamic>>> sellerStream,
  ) {
    late final StreamController<List<ChatModel>> controller;
    QuerySnapshot<Map<String, dynamic>>? buyerSnapshot;
    QuerySnapshot<Map<String, dynamic>>? sellerSnapshot;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? buyerSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sellerSub;

    void emit() {
      if (buyerSnapshot == null || sellerSnapshot == null) return;

      final chatsById = <String, ChatModel>{};
      for (final doc in [...buyerSnapshot!.docs, ...sellerSnapshot!.docs]) {
        chatsById[doc.id] = ChatModel.fromFirestore(doc);
      }

      final chats = chatsById.values.where((chat) => chat.isActive).toList();

      chats.sort((a, b) {
        if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });

      controller.add(chats);
    }

    controller = StreamController<List<ChatModel>>(
      onListen: () {
        buyerSub = buyerStream.listen((snapshot) {
          buyerSnapshot = snapshot;
          emit();
        }, onError: controller.addError);
        sellerSub = sellerStream.listen((snapshot) {
          sellerSnapshot = snapshot;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await buyerSub?.cancel();
        await sellerSub?.cancel();
      },
    );

    return controller.stream;
  }

  Stream<ChatModel?> getChat(String chatId) {
    try {
      return _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .snapshots()
          .map((doc) {
            if (!doc.exists) return null;
            return ChatModel.fromFirestore(doc);
          });
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    try {
      return _firestore
          .collection(AppConstants.messagesCollection)
          .where('chatId', isEqualTo: chatId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => MessageModel.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      rethrow;
    }
  }

  Future<MessageModel> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String content,
    MessageType type = MessageType.text,
    String? imageUrl,
    String? messageId,
    List<MessageAttachment> attachments = const [],
  }) async {
    try {
      final images = attachments.where((a) => a.isImage).toList();
      final effectiveImageUrl =
          imageUrl ?? (images.isNotEmpty ? images.first.url : null);
      final effectiveType = images.isNotEmpty ? MessageType.image : type;

      final message = MessageModel(
        id: messageId ?? '',
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        content: content,
        type: effectiveType,
        imageUrl: effectiveImageUrl,
        timestamp: DateTime.now(),
        readBy: [senderId],
        attachments: attachments,
      );

      final DocumentReference<Map<String, dynamic>> docRef;
      if (messageId != null && messageId.isNotEmpty) {
        docRef = _firestore
            .collection(AppConstants.messagesCollection)
            .doc(messageId);
        await docRef.set(message.toFirestore());
      } else {
        docRef = await _firestore
            .collection(AppConstants.messagesCollection)
            .add(message.toFirestore());
      }

      final chat = await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .get();

      final chatData = ChatModel.fromFirestore(chat);

      final updates = <String, dynamic>{
        'lastMessage': message.previewText,
        'lastMessageTime': Timestamp.fromDate(message.timestamp),
        'lastMessageSenderId': senderId,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };
      if (senderId != chatData.sellerId) {
        updates['sellerUnreadCount'] = FieldValue.increment(1);
      }
      if (senderId != chatData.buyerId) {
        updates['buyerUnreadCount'] = FieldValue.increment(1);
      }

      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .update(updates);

      return message.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('❌ sendMessage failed (chat=$chatId, sender=$senderId): $e');
      rethrow;
    }
  }

  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      final chat = await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .get();

      final chatData = ChatModel.fromFirestore(chat);

      Map<String, dynamic> updates = {};

      if (userId == chatData.buyerId) {
        updates['buyerUnreadCount'] = 0;
      } else if (userId.isNotEmpty && userId == chatData.sellerId) {
        updates['sellerUnreadCount'] = 0;
      }

      if (updates.isNotEmpty) {
        await _firestore
            .collection(AppConstants.chatsCollection)
            .doc(chatId)
            .update(updates);
      }

      try {
        final unreadRows = await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .where('isRead', isEqualTo: false)
            .where('data.chatId', isEqualTo: chatId)
            .get();
        if (unreadRows.docs.isNotEmpty) {
          final rowBatch = _firestore.batch();
          for (final doc in unreadRows.docs) {
            rowBatch.update(doc.reference, {'isRead': true});
          }
          await rowBatch.commit();
        }
      } catch (e) {
        debugPrint('⚠️ could not clear chat notification rows: $e');
      }

      final unreadMessages = await _firestore
          .collection(AppConstants.messagesCollection)
          .where('chatId', isEqualTo: chatId)
          .where('senderId', isNotEqualTo: userId)
          .get();

      final batch = _firestore.batch();

      for (final doc in unreadMessages.docs) {
        final message = MessageModel.fromFirestore(doc);
        if (!message.readBy.contains(userId)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([userId]),
            'isRead': true,
          });
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint(
        '❌ markMessagesAsRead failed (chat=$chatId, user=$userId): $e',
      );
      rethrow;
    }
  }

  Stream<int> getUnreadCount(String userId) {
    try {
      return getUserChats(userId).map((chats) {
        int total = 0;
        for (final chat in chats) {
          if (chat.buyerId == userId) {
            total += chat.buyerUnreadCount;
          } else if (chat.sellerId == userId) {
            total += chat.sellerUnreadCount;
          }
        }
        return total;
      });
    } catch (e) {
      rethrow;
    }
  }
}
