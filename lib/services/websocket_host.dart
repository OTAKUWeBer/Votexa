import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../models/message.dart';
import '../models/vote.dart';
import '../models/question.dart';

class WebSocketHost {
  late HttpServer _server;
  final Set<WebSocket> _connectedClients = {};
  final String pollId;
  final String? password;
  final String deviceId;
  final Set<String> _votedKeys = {}; // Track voted device:uuid:questionId combinations
  final Map<String, Set<String>> _participantUuidsPerDevice = {}; // device -> set of uuids
  
  final StreamController<Message> _messageController = StreamController<Message>.broadcast();
  
  Stream<Message> get messages => _messageController.stream;
  
  int get connectedParticipants => _connectedClients.length;
  
  int get port => _server.port;

  WebSocketHost({
    required this.pollId,
    this.password,
    required this.deviceId,
  });

  Future<void> start({int port = 0}) async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          WebSocket ws = await WebSocketTransformer.upgrade(request);
          _handleNewClient(ws);
        }
      });
      
      print('[Votexa Host] WebSocket server started on port ${_server.port}');
      _messageController.add(
        Message.hostCreated(
          pollId: pollId,
          qrData: '$deviceId:${_server.port}:$pollId:${password ?? ''}',
          passwordProtected: password != null,
        ),
      );
    } catch (e) {
      _messageController.addError('Failed to start server: $e');
    }
  }

  void _handleNewClient(WebSocket ws) {
    _connectedClients.add(ws);
    
    ws.listen(
      (message) => _handleMessage(ws, message),
      onError: (error) {
        print('[Votexa Host] WebSocket error: $error');
        _connectedClients.remove(ws);
      },
      onDone: () {
        print('[Votexa Host] Client disconnected');
        _connectedClients.remove(ws);
      },
    );
  }

  void _handleMessage(WebSocket ws, dynamic data) {
    try {
      final message = Message.fromJsonString(data as String);
      
      switch (message.type) {
        case MessageType.participantJoined:
          _handleParticipantJoin(message.data);
          break;
        case MessageType.voteReceived:
          _handleVote(message.data);
          break;
        default:
          break;
      }
    } catch (e) {
      print('[Votexa Host] Error handling message: $e');
    }
  }

  void _handleParticipantJoin(Map<String, dynamic> data) {
    final deviceId = data['deviceId'] as String;
    final participantUuid = data['participantUuid'] as String;
    
    // Track participant UUID per device
    _participantUuidsPerDevice.putIfAbsent(deviceId, () => {}).add(participantUuid);
    
    print('[Votexa Host] Participant joined: $deviceId - $participantUuid');
    
    // Emit participant joined message so providers can update
    _messageController.add(
      Message.participantJoined(
        pollId: pollId,
        deviceId: deviceId,
        participantUuid: participantUuid,
      ),
    );
  }

  void _handleVote(Map<String, dynamic> data) {
    try {
      final vote = Vote.fromJson(data['vote'] as Map<String, dynamic>);
      final voteKey = vote.getVoteKey();
      
      // Check if vote is duplicate
      if (_votedKeys.contains(voteKey)) {
        print('[Votexa Host] Duplicate vote prevented: $voteKey');
        return;
      }
      
      // Record the vote
      _votedKeys.add(voteKey);
      _messageController.add(Message.voteReceived(vote: vote));
      
      print('[Votexa Host] Vote recorded: $voteKey -> ${vote.selectedOption}');
    } catch (e) {
      print('[Votexa Host] Error handling vote: $e');
    }
  }

  void broadcastResults(String pollId, List<Question> questions, int totalParticipants) {
    final message = Message.resultsUpdate(
      pollId: pollId,
      questions: questions,
      totalParticipants: totalParticipants,
    );
    
    _broadcastToAll(message);
  }

  void broadcastQuestionUpdate(Question question) {
    final message = Message.questionUpdated(question: question);
    _broadcastToAll(message);
  }

  void broadcastPollStarted(String pollId, List<Question> questions) {
    final message = Message.pollStarted(
      pollId: pollId,
      questions: questions,
    );
    _broadcastToAll(message);
  }

  void _broadcastToAll(Message message) {
    final jsonString = message.toJsonString();
    for (var client in _connectedClients) {
      try {
        client.add(jsonString);
      } catch (e) {
        print('[Votexa Host] Error broadcasting to client: $e');
      }
    }
  }

  void closePoll() {
    final message = Message.pollClosed(pollId: pollId);
    _broadcastToAll(message);
  }

  Future<void> stop() async {
    closePoll();
    for (var client in _connectedClients) {
      await client.close();
    }
    _connectedClients.clear();
    await _server.close();
    _messageController.close();
  }

  // Check if a device+uuid combination has already voted for a question
  bool hasDeviceVoted(String deviceId, String participantUuid, String questionId) {
    return _votedKeys.contains('$deviceId:$participantUuid:$questionId');
  }
}
