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
  String? _connectionError;
  bool _isConnecting = false;

  // Getters
  Poll? get currentPoll => _currentPoll;
  List<Question> get questions => _questions;
  bool get isConnected => _wsClient?.isConnected ?? false;
  bool get isConnecting => _isConnecting;
  int get totalParticipants => _totalParticipants;
  String? get participantUuid => _participantUuid;
  String? get connectionError => _connectionError;

  /// Initialize device ID and participant UUID
  Future<void> initializeIds() async {
    try {
      _deviceId = await DeviceIdManager.getDeviceId();
      _participantUuid = DeviceIdManager.getParticipantUuid();
      print('[ParticipantProvider] IDs initialized - Device: $_deviceId, Participant: $_participantUuid');
      notifyListeners();
    } catch (e) {
      print('[ParticipantProvider] Error initializing IDs: $e');
      _connectionError = 'Failed to initialize device IDs';
      notifyListeners();
    }
  }

  /// Join a poll with proper error handling and connection management
  Future<bool> joinPoll({
    required String hostAddress,
    required int hostPort,
    required String pollId,
    String? password,
  }) async {
    _isConnecting = true;
    _connectionError = null;
    notifyListeners();

    try {
      // Ensure IDs are initialized
      if (_deviceId == null || _participantUuid == null) {
        await initializeIds();
      }

      if (_deviceId == null || _participantUuid == null) {
        throw Exception('Device ID or Participant UUID is null');
      }

      print('[ParticipantProvider] Joining poll - Host: $hostAddress:$hostPort, Poll: $pollId');

      // Create WebSocket client
      _wsClient = WebSocketClient(
        hostAddress: hostAddress,
        hostPort: hostPort,
        pollId: pollId,
        password: password,
        deviceId: _deviceId!,
        participantUuid: _participantUuid!,
      );

      // Attempt connection with timeout
      await _wsClient!.connect().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout - could not reach host');
        },
      );

      // Set up message listener
      _wsClient!.messages.listen(
        (message) {
          print('[ParticipantProvider] Received message: ${message['type']}');
          _handleHostMessage(message);
        },
        onError: (error) {
          print('[ParticipantProvider] WebSocket error: $error');
          _connectionError = 'Connection error: ${error.toString()}';
          notifyListeners();
        },
        onDone: () {
          print('[ParticipantProvider] WebSocket connection closed');
          _handleDisconnection();
        },
        cancelOnError: false, // Don't cancel on errors
      );

      // Create poll instance
      _currentPoll = Poll(
        pollId: pollId,
        password: password,
        hostDeviceId: hostAddress,
        createdAt: DateTime.now(),
      );

      _isConnecting = false;
      _connectionError = null;
      notifyListeners();

      print('[ParticipantProvider] Successfully joined poll: $pollId');
      return true;
    } catch (e) {
      print('[ParticipantProvider] Failed to join poll: $e');
      _connectionError = _getErrorMessage(e);
      _isConnecting = false;
      
      // Clean up on failure
      await _wsClient?.disconnect();
      _wsClient = null;
      
      notifyListeners();
      return false;
    }
  }

  /// Handle incoming messages from the host
  void _handleHostMessage(Map<String, dynamic> message) {
    try {
      final String? messageType = message['type'];
      final Map<String, dynamic>? data = message['data'];
      
      if (messageType == null) {
        print('[ParticipantProvider] Message missing type field');
        return;
      }
      
      if (data == null) {
        print('[ParticipantProvider] Message missing data field');
        return;
      }
      
      print('[ParticipantProvider] Processing message type: $messageType');

      switch (messageType) {
        case 'pollInfo':
          _handlePollInfo(data);
          break;
        
        case 'questionUpdated':
        case 'questionAdded':
          _handleQuestionUpdate(data);
          break;
        
        case 'resultsUpdate':
          _handleResultsUpdate(data);
          break;
        
        case 'pollClosed':
          _handlePollClosed(data);
          break;
        
        case 'participantCount':
          _handleParticipantCount(data);
          break;
        
        case 'voteAcknowledged':
          _handleVoteAcknowledgement(data);
          break;
        
        case 'pollStarted':
          _handlePollStarted(data);
          break;
        
        case 'error':
          _handleError(data);
          break;
        
        case 'disconnected':
          _handleDisconnection();
          break;
        
        default:
          print('[ParticipantProvider] Unknown message type: $messageType');
      }
    } catch (e) {
      print('[ParticipantProvider] Error handling message: $e');
    }
  }

  /// Handle poll information
  void _handlePollInfo(Map<String, dynamic> data) {
    try {
      final List<dynamic>? questionsData = data['questions'];
      if (questionsData != null) {
        _questions = questionsData
            .map((q) => Question.fromJson(q as Map<String, dynamic>))
            .toList();
      }
      
      final int? totalParticipants = data['totalParticipants'];
      if (totalParticipants != null) {
        _totalParticipants = totalParticipants;
      }
      
      notifyListeners();
      print('[ParticipantProvider] Poll info updated - ${_questions.length} questions, $_totalParticipants participants');
    } catch (e) {
      print('[ParticipantProvider] Error parsing poll info: $e');
    }
  }

  /// Handle poll started event
  void _handlePollStarted(Map<String, dynamic> data) {
    try {
      final List<dynamic>? questionsData = data['questions'];
      if (questionsData != null) {
        _questions = questionsData
            .map((q) => Question.fromJson(q as Map<String, dynamic>))
            .toList();
        
        print('[ParticipantProvider] Poll started with ${_questions.length} questions');
        notifyListeners();
      }
    } catch (e) {
      print('[ParticipantProvider] Error parsing poll started: $e');
    }
  }

  /// Handle new or updated question
  void _handleQuestionUpdate(Map<String, dynamic> data) {
    try {
      final question = Question.fromJson(data);
      
      // Find and update existing question or add new one
      final index = _questions.indexWhere((q) => q.id == question.id);
      if (index >= 0) {
        _questions[index] = question;
        print('[ParticipantProvider] Question updated: ${question.id}');
      } else {
        _questions.add(question);
        print('[ParticipantProvider] New question added: ${question.id}');
      }
      
      notifyListeners();
    } catch (e) {
      print('[ParticipantProvider] Error parsing question update: $e');
    }
  }

  /// Handle live results update
  void _handleResultsUpdate(Map<String, dynamic> data) {
    try {
      final List<dynamic>? questionsData = data['questions'];
      if (questionsData != null) {
        final updatedQuestions = questionsData
            .map((q) => Question.fromJson(q as Map<String, dynamic>))
            .toList();
        
        // Update questions while preserving vote status
        for (final updated in updatedQuestions) {
          final index = _questions.indexWhere((q) => q.id == updated.id);
          if (index >= 0) {
            _questions[index] = updated;
          }
        }
        
        notifyListeners();
        print('[ParticipantProvider] Results updated for ${updatedQuestions.length} questions');
      }
    } catch (e) {
      print('[ParticipantProvider] Error parsing results update: $e');
    }
  }

  /// Handle participant count update
  void _handleParticipantCount(Map<String, dynamic> data) {
    final int? count = data['count'];
    if (count != null) {
      _totalParticipants = count;
      notifyListeners();
      print('[ParticipantProvider] Participant count updated: $_totalParticipants');
    }
  }

  /// Handle vote acknowledgement
  void _handleVoteAcknowledgement(Map<String, dynamic> data) {
    final String? questionId = data['questionId'];
    final bool? success = data['success'];
    final String? message = data['message'];
    
    if (questionId != null && success == true) {
      print('[ParticipantProvider] Vote acknowledged for question: $questionId');
      _connectionError = null;
    } else if (success == false) {
      // Remove from voted set if vote was rejected (e.g., duplicate)
      if (questionId != null) {
        _votedQuestions.remove(questionId);
      }
      _connectionError = message ?? 'Vote was rejected';
      notifyListeners();
      print('[ParticipantProvider] Vote rejected: $message');
    }
  }

  /// Handle poll closed event
  void _handlePollClosed(Map<String, dynamic> data) {
    print('[ParticipantProvider] Poll has been closed by host');
    _connectionError = 'Poll has been closed by the host';
    notifyListeners();
  }

  /// Handle error messages from host
  void _handleError(Map<String, dynamic> data) {
    final String? message = data['message'];
    if (message != null) {
      _connectionError = message;
      notifyListeners();
      print('[ParticipantProvider] Error from host: $message');
    }
  }

  /// Handle disconnection
  void _handleDisconnection() {
    if (_currentPoll != null) {
      _connectionError = 'Connection to host lost';
    }
    notifyListeners();
  }

  /// Submit a vote for a question
  void vote(String questionId, String selectedOption) {
    if (!isConnected || _currentPoll == null) {
      print('[ParticipantProvider] Cannot vote: not connected or no active poll');
      _connectionError = 'Not connected to poll';
      notifyListeners();
      return;
    }

    if (hasVoted(questionId)) {
      print('[ParticipantProvider] Already voted for question: $questionId');
      _connectionError = 'You have already voted for this question';
      notifyListeners();
      return;
    }

    try {
      // Mark as voted (optimistic update)
      _votedQuestions.add(questionId);
      _connectionError = null;
      
      // Send vote to host
      _wsClient?.sendVote(questionId, selectedOption, _currentPoll!.pollId);
      
      notifyListeners();
      print('[ParticipantProvider] Vote submitted - Question: $questionId, Option: $selectedOption');
    } catch (e) {
      // Rollback on error
      _votedQuestions.remove(questionId);
      _connectionError = 'Failed to submit vote: ${e.toString()}';
      notifyListeners();
      print('[ParticipantProvider] Error submitting vote: $e');
    }
  }

  /// Check if user has voted for a specific question
  bool hasVoted(String questionId) {
    return _votedQuestions.contains(questionId);
  }

  /// Manual method to update questions (if needed)
  void updateQuestions(List<Question> newQuestions) {
    _questions = newQuestions;
    notifyListeners();
    print('[ParticipantProvider] Questions manually updated: ${newQuestions.length}');
  }

  /// Manual method to set total participants (if needed)
  void setTotalParticipants(int count) {
    _totalParticipants = count;
    notifyListeners();
    print('[ParticipantProvider] Total participants set to: $count');
  }

  /// Manual method to update results (if needed)
  void updateResults(List<Question> updatedQuestions) {
    _questions = updatedQuestions;
    notifyListeners();
    print('[ParticipantProvider] Results manually updated');
  }

  /// Clear any connection errors
  void clearError() {
    _connectionError = null;
    notifyListeners();
  }

  /// Disconnect from poll and clean up
  Future<void> disconnect() async {
    print('[ParticipantProvider] Disconnecting from poll');
    
    try {
      await _wsClient?.disconnect();
    } catch (e) {
      print('[ParticipantProvider] Error during disconnect: $e');
    }
    
    _wsClient = null;
    _votedQuestions.clear();
    _questions.clear();
    _currentPoll = null;
    _totalParticipants = 0;
    _connectionError = null;
    _isConnecting = false;
    
    notifyListeners();
    print('[ParticipantProvider] Disconnected and cleaned up');
  }

  /// Get user-friendly error message
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('timeout')) {
      return 'Connection timeout. Please check:\n'
             '• You are on the same WiFi network\n'
             '• The Poll ID is correct\n'
             '• The host\'s poll is still active';
    } else if (errorStr.contains('socketexception') || errorStr.contains('network')) {
      return 'Network error. Please check your WiFi connection.';
    } else if (errorStr.contains('refused')) {
      return 'Connection refused. The host may not be running.';
    } else if (errorStr.contains('password')) {
      return 'Incorrect password';
    } else {
      return 'Connection failed: ${error.toString()}';
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}