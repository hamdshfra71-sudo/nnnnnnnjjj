class NotificationModel {
  final String id;
  final int userId;
  final String? type; // like, comment, message, system
  final String? relatedId;
  final bool isSeen;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    this.type,
    this.relatedId,
    this.isSeen = false,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      userId: json['user_id'],
      type: json['type'],
      relatedId: json['related_id'],
      isSeen: json['is_seen'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'user_id': userId, 'type': type, 'related_id': relatedId};
  }
}
