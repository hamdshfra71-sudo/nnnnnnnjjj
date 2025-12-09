class CommentModel {
  final String id;
  final String postId;
  final int userId;
  final String text;
  final DateTime? createdAt;
  final String? username;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.text,
    this.createdAt,
    this.username,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'],
      postId: json['post_id'],
      userId: json['user_id'],
      text: json['text'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      username: json['profiles']?['username'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'post_id': postId, 'user_id': userId, 'text': text};
  }
}
