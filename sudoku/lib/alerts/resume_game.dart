import 'package:flutter/material.dart';

import '../styles.dart';

class AlertResumeGame extends StatelessWidget {
  final String difficulty;
  final String timeTaken;
  final int moveCount;

  const AlertResumeGame({
    Key? key,
    required this.difficulty,
    required this.timeTaken,
    required this.moveCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: Styles.secondaryBackgroundColor,
      title: Text(
        'Resume Game',
        style: TextStyle(color: Styles.foregroundColor),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You have a saved game in progress!',
            style: TextStyle(
              color: Styles.foregroundColor,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Styles.primaryBackgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildInfoRow('Difficulty', difficulty),
                const SizedBox(height: 8),
                _buildInfoRow('Time', timeTaken),
                const SizedBox(height: 8),
                _buildInfoRow('Moves', moveCount.toString()),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          style: ButtonStyle(
            foregroundColor:
                MaterialStateProperty.all<Color>(Styles.foregroundColor),
          ),
          onPressed: () {
            Navigator.pop(context, false);
          },
          child: const Text('New Game'),
        ),
        TextButton(
          style: ButtonStyle(
            foregroundColor:
                MaterialStateProperty.all<Color>(Styles.primaryColor),
          ),
          onPressed: () {
            Navigator.pop(context, true);
          },
          child: const Text('Resume'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Styles.foregroundColor,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Styles.primaryColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
