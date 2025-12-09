class SavedPostModel {
  final String id;
  final int userId;
  final String postId;
  final DateTime? createdAt;

  SavedPostModel({
    required this.id,
    required this.userId,
    required this.postId,
    this.createdAt,
  });

  factory SavedPostModel.fromJson(Map<String, dynamic> json) {
    return SavedPostModel(
      id: json['id'],
      userId: json['user_id'],
      postId: json['post_id'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'user_id': userId, 'post_id': postId};
  }
}
