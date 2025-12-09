class LikeModel {
  final String id;
  final String postId;
  final int userId;
  final DateTime? createdAt;

  LikeModel({
    required this.id,
    required this.postId,
    required this.userId,
    this.createdAt,
  });

  factory LikeModel.fromJson(Map<String, dynamic> json) {
    return LikeModel(
      id: json['id'],
      postId: json['post_id'],
      userId: json['user_id'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'post_id': postId, 'user_id': userId};
  }
}
