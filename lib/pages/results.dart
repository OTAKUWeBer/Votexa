import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/poll_provider.dart';
import '../providers/participant_provider.dart';
import '../widgets/results_chart.dart';

class ResultsPage extends StatefulWidget {
  final bool isHost;

  const ResultsPage({
    Key? key,
    required this.isHost,
  }) : super(key: key);

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (widget.isHost) {
          context.read<PollProvider>().closePoll();
        } else {
          await context.read<ParticipantProvider>().disconnect();
        }
        return true;
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0E27), Color(0xFF141829)],
            ),
          ),
          child: SafeArea(
            child: widget.isHost
                ? _buildHostResults()
                : _buildParticipantResults(),
          ),
        ),
      ),
    );
  }

  Widget _buildHostResults() {
    return Consumer<PollProvider>(
      builder: (context, pollProvider, _) {
        final questions = pollProvider.questions;

        return SingleChildScrollView(
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
                      'Live Results',
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
                // Poll Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Poll ID',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9ca3af),
                            ),
                          ),
                          Text(
                            pollProvider.currentPoll?.pollId ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFa78bfa),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Participants',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9ca3af),
                            ),
                          ),
                          Text(
                            '${pollProvider.totalParticipants}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Results
                if (questions.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    alignment: Alignment.center,
                    child: const Text(
                      'No questions added yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF9ca3af),
                      ),
                    ),
                  )
                else
                  ...List.generate(
                    questions.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: ResultsChart(
                        question: questions[index],
                        showPercentages: true,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildParticipantResults() {
    return Consumer<ParticipantProvider>(
      builder: (context, participantProvider, _) {
        final questions = participantProvider.questions;

        return SingleChildScrollView(
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
                      'Results',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        await participantProvider.disconnect();
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.exit_to_app,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Poll Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Poll ID',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9ca3af),
                            ),
                          ),
                          Text(
                            participantProvider.currentPoll?.pollId ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFa78bfa),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Participants',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9ca3af),
                            ),
                          ),
                          Text(
                            '${participantProvider.totalParticipants}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Results
                if (questions.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    alignment: Alignment.center,
                    child: const Column(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: Color(0xFFa78bfa),
                          size: 48,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Waiting for results',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF9ca3af),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...List.generate(
                    questions.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: ResultsChart(
                        question: questions[index],
                        showPercentages: true,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}
