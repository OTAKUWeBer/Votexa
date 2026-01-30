import 'package:flutter/material.dart';
import '../models/poll.dart';
import '../models/question.dart';
import '../services/websocket_client.dart';
import '../utils/device_id_manager.dart';

class ParticipantProvider extends ChangeNotifier {
  WebSocketClient? _wsClient;
  Poll? _currentPoll;
  List<Question> _questions = [];
  Set<String> _votedQuestions = {}; // Track voted questions
  String? _deviceId;
  String? _participantUuid;
  int _totalParticipants = 0;

  Poll? get currentPoll => _currentPoll;
  List<Question> get questions => _questions;
  bool get isConnected => _wsClient?.isConnected ?? false;
  int get totalParticipants => _totalParticipants;
  String? get participantUuid => _participantUuid;

  Future<void> initializeIds() async {
    _deviceId = await DeviceIdManager.getDeviceId();
    _participantUuid = DeviceIdManager.getParticipantUuid();
    notifyListeners();
  }

  Future<bool> joinPoll({
    required String hostAddress,
    required int hostPort,
    required String pollId,
    required String? password,
  }) async {
    if (_deviceId == null || _participantUuid == null) {
      await initializeIds();
    }

    try {
      _wsClient = WebSocketClient(
        hostAddress: hostAddress,
        hostPort: hostPort,
        pollId: pollId,
        password: password,
        deviceId: _deviceId!,
        participantUuid: _participantUuid!,
      );

      await _wsClient!.connect();

      // Listen for messages from host
      _wsClient!.messages.listen(
        (message) => _handleHostMessage(message),
        onError: (error) {
          print('[ParticipantProvider] Error: $error');
        },
      );

      _currentPoll = Poll(
        pollId: pollId,
        password: password,
        hostDeviceId: hostAddress,
        createdAt: DateTime.now(),
      );

      notifyListeners();
      return true;
    } catch (e) {
      print('[ParticipantProvider] Failed to join poll: $e');
      notifyListeners();
      return false;
    }
  }

  void _handleHostMessage(dynamic message) {
    // Handle messages from host (questions, results updates, poll closed)
    notifyListeners();
  }

  void vote(String questionId, String selectedOption) {
    if (!isConnected || _currentPoll == null) {
      print('[ParticipantProvider] Cannot vote: not connected or no active poll');
      return;
    }

    if (hasVoted(questionId)) {
      print('[ParticipantProvider] Already voted for this question');
      return;
    }

    _votedQuestions.add(questionId);
    _wsClient?.sendVote(questionId, selectedOption, _currentPoll!.pollId);
    notifyListeners();
  }

  bool hasVoted(String questionId) {
    return _votedQuestions.contains(questionId);
  }

  void updateQuestions(List<Question> newQuestions) {
    _questions = newQuestions;
    notifyListeners();
  }

  void setTotalParticipants(int count) {
    _totalParticipants = count;
    notifyListeners();
  }

  void updateResults(List<Question> updatedQuestions) {
    _questions = updatedQuestions;
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _wsClient?.disconnect();
    _votedQuestions.clear();
    _questions.clear();
    _currentPoll = null;
    notifyListeners();
  }
}
