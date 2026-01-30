class Question {
  final String id;
  final String pollId;
  final String title;
  final List<String> options;
  final Map<String, int> votes; // option -> vote count
  final int votingDevices; // unique devices that voted

  Question({
    required this.id,
    required this.pollId,
    required this.title,
    required this.options,
    Map<String, int>? votes,
    this.votingDevices = 0,
  }) : votes = votes ?? {};

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pollId': pollId,
      'title': title,
      'options': options,
      'votes': votes,
      'votingDevices': votingDevices,
    };
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      pollId: json['pollId'] as String,
      title: json['title'] as String,
      options: List<String>.from(json['options'] as List),
      votes: Map<String, int>.from(json['votes'] as Map? ?? {}),
      votingDevices: json['votingDevices'] as int? ?? 0,
    );
  }

  Question copyWith({
    String? id,
    String? pollId,
    String? title,
    List<String>? options,
    Map<String, int>? votes,
    int? votingDevices,
  }) {
    return Question(
      id: id ?? this.id,
      pollId: pollId ?? this.pollId,
      title: title ?? this.title,
      options: options ?? this.options,
      votes: votes ?? this.votes,
      votingDevices: votingDevices ?? this.votingDevices,
    );
  }

  int getTotalVotes() {
    return votes.values.fold(0, (sum, count) => sum + count);
  }

  double getPercentage(String option) {
    int total = getTotalVotes();
    if (total == 0) return 0;
    return (votes[option] ?? 0) / total * 100;
  }
}
