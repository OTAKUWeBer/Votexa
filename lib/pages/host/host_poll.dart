import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import '../../providers/poll_provider.dart';

class HostPollPage extends StatefulWidget {
  const HostPollPage({Key? key}) : super(key: key);

  @override
  State<HostPollPage> createState() => _HostPollPageState();
}

class _HostPollPageState extends State<HostPollPage> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  late GlobalKey<ScaffoldState> _scaffoldKey;

  @override
  void initState() {
    super.initState();
    _scaffoldKey = GlobalKey<ScaffoldState>();
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  void _addQuestion() {
    if (_questionController.text.isEmpty ||
        _optionControllers.any((c) => c.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final pollProvider = context.read<PollProvider>();
    pollProvider.addQuestion(
      _questionController.text,
      _optionControllers.map((c) => c.text).toList(),
    );

    _questionController.clear();
    for (var controller in _optionControllers) {
      controller.clear();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Question added!')),
    );
  }

  Future<String> _getQrData(BuildContext context, String pollId) async {
    try {
      final pollProvider = context.read<PollProvider>();
      
      // Use the host IP and port from the provider (already set by WebSocketHost)
      final hostIp = pollProvider.hostIp ?? '192.168.1.100';
      final port = pollProvider.hostPort ?? 8080;

      print('[HostPollPage] QR Data - IP: $hostIp, Port: $port, Poll: $pollId');
      
      // Format: VOTEXA|pollId|hostIp|port
      return 'VOTEXA|$pollId|$hostIp|$port';
    } catch (e) {
      print('[HostPollPage] Error getting QR data: $e');
      return 'VOTEXA|$pollId';
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final pollProvider = context.read<PollProvider>();
        pollProvider.closePoll();
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0E27), Color(0xFF141829)],
            ),
          ),
          child: Consumer<PollProvider>(
            builder: (context, pollProvider, _) {
              final poll = pollProvider.currentPoll;
              if (poll == null) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              return SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Host Poll',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                pollProvider.closePoll();
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // QR Code Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Poll ID',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFd1d5db),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                poll.pollId,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0DD9FF),
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 24),
                              // QR Code
                              FutureBuilder<String>(
                                future: _getQrData(context, poll.pollId),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return Container(
                                      width: 200,
                                      height: 200,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }

                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: QrImageView(
                                      data: snapshot.data!,
                                      version: QrVersions.auto,
                                      size: 200.0,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Share this QR code with participants',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9ca3af),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Questions Section
                        const Text(
                          'Questions',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Add Question Form
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Add a Question',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _questionController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Question',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF6b7280),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.05),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ...List.generate(
                                _optionControllers.length,
                                (index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _optionControllers[index],
                                          style:
                                              const TextStyle(color: Colors.white),
                                          decoration: InputDecoration(
                                            hintText: 'Option ${index + 1}',
                                            hintStyle: const TextStyle(
                                              color: Color(0xFF6b7280),
                                            ),
                                            filled: true,
                                            fillColor:
                                                Colors.white.withOpacity(0.05),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: Colors.white
                                                    .withOpacity(0.2),
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: Colors.white
                                                    .withOpacity(0.2),
                                              ),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.all(16),
                                          ),
                                        ),
                                      ),
                                      if (_optionControllers.length > 2)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 12),
                                          child: GestureDetector(
                                            onTap: () => _removeOption(index),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.red
                                                    .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.red,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Add Option Button
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _addOption,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFF0DD9FF),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    '+ Add Option',
                                    style: TextStyle(
                                      color: Color(0xFF0DD9FF),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Add Question Button
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _addQuestion,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0DD9FF),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Add Question',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0A0E27),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Questions List
                        if (pollProvider.questions.isNotEmpty)
                          Column(
                            children: List.generate(
                              pollProvider.questions.length,
                              (index) {
                                final question = pollProvider.questions[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${index + 1}. ${question.title}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ...question.options.map((option) {
                                          final votes = question.votes[option] ?? 0;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    child: LinearProgressIndicator(
                                                      value: question
                                                              .getTotalVotes() >
                                                          0
                                                          ? votes /
                                                              question
                                                                  .getTotalVotes()
                                                          : 0,
                                                      minHeight: 24,
                                                      backgroundColor: Colors
                                                          .white
                                                          .withOpacity(0.1),
                                                      valueColor:
                                                          const AlwaysStoppedAnimation<
                                                              Color>(
                                                        Color(0xFF8b5cf6),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  '$votes',
                                                  style: const TextStyle(
                                                    color: Color(0xFFa78bfa),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 32),
                        // Connected Participants Info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8b5cf6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF8b5cf6).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Connected Participants',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFa78bfa),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${pollProvider.totalParticipants}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFa78bfa),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Start Poll Button
                        if (pollProvider.questions.isNotEmpty)
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                print('[HostPollPage] Starting poll...');
                                pollProvider.startPoll();
                                // Show confirmation and navigate after a brief delay
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Poll started! Waiting for participant responses...'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                // Navigate to results page after a delay to let broadcast propagate
                                Future.delayed(const Duration(milliseconds: 500), () {
                                  if (mounted) {
                                    Navigator.of(context).pushReplacementNamed(
                                      '/results',
                                      arguments: {'isHost': true},
                                    );
                                  }
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10b981),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.play_arrow),
                                  SizedBox(width: 8),
                                  Text(
                                    'Start Poll',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: const Text(
                              'Add at least one question to start the poll',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFFfbbf24),
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
