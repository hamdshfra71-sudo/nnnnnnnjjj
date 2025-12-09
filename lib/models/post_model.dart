class PostModel {
  final String id;
  final int userId;
  final String? textContent;
  final String? mediaUrl;
  final String? mediaType;
  final int likesCount;
  final int commentsCount;
  final DateTime? createdAt;
  final String? username; // من join مع profiles

  PostModel({
    required this.id,
    required this.userId,
    this.textContent,
    this.mediaUrl,
    this.mediaType,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.createdAt,
    this.username,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'],
      userId: json['user_id'],
      textContent: json['text_content'],
      mediaUrl: json['media_url'],
      mediaType: json['media_type'],
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      username: json['profiles']?['username'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'text_content': textContent,
      'media_url': mediaUrl,
      'media_type': mediaType,
    };
  }
}
