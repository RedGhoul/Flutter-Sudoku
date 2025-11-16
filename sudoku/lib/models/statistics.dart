import 'package:shared_preferences/shared_preferences.dart';

class DifficultyStats {
  int gamesPlayed;
  int gamesCompleted;
  Duration? bestTime;
  Duration? averageTime;
  int totalMoves;
  List<Duration> recentTimes; // Last 10 games

  DifficultyStats({
    this.gamesPlayed = 0,
    this.gamesCompleted = 0,
    this.bestTime,
    this.averageTime,
    this.totalMoves = 0,
    List<Duration>? recentTimes,
  }) : recentTimes = recentTimes ?? [];

  /// Record a completed game
  void recordGame(Duration time, int moves) {
    gamesPlayed++;
    gamesCompleted++;
    totalMoves += moves;

    // Update best time
    if (bestTime == null || time < bestTime!) {
      bestTime = time;
    }

    // Add to recent times (keep last 10)
    recentTimes.add(time);
    if (recentTimes.length > 10) {
      recentTimes.removeAt(0);
    }

    // Recalculate average time
    _updateAverageTime();
  }

  /// Record a played but not completed game
  void recordIncompleteGame() {
    gamesPlayed++;
  }

  /// Update average time based on recent times
  void _updateAverageTime() {
    if (recentTimes.isEmpty) {
      averageTime = null;
      return;
    }

    int totalSeconds = 0;
    for (var time in recentTimes) {
      totalSeconds += time.inSeconds;
    }

    averageTime = Duration(seconds: totalSeconds ~/ recentTimes.length);
  }

  /// Get completion rate as percentage (0-100)
  double get completionRate {
    if (gamesPlayed == 0) return 0.0;
    return (gamesCompleted / gamesPlayed) * 100;
  }

  /// Get average moves per game
  double get averageMoves {
    if (gamesCompleted == 0) return 0.0;
    return totalMoves / gamesCompleted;
  }

  /// Serialization
  Map<String, dynamic> toJson() {
    return {
      'gamesPlayed': gamesPlayed,
      'gamesCompleted': gamesCompleted,
      'bestTime': bestTime?.inSeconds,
      'averageTime': averageTime?.inSeconds,
      'totalMoves': totalMoves,
      'recentTimes': recentTimes.map((t) => t.inSeconds).toList(),
    };
  }

  /// Deserialization
  factory DifficultyStats.fromJson(Map<String, dynamic> json) {
    return DifficultyStats(
      gamesPlayed: json['gamesPlayed'] as int? ?? 0,
      gamesCompleted: json['gamesCompleted'] as int? ?? 0,
      bestTime: json['bestTime'] != null
          ? Duration(seconds: json['bestTime'] as int)
          : null,
      averageTime: json['averageTime'] != null
          ? Duration(seconds: json['averageTime'] as int)
          : null,
      totalMoves: json['totalMoves'] as int? ?? 0,
      recentTimes: (json['recentTimes'] as List<dynamic>?)
              ?.map((s) => Duration(seconds: s as int))
              .toList() ??
          [],
    );
  }

  @override
  String toString() {
    return 'DifficultyStats(played: $gamesPlayed, completed: $gamesCompleted, bestTime: $bestTime)';
  }
}

class GameStatistics {
  // Per-difficulty stats
  Map<String, DifficultyStats> difficultyStats;

  // Global stats
  int totalGamesPlayed;
  int totalGamesCompleted;
  int currentStreak;
  int longestStreak;
  DateTime? lastPlayedDate;

  GameStatistics({
    Map<String, DifficultyStats>? difficultyStats,
    this.totalGamesPlayed = 0,
    this.totalGamesCompleted = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastPlayedDate,
  }) : difficultyStats = difficultyStats ?? _initializeStats();

  /// Initialize stats for all difficulty levels
  static Map<String, DifficultyStats> _initializeStats() {
    return {
      'beginner': DifficultyStats(),
      'easy': DifficultyStats(),
      'medium': DifficultyStats(),
      'hard': DifficultyStats(),
    };
  }

  /// Record a completed or incomplete game
  void recordGame({
    required String difficulty,
    required bool completed,
    required Duration timeTaken,
    required int moveCount,
  }) {
    // Normalize difficulty name
    difficulty = difficulty.toLowerCase();

    // Ensure difficulty exists
    if (!difficultyStats.containsKey(difficulty)) {
      difficultyStats[difficulty] = DifficultyStats();
    }

    // Update global stats
    totalGamesPlayed++;

    if (completed) {
      totalGamesCompleted++;

      // Record in difficulty-specific stats
      difficultyStats[difficulty]!.recordGame(timeTaken, moveCount);

      // Update streak
      updateStreak(true);
    } else {
      // Incomplete game
      difficultyStats[difficulty]!.recordIncompleteGame();
      updateStreak(false);
    }

    // Update last played date
    lastPlayedDate = DateTime.now();
  }

