import 'package:flutter/material.dart';

import '../styles.dart';

class AlertGameOver extends StatelessWidget {
  static bool newGame = false;
  static bool restartGame = false;

  final String? timeTaken;
  final int? moveCount;

  const AlertGameOver({Key? key, this.timeTaken, this.moveCount})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: Styles.secondaryBackgroundColor,
      title: Text(
        'Game Over',
        style: TextStyle(color: Styles.foregroundColor),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You successfully solved the Sudoku!',
            style: TextStyle(
              color: Styles.foregroundColor,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          if (timeTaken != null) ...[
            const SizedBox(height: 16),
            Text(
              'Time: $timeTaken',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Styles.primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (moveCount != null) ...[
            const SizedBox(height: 8),
            Text(
              'Moves: $moveCount',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Styles.primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          style: ButtonStyle(
              foregroundColor:
                  MaterialStateProperty.all<Color>(Styles.primaryColor)),
          onPressed: () {
            Navigator.pop(context);
            restartGame = true;
          },
          child: const Text('Restart Game'),
        ),
        TextButton(
          style: ButtonStyle(
              foregroundColor:
                  MaterialStateProperty.all<Color>(Styles.primaryColor)),
          onPressed: () {
            Navigator.pop(context);
            newGame = true;
          },
          child: const Text('New Game'),
        ),
      ],
    );
  }
}
