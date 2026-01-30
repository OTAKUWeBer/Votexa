import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/poll.dart';
import '../models/question.dart';
import '../models/vote.dart';
import '../services/websocket_host.dart';
import '../utils/device_id_manager.dart';

class PollProvider extends ChangeNotifier {
  Poll? _currentPoll;
  WebSocketHost? _wsHost;
  List<Question> _questions = [];
  Set<String> _votedKeys = {}; // Track voted combinations
  int _totalParticipants = 0;
  String? _deviceId;
  bool _isHost = false;
  Timer? _participantUpdateTimer;

  Poll? get currentPoll => _currentPoll;
  List<Question> get questions => _questions;
  int get totalParticipants => _totalParticipants;
  bool get isHost => _isHost;
  bool get isPollActive => _currentPoll?.isActive ?? false;
  WebSocketHost? get wsHost => _wsHost;

  Future<void> initializeDeviceId() async {
    _deviceId = await DeviceIdManager.getDeviceId();
    notifyListeners();
  }

  Future<void> createPoll({
    required String? password,
    int port = 0,
  }) async {
    if (_deviceId == null) {
      await initializeDeviceId();
    }

    final pollId = DeviceIdManager.generatePollId();
    _currentPoll = Poll(
      pollId: pollId,
      password: password,
      hostDeviceId: _deviceId!,
      createdAt: DateTime.now(),
    );

    _wsHost = WebSocketHost(
      pollId: pollId,
      password: password,
      deviceId: _deviceId!,
    );

    await _wsHost!.start(port: port);
    _isHost = true;
    _votedKeys.clear();

    // Listen for host messages
    _wsHost!.messages.listen((message) {
      _handleHostMessage(message);
    });

    // Periodic update of participant count every 500ms
    _participantUpdateTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        _totalParticipants = _wsHost!.connectedParticipants;
        notifyListeners();
      },
    );

    notifyListeners();
  }

  void _handleHostMessage(dynamic message) {
    // Update participant count when participants join/leave
    if (_wsHost != null) {
      _totalParticipants = _wsHost!.connectedParticipants;
      notifyListeners();
    }
  }

  void addQuestion(String title, List<String> options) {
    if (_currentPoll == null) return;

    final question = Question(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      pollId: _currentPoll!.pollId,
      title: title,
      options: options,
    );

    _questions.add(question);
    _wsHost?.broadcastQuestionUpdate(question);
    notifyListeners();
  }

  void updateQuestionVotes(String questionId, Map<String, int> votes) {
    final index = _questions.indexWhere((q) => q.id == questionId);
    if (index != -1) {
      final updatedQuestion = _questions[index].copyWith(votes: votes);
      _questions[index] = updatedQuestion;
      notifyListeners();
    }
  }

  void recordVote(Vote vote) {
    final voteKey = vote.getVoteKey();
    
    if (_votedKeys.contains(voteKey)) {
      print('[PollProvider] Duplicate vote prevented');
      return;
    }

    _votedKeys.add(voteKey);

    // Update question votes
    final questionIndex = _questions.indexWhere((q) => q.id == vote.questionId);
    if (questionIndex != -1) {
      final question = _questions[questionIndex];
      final updatedVotes = Map<String, int>.from(question.votes);
      updatedVotes[vote.selectedOption] = (updatedVotes[vote.selectedOption] ?? 0) + 1;

      final updatedQuestion = question.copyWith(
        votes: updatedVotes,
        votingDevices: _votedKeys.where((key) => key.startsWith('${vote.deviceId}:')).length,
      );
      _questions[questionIndex] = updatedQuestion;
    }

    notifyListeners();
  }

  void broadcastResults() {
    if (_wsHost != null && _currentPoll != null) {
      _wsHost!.broadcastResults(
        _currentPoll!.pollId,
        _questions,
        _wsHost!.connectedParticipants,
      );
    }
  }

  void setTotalParticipants(int count) {
    _totalParticipants = count;
    notifyListeners();
  }

  void startPoll() {
    if (_currentPoll == null || _questions.isEmpty) {
      return;
    }

    _currentPoll = _currentPoll!.copyWith(isActive: true);
    
    if (_wsHost != null) {
      _wsHost!.broadcastPollStarted(
        _currentPoll!.pollId,
        _questions,
      );
    }

    notifyListeners();
  }

  void closePoll() {
    if (_wsHost != null) {
      _wsHost!.closePoll();
      _currentPoll = _currentPoll?.copyWith(isActive: false);
    }
    notifyListeners();
  }

  Future<void> dispose() async {
    _participantUpdateTimer?.cancel();
    await _wsHost?.stop();
    super.dispose();
  }
}
