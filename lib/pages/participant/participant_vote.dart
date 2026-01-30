import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/participant_provider.dart';

class ParticipantVotePage extends StatefulWidget {
  const ParticipantVotePage({Key? key}) : super(key: key);

  @override
  State<ParticipantVotePage> createState() => _ParticipantVotePageState();
}

class _ParticipantVotePageState extends State<ParticipantVotePage> {
  int _currentQuestionIndex = 0;
  Map<int, String> _selectedAnswers = {};

  @override
  void dispose() {
    context.read<ParticipantProvider>().disconnect();
    super.dispose();
  }

  void _selectOption(String option, String questionId) {
    setState(() {
      _selectedAnswers[_currentQuestionIndex] = option;
    });

    // Send vote immediately
    context.read<ParticipantProvider>().vote(questionId, option);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vote submitted!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await context.read<ParticipantProvider>().disconnect();
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
          child: Consumer<ParticipantProvider>(
            builder: (context, participantProvider, _) {
              final questions = participantProvider.questions;

              if (questions.isEmpty) {
                return SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                              const Icon(
                                Icons.schedule,
                                color: Color(0xFF0DD9FF),
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Waiting for Questions',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'The host will share questions soon',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFd1d5db),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFa78bfa),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final currentQuestion = questions[_currentQuestionIndex];
              final hasVoted = participantProvider.hasVoted(currentQuestion.id);

              return SafeArea(
                child: Column(
                  children: [
                    // Progress Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Question ${_currentQuestionIndex + 1} of ${questions.length}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFd1d5db),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (hasVoted)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Voted',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                            ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: (_currentQuestionIndex + 1) / questions.length,
                              minHeight: 4,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF0DD9FF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Question Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentQuestion.title,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Options
                            ...List.generate(
                              currentQuestion.options.length,
                              (index) {
                                final option = currentQuestion.options[index];
                                final isSelected =
                                    _selectedAnswers[_currentQuestionIndex] ==
                                        option;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: GestureDetector(
                                    onTap: hasVoted
                                        ? null
                                        : () => _selectOption(
                                              option,
                                              currentQuestion.id,
                                            ),
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF0DD9FF)
                                                .withOpacity(0.3)
                                            : Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF0DD9FF)
                                              : Colors.white.withOpacity(0.1),
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected
                                                    ? const Color(0xFF0DD9FF)
                                                    : Colors.white
                                                        .withOpacity(0.4),
                                              ),
                                            ),
                                            child: isSelected
                                                ? Center(
                                                    child: Container(
                                                      width: 12,
                                                      height: 12,
                                                      decoration:
                                                          const BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: Color(
                                                          0xFF0DD9FF,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Text(
                                              option,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: isSelected
                                                    ? const Color(0xFF0DD9FF)
                                                    : Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Navigation Buttons
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          // Previous Button
                          if (_currentQuestionIndex > 0)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() => _currentQuestionIndex--);
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFF0DD9FF),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Previous',
                                  style: TextStyle(
                                    color: Color(0xFF0DD9FF),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          if (_currentQuestionIndex > 0)
                            const SizedBox(width: 16),
                          // Next Button
                          if (_currentQuestionIndex < questions.length - 1)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() => _currentQuestionIndex++);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0DD9FF),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Next',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0A0E27),
                                  ),
                                ),
                              ),
                            )
                          else if (_currentQuestionIndex ==
                              questions.length - 1)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: const Color(0xFF1e1b4b),
                                      title: const Text(
                                        'Finished!',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      content: const Text(
                                        'You have completed all questions. You can view live results by waiting for other participants.',
                                        style: TextStyle(
                                          color: Color(0xFFd1d5db),
                                        ),
                                      ),
                                      actions: [
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF8b5cf6),
                                          ),
                                          child: const Text('OK'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0DD9FF),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Complete',
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
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
