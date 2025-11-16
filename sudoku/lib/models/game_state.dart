import 'move_history.dart';
import 'pencil_marks.dart';

class GameState {
  List<List<int>> currentGrid;
  List<List<int>> initialGrid;
  List<List<int>> solutionGrid;

  PencilMarks pencilMarks;
  MoveHistory moveHistory;

  String difficulty;
  DateTime startTime;
  Duration elapsedTime;
  bool isPaused;
  bool isCompleted;

  int moveCount;

  GameState({
    required this.currentGrid,
    required this.initialGrid,
    required this.solutionGrid,
    required this.difficulty,
    PencilMarks? pencilMarks,
    MoveHistory? moveHistory,
    DateTime? startTime,
    Duration? elapsedTime,
    this.isPaused = false,
    this.isCompleted = false,
    this.moveCount = 0,
  })  : pencilMarks = pencilMarks ?? PencilMarks(),
        moveHistory = moveHistory ?? MoveHistory(),
        startTime = startTime ?? DateTime.now(),
        elapsedTime = elapsedTime ?? Duration.zero;

  /// Create from existing game (for migration from old code)
  factory GameState.fromExistingGame({
    required List<List<int>> game,
    required List<List<int>> gameCopy,
    required List<List<int>> gameSolved,
    required String difficulty,
  }) {
    return GameState(
      currentGrid: _deepCopyGrid(game),
      initialGrid: _deepCopyGrid(gameCopy),
      solutionGrid: _deepCopyGrid(gameSolved),
      difficulty: difficulty,
    );
  }

  /// Create a new empty game state
  factory GameState.empty() {
    final emptyGrid = List.generate(9, (_) => List.filled(9, 0));
    return GameState(
      currentGrid: emptyGrid,
      initialGrid: emptyGrid,
      solutionGrid: emptyGrid,
      difficulty: 'easy',
    );
  }

  /// Check if there's a game in progress (not completed and has moves)
  bool hasInProgressGame() => !isCompleted && moveCount > 0;

  /// Check if the current state is valid
  bool isValid() {
    return currentGrid.length == 9 &&
        initialGrid.length == 9 &&
        solutionGrid.length == 9 &&
        currentGrid.every((row) => row.length == 9) &&
        initialGrid.every((row) => row.length == 9) &&
        solutionGrid.every((row) => row.length == 9);
  }

  /// Deep copy the game state
  GameState copy() {
    return GameState(
      currentGrid: _deepCopyGrid(currentGrid),
      initialGrid: _deepCopyGrid(initialGrid),
      solutionGrid: _deepCopyGrid(solutionGrid),
      difficulty: difficulty,
      pencilMarks: pencilMarks.copy(),
      moveHistory: MoveHistory.fromJson(moveHistory.toJson()),
      startTime: startTime,
      elapsedTime: elapsedTime,
      isPaused: isPaused,
      isCompleted: isCompleted,
      moveCount: moveCount,
    );
  }

  /// Serialization for saving
  Map<String, dynamic> toJson() {
    return {
      'currentGrid': currentGrid,
      'initialGrid': initialGrid,
      'solutionGrid': solutionGrid,
      'pencilMarks': pencilMarks.toJson(),
      'moveHistory': moveHistory.toJson(),
      'difficulty': difficulty,
      'startTime': startTime.toIso8601String(),
      'elapsedTime': elapsedTime.inSeconds,
      'isPaused': isPaused,
      'isCompleted': isCompleted,
      'moveCount': moveCount,
      'version': 1, // For future migration compatibility
    };
  }

  /// Deserialization for loading
  factory GameState.fromJson(Map<String, dynamic> json) {
    try {
      return GameState(
        currentGrid: _parseGrid(json['currentGrid']),
        initialGrid: _parseGrid(json['initialGrid']),
        solutionGrid: _parseGrid(json['solutionGrid']),
        pencilMarks: json['pencilMarks'] != null
            ? PencilMarks.fromJson(json['pencilMarks'] as Map<String, dynamic>)
            : PencilMarks(),
        moveHistory: json['moveHistory'] != null
            ? MoveHistory.fromJson(json['moveHistory'] as Map<String, dynamic>)
            : MoveHistory(),
        difficulty: json['difficulty'] as String? ?? 'easy',
        startTime: json['startTime'] != null
            ? DateTime.parse(json['startTime'] as String)
            : DateTime.now(),
        elapsedTime: json['elapsedTime'] != null
            ? Duration(seconds: json['elapsedTime'] as int)
            : Duration.zero,
        isPaused: json['isPaused'] as bool? ?? false,
        isCompleted: json['isCompleted'] as bool? ?? false,
        moveCount: json['moveCount'] as int? ?? 0,
      );
    } catch (e) {
      // Return empty state if parsing fails
      return GameState.empty();
    }
  }

  /// Helper: Deep copy a 9x9 grid
  static List<List<int>> _deepCopyGrid(List<List<int>> grid) {
    return grid.map((row) => List<int>.from(row)).toList();
  }

  /// Helper: Parse grid from JSON (handles type conversions)
  static List<List<int>> _parseGrid(dynamic gridData) {
    if (gridData == null) {
      return List.generate(9, (_) => List.filled(9, 0));
    }

    final grid = gridData as List<dynamic>;
    return grid.map((row) {
      final rowList = row as List<dynamic>;
      return rowList.map((cell) => cell as int).toList();
    }).toList();
  }

  @override
  String toString() {
    return 'GameState(difficulty: $difficulty, moves: $moveCount, completed: $isCompleted, paused: $isPaused)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is GameState &&
        difficulty == other.difficulty &&
        moveCount == other.moveCount &&
        isCompleted == other.isCompleted &&
        isPaused == other.isPaused;
  }

  @override
  int get hashCode {
    return difficulty.hashCode ^
        moveCount.hashCode ^
        isCompleted.hashCode ^
        isPaused.hashCode;
  }
}
