import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../models/vote.dart';
import '../models/question.dart';

class WebSocketHost {
  late HttpServer _server;
  final Set<WebSocket> _connectedClients = {};
  final Map<String, WebSocket> _clientsByUuid = {}; // Map participant UUID to WebSocket
  final String pollId;
  final String? password;
  final String deviceId;
  final Set<String> _votedKeys = {}; // Track voted device:uuid:questionId combinations
  final Map<String, Set<String>> _participantUuidsPerDevice = {}; // device -> set of uuids
  
  String? _hostIp;
  bool _isRunning = false;
  
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  
  int get connectedParticipants => _connectedClients.length;
  
  int get port => _server.port;
  
  String? get hostIp => _hostIp;
  
  bool get isRunning => _isRunning;

  WebSocketHost({
    required this.pollId,
    this.password,
    required this.deviceId,
  });

  Future<void> start({int port = 0}) async {
    try {
      // Get local IP address
      _hostIp = await _getLocalIpAddress();
      
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _isRunning = true;
      
      _server.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          WebSocket ws = await WebSocketTransformer.upgrade(request);
          _handleNewClient(ws);
        }
      });
      
      print('[Votexa Host] WebSocket server started on $_hostIp:${_server.port}');
      
      // Emit host created message
      _messageController.add({
        'type': 'hostCreated',
        'data': {
          'pollId': pollId,
          'qrData': '$deviceId:${_server.port}:$pollId:${password ?? ''}',
          'passwordProtected': password != null,
          'hostIp': _hostIp,
          'hostPort': _server.port,
        },
      });
    } catch (e) {
      _isRunning = false;
      print('[Votexa Host] Error starting server: $e');
      _messageController.addError('Failed to start server: $e');
      rethrow;
    }
  }

  /// Get local IP address
  Future<String?> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      
      for (var interface in interfaces) {
        // Skip loopback
        if (interface.name.contains('lo')) continue;
        
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('[Votexa Host] Error getting local IP: $e');
    }
    return null;
  }

  void _handleNewClient(WebSocket ws) {
    _connectedClients.add(ws);
    print('[Votexa Host] New client connected. Total: ${_connectedClients.length}');
    
    ws.listen(
      (message) => _handleMessage(ws, message),
      onError: (error) {
        print('[Votexa Host] WebSocket error: $error');
        _removeClient(ws);
      },
      onDone: () {
        print('[Votexa Host] Client disconnected');
        _removeClient(ws);
      },
    );
  }

  void _removeClient(WebSocket ws) {
    _connectedClients.remove(ws);
    
    // Find and remove the participant UUID
    String? removedUuid;
    _clientsByUuid.removeWhere((uuid, socket) {
      if (socket == ws) {
        removedUuid = uuid;
        return true;
      }
      return false;
    });
    
    // Notify provider about disconnection
    _messageController.add({
      'type': 'participantLeft',
      'data': {
        'participantUuid': removedUuid ?? 'unknown',
        'connectedCount': _connectedClients.length,
      },
    });
    
    print('[Votexa Host] Client removed. Remaining: ${_connectedClients.length}');
  }

  void _handleMessage(WebSocket ws, dynamic data) {
    try {
      if (data is! String) {
        print('[Votexa Host] Received non-string message');
        return;
      }
      
      final Map<String, dynamic> message = jsonDecode(data);
      final String? messageType = message['type'];
      
      print('[Votexa Host] Received message type: $messageType');
      
      switch (messageType) {
        case 'participantJoined':
          _handleParticipantJoin(ws, message['data'] ?? {});
          break;
        case 'voteReceived':
          _handleVote(message['data'] ?? {});
          break;
        default:
          print('[Votexa Host] Unknown message type: $messageType');
      }
    } catch (e) {
      print('[Votexa Host] Error handling message: $e');
    }
  }

  void _handleParticipantJoin(WebSocket ws, Map<String, dynamic> data) {
    final String? deviceId = data['deviceId'];
    final String? participantUuid = data['participantUuid'];
    final String? providedPassword = data['password'];
    
    if (deviceId == null || participantUuid == null) {
      print('[Votexa Host] Invalid join request - missing required fields');
      _sendError(ws, 'Invalid join request');
      return;
    }
    
    // Verify password if required
    if (password != null && password!.isNotEmpty) {
      if (providedPassword != password) {
        print('[Votexa Host] Invalid password from $participantUuid');
        _sendError(ws, 'Invalid password');
        ws.close(1008, 'Invalid password');
        return;
      }
    }
    
    // Store WebSocket for this participant
    _clientsByUuid[participantUuid] = ws;
    
    // Track participant UUID per device
    _participantUuidsPerDevice.putIfAbsent(deviceId, () => {}).add(participantUuid);
    
    print('[Votexa Host] Participant joined: $deviceId - $participantUuid');
    
    // Emit participant joined message to provider
    _messageController.add({
      'type': 'participantJoined',
      'data': {
        'deviceId': deviceId,
        'participantUuid': participantUuid,
        'pollId': pollId,
        'connectedCount': _connectedClients.length,
      },
    });
  }

  void _handleVote(Map<String, dynamic> data) {
    try {
      final Map<String, dynamic>? voteData = data['vote'];
      
      if (voteData == null) {
        print('[Votexa Host] Vote data missing');
        return;
      }
      
      // Extract vote information
      final String? deviceId = voteData['deviceId'];
      final String? participantUuid = voteData['participantUuid'];
      final String? questionId = voteData['questionId'];
      final String? selectedOption = voteData['selectedOption'];
      
      if (deviceId == null || participantUuid == null || 
          questionId == null || selectedOption == null) {
        print('[Votexa Host] Invalid vote - missing required fields');
        return;
      }
      
      final voteKey = '$deviceId:$participantUuid:$questionId';
      
      // Check if vote is duplicate
      if (_votedKeys.contains(voteKey)) {
        print('[Votexa Host] Duplicate vote prevented: $voteKey');
        
        // Send rejection to participant
        sendVoteAcknowledgement(
          participantUuid,
          questionId,
          success: false,
          message: 'You have already voted for this question',
        );
        return;
      }
      
      // Record the vote
      _votedKeys.add(voteKey);
      
      // Forward vote to provider
      _messageController.add({
        'type': 'voteReceived',
        'data': {
          'pollId': voteData['pollId'],
          'questionId': questionId,
          'deviceId': deviceId,
          'participantUuid': participantUuid,
          'selectedOption': selectedOption,
          'timestamp': voteData['timestamp'] ?? DateTime.now().toIso8601String(),
        },
      });
      
      print('[Votexa Host] Vote recorded: $voteKey -> $selectedOption');
    } catch (e) {
      print('[Votexa Host] Error handling vote: $e');
    }
  }

  void _sendError(WebSocket ws, String errorMessage) {
    try {
      final message = {
        'type': 'error',
        'data': {'message': errorMessage},
      };
      ws.add(jsonEncode(message));
    } catch (e) {
      print('[Votexa Host] Error sending error message: $e');
    }
  }

  /// Send poll information to a specific participant
  void sendPollInfo(
    String participantUuid,
    String pollId,
    List<Question> questions,
    int totalParticipants,
  ) {
    final client = _clientsByUuid[participantUuid];
    if (client == null) {
      print('[Votexa Host] Cannot send poll info - participant not found: $participantUuid');
      return;
    }

    try {
      final message = {
        'type': 'pollInfo',
        'data': {
          'pollId': pollId,
          'questions': questions.map((q) => q.toJson()).toList(),
          'totalParticipants': totalParticipants,
          'isActive': true,
        },
      };

      client.add(jsonEncode(message));
      print('[Votexa Host] Sent poll info to participant: $participantUuid');
    } catch (e) {
      print('[Votexa Host] Error sending poll info: $e');
    }
  }

  /// Send vote acknowledgement to a specific participant
  void sendVoteAcknowledgement(
    String participantUuid,
    String questionId, {
    required bool success,
    String? message,
  }) {
    final client = _clientsByUuid[participantUuid];
    if (client == null) {
      print('[Votexa Host] Cannot send acknowledgement - participant not found: $participantUuid');
      return;
    }

    try {
      final ackMessage = {
        'type': 'voteAcknowledged',
        'data': {
          'questionId': questionId,
          'success': success,
          'message': message ?? (success ? 'Vote recorded' : 'Vote rejected'),
        },
      };

      client.add(jsonEncode(ackMessage));
      print('[Votexa Host] Sent vote acknowledgement to $participantUuid: $success');
    } catch (e) {
      print('[Votexa Host] Error sending vote acknowledgement: $e');
    }
  }

  /// Broadcast participant count to all clients
  void broadcastParticipantCount(int count) {
    final message = {
      'type': 'participantCount',
      'data': {'count': count},
    };
    
    _broadcastToAll(message);
    print('[Votexa Host] Broadcast participant count: $count');
  }

  void broadcastResults(String pollId, List<Question> questions, int totalParticipants) {
    final message = {
      'type': 'resultsUpdate',
      'data': {
        'pollId': pollId,
        'questions': questions.map((q) => q.toJson()).toList(),
        'totalParticipants': totalParticipants,
      },
    };
    
    _broadcastToAll(message);
  }

  void broadcastQuestionUpdate(Question question) {
    final message = {
      'type': 'questionUpdated',
      'data': question.toJson(),
    };
    _broadcastToAll(message);
  }

  void broadcastPollStarted(String pollId, List<Question> questions) {
    final message = {
      'type': 'pollStarted',
      'data': {
        'pollId': pollId,
        'questions': questions.map((q) => q.toJson()).toList(),
      },
    };
    _broadcastToAll(message);
  }

  void _broadcastToAll(Map<String, dynamic> message) {
    final jsonString = jsonEncode(message);
    for (var client in _connectedClients) {
      try {
        client.add(jsonString);
      } catch (e) {
        print('[Votexa Host] Error broadcasting to client: $e');
      }
    }
  }

  void closePoll() {
    final message = {
      'type': 'pollClosed',
      'data': {'pollId': pollId},
    };
    _broadcastToAll(message);
  }

  Future<void> stop() async {
    _isRunning = false;
    
    closePoll();
    
    // Close all client connections
    for (var client in _connectedClients) {
      try {
        await client.close();
      } catch (e) {
        print('[Votexa Host] Error closing client: $e');
      }
    }
    _connectedClients.clear();
    _clientsByUuid.clear();
    _participantUuidsPerDevice.clear();
    _votedKeys.clear();
    
    await _server.close();
    await _messageController.close();
    
    print('[Votexa Host] Server stopped');
  }

  // Check if a device+uuid combination has already voted for a question
  bool hasDeviceVoted(String deviceId, String participantUuid, String questionId) {
    return _votedKeys.contains('$deviceId:$participantUuid:$questionId');
  }
}