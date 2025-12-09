class ProfileModel {
  final int id;
  final String? username;
  final String? name;
  final String? bio;
  final String? avatarUrl;
  final DateTime? createdAt;

  ProfileModel({
    required this.id,
    this.username,
    this.name,
    this.bio,
    this.avatarUrl,
    this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'],
      username: json['username'],
      name: json['name'],
      bio: json['bio'],
      avatarUrl: json['avatar_url'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'bio': bio,
      'avatar_url': avatarUrl,
    };
  }
}
