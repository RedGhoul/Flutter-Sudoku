import 'package:flutter/material.dart';
import '../models/statistics.dart';
import '../styles.dart';

class AlertStatistics extends StatelessWidget {
  final GameStatistics statistics;

  const AlertStatistics({Key? key, required this.statistics})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Styles.secondaryBackgroundColor,
      title: Text(
        'Statistics',
        style: TextStyle(color: Styles.foregroundColor),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Overall stats
            _buildStatCard(
              'Overall',
              [
                _StatRow('Games Played', statistics.totalGamesPlayed.toString()),
                _StatRow('Games Won', statistics.totalGamesCompleted.toString()),
                _StatRow(
                    'Win Rate',
                    statistics.totalGamesPlayed > 0
                        ? '${statistics.overallCompletionRate.toStringAsFixed(1)}%'
                        : '0%'),
                _StatRow('Current Streak', '${statistics.currentStreak} 🔥'),
                _StatRow('Longest Streak', statistics.longestStreak.toString()),
              ],
            ),
            const SizedBox(height: 16),

            // Per-difficulty stats
            _buildDifficultyStats(
                'Beginner', statistics.difficultyStats['beginner']!),
            _buildDifficultyStats('Easy', statistics.difficultyStats['easy']!),
            _buildDifficultyStats(
                'Medium', statistics.difficultyStats['medium']!),
            _buildDifficultyStats('Hard', statistics.difficultyStats['hard']!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: TextStyle(color: Styles.primaryColor)),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, List<Widget> rows) {
    return Card(
      color: Styles.primaryBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Styles.primaryColor,
              ),
            ),
            const Divider(),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyStats(String difficulty, DifficultyStats stats) {
    if (stats.gamesPlayed == 0) return const SizedBox.shrink();

    return _buildStatCard(
      difficulty,
      [
        _StatRow('Played', stats.gamesPlayed.toString()),
        _StatRow('Completed', stats.gamesCompleted.toString()),
        _StatRow('Win Rate', '${stats.completionRate.toStringAsFixed(1)}%'),
        if (stats.bestTime != null)
          _StatRow('Best Time', _formatDuration(stats.bestTime!)),
        if (stats.averageTime != null)
          _StatRow('Avg Time', _formatDuration(stats.averageTime!)),
        if (stats.gamesCompleted > 0)
          _StatRow('Avg Moves', stats.averageMoves.toStringAsFixed(1)),
      ],
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(d.inHours);
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));

    if (d.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Styles.foregroundColor)),
          Text(
            value,
            style: TextStyle(
              color: Styles.foregroundColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
