import 'package:flutter/material.dart';
import '../models/question.dart';

class ResultsChart extends StatelessWidget {
  final Question question;
  final bool showPercentages;

  const ResultsChart({
    Key? key,
    required this.question,
    this.showPercentages = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalVotes = question.getTotalVotes();

    return Container(
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
          Text(
            question.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          if (totalVotes == 0)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              child: const Text(
                'No votes yet',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9ca3af),
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ...List.generate(
              question.options.length,
              (index) {
                final option = question.options[index];
                final votes = question.votes[option] ?? 0;
                final percentage = question.getPercentage(option);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (showPercentages)
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFa78bfa),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            '$votes',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF9ca3af),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: totalVotes > 0 ? votes / totalVotes : 0,
                          minHeight: 12,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF8b5cf6),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
