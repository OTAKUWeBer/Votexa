import 'dart:convert';
import 'vote.dart';
import 'question.dart';

enum MessageType {
  hostCreated,
  participantJoined,
  participantLeft,
  questionUpdated,
  voteReceived,
  resultsUpdate,
  pollStarted,
  pollClosed,
  passwordRequired,
  passwordValid,
  error,
}

class Message {
  final MessageType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  Message({
    required this.type,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String toJsonString() {
    return jsonEncode({
      'type': type.name,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    });
  }

  factory Message.fromJsonString(String json) {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return Message(
      type: MessageType.values.byName(decoded['type'] as String),
      data: decoded['data'] as Map<String, dynamic>,
      timestamp: DateTime.parse(decoded['timestamp'] as String),
    );
  }

  // Factory constructors for specific message types
  factory Message.hostCreated({
    required String pollId,
    required String qrData,
    required bool passwordProtected,
  }) {
    return Message(
      type: MessageType.hostCreated,
      data: {
        'pollId': pollId,
        'qrData': qrData,
        'passwordProtected': passwordProtected,
      },
    );
  }

  factory Message.participantJoined({
    required String pollId,
    required String deviceId,
    required String participantUuid,
  }) {
    return Message(
      type: MessageType.participantJoined,
      data: {
        'pollId': pollId,
        'deviceId': deviceId,
        'participantUuid': participantUuid,
      },
    );
  }

  factory Message.questionUpdated({
    required Question question,
  }) {
    return Message(
      type: MessageType.questionUpdated,
      data: {
        'question': question.toJson(),
      },
    );
  }

  factory Message.voteReceived({
    required Vote vote,
  }) {
    return Message(
      type: MessageType.voteReceived,
      data: {
        'vote': vote.toJson(),
      },
    );
  }

  factory Message.resultsUpdate({
    required String pollId,
    required List<Question> questions,
    required int totalParticipants,
  }) {
    return Message(
      type: MessageType.resultsUpdate,
      data: {
        'pollId': pollId,
        'questions': questions.map((q) => q.toJson()).toList(),
        'totalParticipants': totalParticipants,
      },
    );
  }

  factory Message.pollStarted({
    required String pollId,
    required List<Question> questions,
  }) {
    return Message(
      type: MessageType.pollStarted,
      data: {
        'pollId': pollId,
        'questions': questions.map((q) => q.toJson()).toList(),
      },
    );
  }

  factory Message.pollClosed({
    required String pollId,
  }) {
    return Message(
      type: MessageType.pollClosed,
      data: {
        'pollId': pollId,
      },
    );
  }

  factory Message.error({
    required String message,
  }) {
    return Message(
      type: MessageType.error,
      data: {
        'message': message,
      },
    );
  }
}
