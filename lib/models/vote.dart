class Vote {
  final String pollId;
  final String questionId;
  final String deviceId;
  final String participantUuid;
  final String selectedOption;
  final DateTime timestamp;

  Vote({
    required this.pollId,
    required this.questionId,
    required this.deviceId,
    required this.participantUuid,
    required this.selectedOption,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'pollId': pollId,
      'questionId': questionId,
      'deviceId': deviceId,
      'participantUuid': participantUuid,
      'selectedOption': selectedOption,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Vote.fromJson(Map<String, dynamic> json) {
    return Vote(
      pollId: json['pollId'] as String,
      questionId: json['questionId'] as String,
      deviceId: json['deviceId'] as String,
      participantUuid: json['participantUuid'] as String,
      selectedOption: json['selectedOption'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  // Unique key to prevent duplicate votes
  String getVoteKey() => '$deviceId:$participantUuid:$questionId';
}
