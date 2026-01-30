import 'dart:async';
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
  
  final StreamController<Message> _messageController = StreamController<Message>.broadcast();
  bool _connected = false;

  Stream<Message> get messages => _messageController.stream;
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
      _channel = WebSocketChannel.connect(wsUrl);
      
      await _channel.ready;
      _connected = true;
      
      // Send join message
      final joinMessage = Message.participantJoined(
        pollId: pollId,
        deviceId: deviceId,
        participantUuid: participantUuid,
      );
      _channel.sink.add(joinMessage.toJsonString());
      
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
        },
      );
    } catch (e) {
      _connected = false;
      print('[Votexa Client] Connection failed: $e');
      _messageController.addError('Failed to connect: $e');
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final message = Message.fromJsonString(data as String);
      _messageController.add(message);
    } catch (e) {
      print('[Votexa Client] Error parsing message: $e');
    }
  }

  void sendVote(String questionId, String selectedOption, String pollId) {
    if (!_connected) {
      _messageController.addError('Not connected to host');
      return;
    }

    try {
      final vote = Vote(
        pollId: pollId,
        questionId: questionId,
        deviceId: deviceId,
        participantUuid: participantUuid,
        selectedOption: selectedOption,
        timestamp: DateTime.now(),
      );

      final message = Message.voteReceived(vote: vote);
      _channel.sink.add(message.toJsonString());
      
      print('[Votexa Client] Vote sent: $questionId -> $selectedOption');
    } catch (e) {
      print('[Votexa Client] Error sending vote: $e');
      _messageController.addError('Failed to send vote: $e');
    }
  }

  Future<void> disconnect() async {
    _connected = false;
    await _channel.sink.close();
    _messageController.close();
  }
}
