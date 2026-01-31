import 'package:flutter/material.dart';
import 'dart:async';
import '../models/poll.dart';
import '../models/question.dart';
import '../services/websocket_host.dart';
import '../utils/device_id_manager.dart';

class PollProvider extends ChangeNotifier {
  Poll? _currentPoll;
  WebSocketHost? _wsHost;
  List<Question> _questions = [];
  Set<String> _votedKeys = {};
  int _totalParticipants = 0;
  String? _deviceId;
  bool _isHost = false;
  Timer? _participantUpdateTimer;
  String? _hostError;
  String? _hostIp;
  int? _hostPort;

  // Getters
  Poll? get currentPoll => _currentPoll;
  List<Question> get questions => _questions;
  int get totalParticipants => _totalParticipants;
  bool get isHost => _isHost;
  bool get isPollActive => _currentPoll?.isActive ?? false;
  WebSocketHost? get wsHost => _wsHost;
  String? get hostError => _hostError;
  String? get hostIp => _hostIp;
  int? get hostPort => _hostPort;
  bool get isHostRunning => _wsHost?.isRunning ?? false;

  /// Initialize device ID
  Future<void> initializeDeviceId() async {
    try {
      _deviceId = await DeviceIdManager.getDeviceId();
      print('[PollProvider] Device ID initialized: $_deviceId');
      notifyListeners();
    } catch (e) {
      print('[PollProvider] Error initializing device ID: $e');
      _hostError = 'Failed to initialize device ID';
      notifyListeners();
    }
  }

  /// Create a new poll and start WebSocket host
  Future<bool> createPoll({
    String? password,
    int port = 0,
  }) async {
    try {
      _hostError = null;
      print('[PollProvider] Starting poll creation...');

      if (_deviceId == null) {
        await initializeDeviceId();
      }

      if (_deviceId == null) {
        throw Exception('Device ID is null');
      }

      final pollId = DeviceIdManager.generatePollId();
      print('[PollProvider] Creating poll with ID: $pollId');

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

      print('[PollProvider] Starting WebSocket server...');
      await _wsHost!.start(port: port);

      _hostIp = _wsHost!.hostIp ?? '192.168.1.100';
      _hostPort = _wsHost!.port;

      _isHost = true;
      _votedKeys.clear();
      _questions.clear();

      print('[PollProvider] Poll created successfully - IP: $_hostIp, Port: $_hostPort');

      // Listen for host messages
      _wsHost!.messages.listen(
        (message) {
          print('[PollProvider] Received message from host: ${message['type']}');
          _handleHostMessage(message);
        },
        onError: (error) {
          print('[PollProvider] Host message error: $error');
          _hostError = 'Message error: ${error.toString()}';
          notifyListeners();
        },
        onDone: () {
          print('[PollProvider] Host message stream closed');
        },
      );

      // Start periodic participant count updates
      _participantUpdateTimer?.cancel();
      _participantUpdateTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) {
          if (_wsHost != null && mounted) {
            final count = _wsHost!.connectedParticipants;
            if (_totalParticipants != count) {
              _totalParticipants = count;
              notifyListeners();

              _wsHost!.broadcastParticipantCount(count);
            }
          }
        },
      );

