class MessageModel {
  final String id;
  final String conversationId;
  final int senderId;
  final int receiverId;
  final String? text;
  final String? mediaUrl;
  final bool isRead;
  final DateTime? createdAt;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    this.text,
    this.mediaUrl,
    this.isRead = false,
    this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      conversationId: json['conversation_id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      text: json['text'],
      mediaUrl: json['media_url'],
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'text': text,
      'media_url': mediaUrl,
    };
  }
}
