class ConversationModel {
  final String id;
  final int participantA;
  final int participantB;
  final String? lastMessage;
  final DateTime? updatedAt;
  final String? otherUsername;

  ConversationModel({
    required this.id,
    required this.participantA,
    required this.participantB,
    this.lastMessage,
    this.updatedAt,
    this.otherUsername,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'],
      participantA: json['participant_a'],
      participantB: json['participant_b'],
      lastMessage: json['last_message'],
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'participant_a': participantA,
      'participant_b': participantB,
      'last_message': lastMessage,
    };
  }
}