      notifyListeners();
      print('[PollProvider] Poll creation complete, notifying listeners');
      return true;
    } catch (e) {
      print('[PollProvider] Error creating poll: $e');
      _hostError = 'Failed to create poll: ${e.toString()}';
      _isHost = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Check if the provider is still mounted
  bool get mounted {
    try {
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Handle messages from WebSocket host service
  void _handleHostMessage(Map<String, dynamic> message) {
    try {
      final String? messageType = message['type'];
      final Map<String, dynamic>? data = message['data'];

      if (messageType == null || data == null) {
        print('[PollProvider] Invalid message structure');
        return;
      }

      print('[PollProvider] Processing message type: $messageType');

      switch (messageType) {
        case 'participantJoined':
          _handleParticipantJoined(data);
          break;
        case 'participantLeft':
          _handleParticipantLeft(data);
          break;
        case 'voteReceived':
          _handleVoteReceived(data);
          break;
        case 'participantCount':
          _handleParticipantCountUpdate(data);
          break;
        default:
          print('[PollProvider] Unknown message type: $messageType');
      }
    } catch (e) {
      print('[PollProvider] Error handling message: $e');
    }
  }

  /// Handle participant joined event
  void _handleParticipantJoined(Map<String, dynamic> data) {
    final String? participantUuid = data['participantUuid'];
    final String? deviceId = data['deviceId'];

    if (participantUuid == null) {
      print('[PollProvider] Participant joined but UUID is missing');
      return;
    }

    print('[PollProvider] Participant joined: $participantUuid (device: $deviceId)');

    if (_wsHost != null) {
      _totalParticipants = _wsHost!.connectedParticipants;
      _sendPollInfoToParticipant(participantUuid);
      notifyListeners();
    }
  }

  /// Handle participant left event
  void _handleParticipantLeft(Map<String, dynamic> data) {
    final String? participantUuid = data['participantUuid'];
    print('[PollProvider] Participant left: $participantUuid');

    if (_wsHost != null) {
      _totalParticipants = _wsHost!.connectedParticipants;
      notifyListeners();
    }
  }

  /// Handle vote received from participant
  void _handleVoteReceived(Map<String, dynamic> data) {
    try {
      final String? questionId = data['questionId'];
      final String? selectedOption = data['selectedOption'];
      final String? participantUuid = data['participantUuid'];
      final String? deviceId = data['deviceId'];

      if (questionId == null || selectedOption == null || participantUuid == null || deviceId == null) {
        print('[PollProvider] Invalid vote data - missing required fields');
        return;
      }

      print('[PollProvider] Vote received - Question: $questionId, Option: $selectedOption');

      final voteKey = '$deviceId:$participantUuid:$questionId';

      if (_votedKeys.contains(voteKey)) {
        print('[PollProvider] Duplicate vote prevented: $voteKey');
        _wsHost?.sendVoteAcknowledgement(
          participantUuid,
          questionId,
          success: false,
          message: 'Duplicate vote - you have already voted for this question',
        );
        return;
      }

      _votedKeys.add(voteKey);
      _updateQuestionVotes(questionId, selectedOption);

      _wsHost?.sendVoteAcknowledgement(
        participantUuid,
        questionId,
        success: true,
        message: 'Vote recorded',
      );

      broadcastResults();
    } catch (e) {
      print('[PollProvider] Error processing vote: $e');
    }
  }

  /// Update vote counts for a question
  void _updateQuestionVotes(String questionId, String selectedOption) {
    final questionIndex = _questions.indexWhere((q) => q.id == questionId);
    if (questionIndex == -1) {
      print('[PollProvider] Warning: Question not found for vote: $questionId');
      return;
    }

    final question = _questions[questionIndex];
    final updatedVotes = Map<String, int>.from(question.votes);

    updatedVotes[selectedOption] = (updatedVotes[selectedOption] ?? 0) + 1;

    final votingDevicesForQuestion = _votedKeys.where((key) => key.endsWith(':$questionId')).length;

    final updatedQuestion = question.copyWith(
      votes: updatedVotes,
      votingDevices: votingDevicesForQuestion,
    );

    _questions[questionIndex] = updatedQuestion;
    print('[PollProvider] Question updated - Total votes for "$selectedOption": ${updatedVotes[selectedOption]}');

    notifyListeners();
  }

  /// Handle participant count update
  void _handleParticipantCountUpdate(Map<String, dynamic> data) {
    final int? count = data['count'];
    if (count != null) {
      _totalParticipants = count;
      notifyListeners();
    }
  }

  /// Send current poll information to a specific participant
  void _sendPollInfoToParticipant(String participantUuid) {
    if (_wsHost == null || _currentPoll == null) {
      print('[PollProvider] Cannot send poll info - host or poll is null');
      return;
    }

    _wsHost!.sendPollInfo(
      participantUuid,
      _currentPoll!.pollId,
      _questions,
      _totalParticipants,
    );
  }

  /// Add a new question to the poll
  void addQuestion(String title, List<String> options) {
    if (_currentPoll == null) {
      print('[PollProvider] Cannot add question: no active poll');
      _hostError = 'No active poll';
      notifyListeners();
      return;
    }

    if (title.trim().isEmpty) {
      print('[PollProvider] Cannot add question: title is empty');
      _hostError = 'Question title cannot be empty';
      notifyListeners();
      return;
    }

    if (options.length < 2) {
      print('[PollProvider] Cannot add question: need at least 2 options');
      _hostError = 'Need at least 2 options';
      notifyListeners();
      return;
    }

    final question = Question(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      pollId: _currentPoll!.pollId,
      title: title,
      options: options,
    );

    _questions.add(question);
    print('[PollProvider] Question added: ${question.id} - $title');

    if (_wsHost != null) {
      _wsHost!.broadcastQuestionUpdate(question);
    }

    _hostError = null;
    notifyListeners();
  }

  /// Update question with new vote counts
  void updateQuestionVotes(String questionId, Map<String, int> votes) {
    final index = _questions.indexWhere((q) => q.id == questionId);
    if (index != -1) {
      final updatedQuestion = _questions[index].copyWith(votes: votes);
      _questions[index] = updatedQuestion;
      print('[PollProvider] Question votes updated: $questionId');
      notifyListeners();
    }
  }

  /// Broadcast current results to all participants
  void broadcastResults() {
    if (_wsHost != null && _currentPoll != null) {
      print('[PollProvider] Broadcasting results to $_totalParticipants participants');
      _wsHost!.broadcastResults(
        _currentPoll!.pollId,
        _questions,
        _totalParticipants,
      );
    }
  }

  /// Manually set total participants (if needed)
  void setTotalParticipants(int count) {
    _totalParticipants = count;
    notifyListeners();
    print('[PollProvider] Total participants set to: $count');
  }

  /// Start the poll and notify all participants
  void startPoll() {
    if (_currentPoll == null) {
      print('[PollProvider] Cannot start poll: no poll created');
      _hostError = 'No poll created';
      notifyListeners();
      return;
    }

    if (_questions.isEmpty) {
      print('[PollProvider] Cannot start poll: no questions added');
      _hostError = 'Add at least one question before starting';
      notifyListeners();
      return;
    }

    _currentPoll = _currentPoll!.copyWith(isActive: true);
    print('[PollProvider] Poll started: ${_currentPoll!.pollId} with ${_questions.length} questions');

    if (_wsHost != null) {
      print('[PollProvider] Broadcasting pollStarted to ${_wsHost!.connectedParticipants} participants');
      _wsHost!.broadcastPollStarted(
        _currentPoll!.pollId,
        _questions,
      );

      Future.delayed(const Duration(milliseconds: 100), () {
        _wsHost!.broadcastResults(
          _currentPoll!.pollId,
          _questions,
          _totalParticipants,
        );
      });
    }

    _hostError = null;
    notifyListeners();
  }

  /// Close the poll and notify all participants
  void closePoll() {
    if (_currentPoll == null) return;

    print('[PollProvider] Closing poll: ${_currentPoll!.pollId}');

    _currentPoll = _currentPoll?.copyWith(isActive: false);

    if (_wsHost != null) {
      _wsHost!.closePoll();
    }

    notifyListeners();
  }

  /// Delete a question from the poll
  void deleteQuestion(String questionId) {
    _questions.removeWhere((q) => q.id == questionId);
    _votedKeys.removeWhere((key) => key.endsWith(':$questionId'));

    print('[PollProvider] Question deleted: $questionId');

    if (_wsHost != null && _currentPoll != null) {
      _wsHost!.broadcastPollStarted(_currentPoll!.pollId, _questions);
    }

    notifyListeners();
  }

  /// Get vote statistics for a question
  Map<String, dynamic> getQuestionStats(String questionId) {
    final question = _questions.firstWhere(
      (q) => q.id == questionId,
      orElse: () => throw Exception('Question not found'),
    );

    final totalVotes = question.votes.values.fold<int>(0, (sum, count) => sum + count);
    final percentages = <String, double>{};

    for (final option in question.options) {
      final votes = question.votes[option] ?? 0;
      percentages[option] = totalVotes > 0 ? (votes / totalVotes) * 100 : 0.0;
    }

    return {
      'question': question,
      'totalVotes': totalVotes,
      'percentages': percentages,
      'votingDevices': question.votingDevices,
    };
  }

  /// Get all poll statistics
  Map<String, dynamic> getPollStats() {
    final totalVotesAcross = _questions.fold<int>(
      0,
      (sum, q) => sum + q.votes.values.fold<int>(0, (s, v) => s + v),
    );

    return {
      'pollId': _currentPoll?.pollId,
      'totalQuestions': _questions.length,
      'totalParticipants': _totalParticipants,
      'totalVotesCast': totalVotesAcross,
      'uniqueVoters': _votedKeys.map((key) => key.split(':')[0]).toSet().length,
      'isActive': isPollActive,
    };
  }

  /// Clear any host errors
  void clearError() {
    _hostError = null;
    notifyListeners();
  }

  /// Export poll results as JSON
  Map<String, dynamic> exportResults() {
    return {
      'poll': _currentPoll?.toJson(),
      'questions': _questions.map((q) => q.toJson()).toList(),
      'stats': getPollStats(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Stop the poll and clean up resources
  Future<void> stopPoll() async {
    print('[PollProvider] Stopping poll');

    _participantUpdateTimer?.cancel();
    _participantUpdateTimer = null;

    if (_wsHost != null) {
      await _wsHost!.stop();
      _wsHost = null;
    }

    _isHost = false;
    _currentPoll = null;
    _questions.clear();
    _votedKeys.clear();
    _totalParticipants = 0;
    _hostIp = null;
    _hostPort = null;
    _hostError = null;

    notifyListeners();
    print('[PollProvider] Poll stopped and cleaned up');
  }

  @override
  void dispose() {
    print('[PollProvider] Disposing');
    _participantUpdateTimer?.cancel();
    _wsHost?.stop();
    super.dispose();
  }
}