  /// Update win streak
  void updateStreak(bool won) {
    final today = DateTime.now();
    final lastPlayed = lastPlayedDate;

    // Check if this is a new day
    bool isNewDay = lastPlayed == null ||
        today.year != lastPlayed.year ||
        today.month != lastPlayed.month ||
        today.day != lastPlayed.day;

    if (won) {
      if (isNewDay) {
        currentStreak++;
      }
      // If same day, don't increment streak (only one game per day counts)

      // Update longest streak
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }
    } else {
      // Reset streak on loss
      currentStreak = 0;
    }
  }

  /// Get overall completion rate
  double get overallCompletionRate {
    if (totalGamesPlayed == 0) return 0.0;
    return (totalGamesCompleted / totalGamesPlayed) * 100;
  }

  /// Get total time spent playing (approximate, based on completed games)
  Duration get totalPlayTime {
    int totalSeconds = 0;

    for (var stats in difficultyStats.values) {
      for (var time in stats.recentTimes) {
        totalSeconds += time.inSeconds;
      }
    }

    return Duration(seconds: totalSeconds);
  }

  /// Get best time across all difficulties
  Duration? get overallBestTime {
    Duration? best;

    for (var stats in difficultyStats.values) {
      if (stats.bestTime != null) {
        if (best == null || stats.bestTime! < best) {
          best = stats.bestTime;
        }
      }
    }

    return best;
  }

  /// Reset all statistics
  void reset() {
    difficultyStats = _initializeStats();
    totalGamesPlayed = 0;
    totalGamesCompleted = 0;
    currentStreak = 0;
    longestStreak = 0;
    lastPlayedDate = null;
  }

  /// Serialization
  Map<String, dynamic> toJson() {
    return {
      'difficultyStats': difficultyStats
          .map((key, value) => MapEntry(key, value.toJson())),
      'totalGamesPlayed': totalGamesPlayed,
      'totalGamesCompleted': totalGamesCompleted,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastPlayedDate': lastPlayedDate?.toIso8601String(),
    };
  }

  /// Deserialization
  factory GameStatistics.fromJson(Map<String, dynamic> json) {
    Map<String, DifficultyStats> stats = {};

    if (json['difficultyStats'] != null) {
      final diffStats = json['difficultyStats'] as Map<String, dynamic>;
      diffStats.forEach((key, value) {
        stats[key] = DifficultyStats.fromJson(value as Map<String, dynamic>);
      });
    }

    // Ensure all difficulty levels exist
    for (var difficulty in ['beginner', 'easy', 'medium', 'hard']) {
      if (!stats.containsKey(difficulty)) {
        stats[difficulty] = DifficultyStats();
      }
    }

    return GameStatistics(
      difficultyStats: stats,
      totalGamesPlayed: json['totalGamesPlayed'] as int? ?? 0,
      totalGamesCompleted: json['totalGamesCompleted'] as int? ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      lastPlayedDate: json['lastPlayedDate'] != null
          ? DateTime.parse(json['lastPlayedDate'] as String)
          : null,
    );
  }

  /// Load from SharedPreferences
  static Future<GameStatistics> loadFromPrefs(SharedPreferences prefs) async {
    try {
      final jsonString = prefs.getString('game_statistics');
      if (jsonString == null) return GameStatistics();

      // For simple storage, we'll use individual keys
      return GameStatistics(
        totalGamesPlayed: prefs.getInt('stats_total_played') ?? 0,
        totalGamesCompleted: prefs.getInt('stats_total_completed') ?? 0,
        currentStreak: prefs.getInt('stats_current_streak') ?? 0,
        longestStreak: prefs.getInt('stats_longest_streak') ?? 0,
        lastPlayedDate: prefs.getString('stats_last_played') != null
            ? DateTime.parse(prefs.getString('stats_last_played')!)
            : null,
      );
    } catch (e) {
      return GameStatistics();
    }
  }

  /// Save to SharedPreferences
  Future<void> saveToPrefs(SharedPreferences prefs) async {
    try {
      await prefs.setInt('stats_total_played', totalGamesPlayed);
      await prefs.setInt('stats_total_completed', totalGamesCompleted);
      await prefs.setInt('stats_current_streak', currentStreak);
      await prefs.setInt('stats_longest_streak', longestStreak);
      if (lastPlayedDate != null) {
        await prefs.setString('stats_last_played', lastPlayedDate!.toIso8601String());
      }

      // Save difficulty stats
      for (var entry in difficultyStats.entries) {
        final prefix = 'stats_${entry.key}';
        final stats = entry.value;
        await prefs.setInt('${prefix}_played', stats.gamesPlayed);
        await prefs.setInt('${prefix}_completed', stats.gamesCompleted);
        if (stats.bestTime != null) {
          await prefs.setInt('${prefix}_best_time', stats.bestTime!.inSeconds);
        }
        if (stats.averageTime != null) {
          await prefs.setInt('${prefix}_avg_time', stats.averageTime!.inSeconds);
        }
        await prefs.setInt('${prefix}_total_moves', stats.totalMoves);
      }
    } catch (e) {
      // Fail silently
    }
  }

  @override
  String toString() {
    return 'GameStatistics(played: $totalGamesPlayed, completed: $totalGamesCompleted, streak: $currentStreak)';
  }
}
