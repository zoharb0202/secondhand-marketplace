import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/chat_repository.dart';
import '../../../../shared/models/chat_model.dart';
import '../../../../shared/models/message_attachment.dart';
import '../../../../shared/models/message_model.dart';
import '../../../../core/constants/enums.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final userChatsProvider = StreamProvider.family<List<ChatModel>, String>((
  ref,
  userId,
) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getUserChats(userId);
});

final chatProvider = StreamProvider.family<ChatModel?, String>((ref, chatId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getChat(chatId);
});

final messagesProvider = StreamProvider.family<List<MessageModel>, String>((
  ref,
  chatId,
) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getMessages(chatId);
});

final unreadCountProvider = StreamProvider.family<int, String>((ref, userId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getUnreadCount(userId);
});

class ChatController extends StateNotifier<AsyncValue<void>> {
  final ChatRepository _repository;

  ChatController(this._repository) : super(const AsyncValue.data(null));

  Future<ChatModel?> getOrCreateChat({
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
    state = const AsyncValue.loading();
    try {
      final chat = await _repository.getOrCreateChat(
        productId: productId,
        productTitle: productTitle,
        productImageUrl: productImageUrl,
        sellerId: sellerId,
        sellerName: sellerName,
        sellerPhotoUrl: sellerPhotoUrl,
        buyerId: buyerId,
        buyerName: buyerName,
        buyerPhotoUrl: buyerPhotoUrl,
      );
      state = const AsyncValue.data(null);
      return chat;
    } catch (e, stack) {
      debugPrint('❌ ChatController.getOrCreateChat failed: $e');
      debugPrint('Stack trace: $stack');
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<MessageModel?> sendMessage({
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
      final message = await _repository.sendMessage(
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        content: content,
        type: type,
        imageUrl: imageUrl,
        messageId: messageId,
        attachments: attachments,
      );
      return message;
    } catch (e, stack) {
      debugPrint('❌ ChatController.sendMessage failed (chat=$chatId): $e');
      debugPrint('Stack trace: $stack');
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      await _repository.markMessagesAsRead(chatId, userId);
    } catch (e) {
      debugPrint('⚠️ markMessagesAsRead failed (chat=$chatId): $e');
    }
  }
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, AsyncValue<void>>((ref) {
      return ChatController(ref.watch(chatRepositoryProvider));
    });
