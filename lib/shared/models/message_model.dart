import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/enums.dart';
import 'message_attachment.dart';

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String content;
  final MessageType type;
  final String? imageUrl;
  final DateTime timestamp;
  final bool isRead;
  final List<String> readBy;

  final List<MessageAttachment> attachments;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.content,
    required this.type,
    this.imageUrl,
    required this.timestamp,
    this.isRead = false,
    this.readBy = const [],
    this.attachments = const [],
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderPhotoUrl: data['senderPhotoUrl'],
      content: data['content'] ?? '',
      type: _parseType(data['type']),
      imageUrl: data['imageUrl'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      readBy: List<String>.from(data['readBy'] ?? []),
      attachments: MessageAttachment.listFromData(data['attachments']),
    );
  }

  static MessageType _parseType(Object? raw) {
    if (raw is! String) return MessageType.text;
    for (final type in MessageType.values) {
      if (type.name == raw) return type;
    }
    return MessageType.text;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'content': content,
      'type': type.name,
      'imageUrl': imageUrl,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'readBy': readBy,
      'attachments': MessageAttachment.listToMaps(attachments),
    };
  }

  bool get hasAttachments => attachments.isNotEmpty;

  String get previewText {
    final text = content.trim();
    if (text.isNotEmpty) return text;
    final label = MessageAttachment.previewLabel(attachments);
    if (label.isNotEmpty) return label;
    return 'הודעה חדשה';
  }

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? senderPhotoUrl,
    String? content,
    MessageType? type,
    String? imageUrl,
    DateTime? timestamp,
    bool? isRead,
    List<String>? readBy,
    List<MessageAttachment>? attachments,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      content: content ?? this.content,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      readBy: readBy ?? this.readBy,
      attachments: attachments ?? this.attachments,
    );
  }
}
