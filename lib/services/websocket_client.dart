import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/message.dart';
import '../models/vote.dart';

class WebSocketClient {
  late WebSocketChannel _channel;
  final String hostAddress;
  final int hostPort;
  final String pollId;
  final String? password;
  final String deviceId;
  final String participantUuid;
  
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  bool _connected = false;

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  bool get isConnected => _connected;

  WebSocketClient({
    required this.hostAddress,
    required this.hostPort,
    required this.pollId,
    this.password,
    required this.deviceId,
    required this.participantUuid,
  });

  Future<void> connect() async {
    try {
      final wsUrl = Uri.parse('ws://$hostAddress:$hostPort');
      print('[Votexa Client] Attempting connection to $wsUrl');
      _channel = WebSocketChannel.connect(wsUrl);
      
      await _channel.ready;
      _connected = true;
      
      print('[Vovexa Client] WebSocket ready, sending join message');
      
      // Send join message with correct format
      final joinMessage = {
        'type': 'participantJoined',
        'data': {
          'pollId': pollId,
          'deviceId': deviceId,
          'participantUuid': participantUuid,
          'password': password,
        },
      };
      _channel.sink.add(jsonEncode(joinMessage));
      print('[Votexa Client] Join message sent');
      
      print('[Votexa Client] Connected to host on $hostAddress:$hostPort');
      
      // Listen for messages from host
      _channel.stream.listen(
        (message) => _handleMessage(message),
        onError: (error) {
          print('[Votexa Client] Error: $error');
          _connected = false;
          _messageController.addError('Connection error: $error');
        },
        onDone: () {
          print('[Votexa Client] Disconnected from host');
          _connected = false;
          // Add a disconnection message
          _messageController.add({
            'type': 'disconnected',
            'data': {'reason': 'Connection closed'},
          });
        },
      );
    } catch (e) {
      _connected = false;
      print('[Votexa Client] Connection failed: $e');
      _messageController.addError('Failed to connect: $e');
      rethrow;
    }
  }

  void _handleMessage(dynamic data) {
    try {
      if (data is String) {
        final Map<String, dynamic> message = jsonDecode(data);
        final messageType = message['type'];
        print('[Vovexa Client] Received message type: $messageType');
        
        // Log important messages with more detail
        if (messageType == 'pollStarted') {
          final questionsData = message['data']?['questions'];
          print('[Vovexa Client] Poll started with ${questionsData?.length ?? 0} questions');
        }
        
        _messageController.add(message);
      } else {
        print('[Vovexa Client] Received non-string message: ${data.runtimeType}');
      }
    } catch (e) {
      print('[Vovexa Client] Error parsing message: $e');
      _messageController.addError('Failed to parse message: $e');
    }
  }

  void sendVote(String questionId, String selectedOption, String pollId) {
    if (!_connected) {
      _messageController.addError('Not connected to host');
      return;
    }

    try {
      final voteMessage = {
        'type': 'voteReceived',
        'data': {
          'vote': {
            'pollId': pollId,
            'questionId': questionId,
            'deviceId': deviceId,
            'participantUuid': participantUuid,
            'selectedOption': selectedOption,
            'timestamp': DateTime.now().toIso8601String(),
          },
        },
      };

      _channel.sink.add(jsonEncode(voteMessage));
      
      print('[Votexa Client] Vote sent: $questionId -> $selectedOption');
    } catch (e) {
      print('[Votexa Client] Error sending vote: $e');
      _messageController.addError('Failed to send vote: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      _connected = false;
      await _channel.sink.close();
      await _messageController.close();
      print('[Votexa Client] Disconnected successfully');
    } catch (e) {
      print('[Votexa Client] Error during disconnect: $e');
    }
  }
}
