# Implementation Plan: Five Core Features

> **Features:** Timer & Statistics | Undo/Redo | Pencil Marks | Number Highlighting | Save Game State
>
> **Estimated Total Effort:** 3-4 weeks
>
> **Created:** 2025-11-16

---

## Table of Contents

1. [Overview & Architecture](#overview--architecture)
2. [Phase 1: Foundation & Data Models](#phase-1-foundation--data-models)
3. [Phase 2: Undo/Redo System](#phase-2-undoredo-system)
4. [Phase 3: Timer & Statistics](#phase-3-timer--statistics)
5. [Phase 4: Pencil Marks](#phase-4-pencil-marks)
6. [Phase 5: Number Highlighting](#phase-5-number-highlighting)
7. [Phase 6: Save Game State](#phase-6-save-game-state)
8. [Testing Strategy](#testing-strategy)
9. [Future Enhancements](#future-enhancements)

---

## Overview & Architecture

### Design Principles

1. **Modularity**: Follow existing pattern of extracting features into separate files
2. **State Management**: Extend current `HomePageState` approach, add new state classes where needed
3. **Persistence**: Use `shared_preferences` for all persistent data
4. **Backward Compatibility**: Gracefully handle missing/corrupted saved data
5. **Performance**: Minimize rebuilds, use const constructors where possible

### New File Structure

```
sudoku/lib/
├── main.dart                          # Modified: add new state management
├── styles.dart                        # Modified: add highlight colors
├── board_style.dart                   # Modified: pencil mark rendering
├── models/                            # NEW directory
│   ├── game_state.dart               # Game state model with serialization
│   ├── move_history.dart             # Move/undo data structure
│   ├── statistics.dart               # Stats data model
│   └── pencil_marks.dart             # Pencil mark data structure
├── utils/                             # NEW directory
│   ├── storage_manager.dart          # SharedPreferences wrapper
│   ├── timer_controller.dart         # Game timer logic
│   └── game_serializer.dart          # JSON serialization helpers
├── alerts/
│   ├── all.dart                      # Modified: add new exports
│   ├── numbers.dart                  # Modified: add pencil mark mode
│   ├── statistics.dart               # NEW: statistics display
│   └── ...existing files...
└── widgets/                           # NEW directory (optional)
    └── sudoku_cell.dart              # Extracted cell rendering (optional refactor)
```

---

## Phase 1: Foundation & Data Models

**Duration:** 3-4 days
**Dependencies:** None
**Risk:** Low

### 1.1 Create Data Models

#### File: `sudoku/lib/models/move_history.dart`

```dart
class GameMove {
  final int row;
  final int col;
  final int? previousValue;        // null for empty
  final int? newValue;             // null for erase
  final List<int>? previousNotes;  // For pencil marks
  final List<int>? newNotes;
  final DateTime timestamp;

  GameMove({
    required this.row,
    required this.col,
    this.previousValue,
    this.newValue,
    this.previousNotes,
    this.newNotes,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  // Serialization
  Map<String, dynamic> toJson();
  factory GameMove.fromJson(Map<String, dynamic> json);
}

class MoveHistory {
  final List<GameMove> _undoStack = [];
  final List<GameMove> _redoStack = [];

  void addMove(GameMove move);
  GameMove? undo();
  GameMove? redo();
  void clear();
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
}
```

**Why:** Centralizes undo/redo logic, supports future analytics

---

#### File: `sudoku/lib/models/statistics.dart`

```dart
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

  static Map<String, DifficultyStats> _initializeStats() {
    return {
      'beginner': DifficultyStats(),
      'easy': DifficultyStats(),
      'medium': DifficultyStats(),
      'hard': DifficultyStats(),
    };
  }

  void recordGame({
    required String difficulty,
    required bool completed,
    required Duration timeTaken,
    required int moveCount,
  });

  void updateStreak(bool won);

  // Serialization
  Map<String, dynamic> toJson();
  factory GameStatistics.fromJson(Map<String, dynamic> json);
  static GameStatistics loadFromPrefs(SharedPreferences prefs);
  Future<void> saveToPrefs(SharedPreferences prefs);
}

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

  void recordGame(Duration time, int moves);
  void _updateAverageTime();

  Map<String, dynamic> toJson();
  factory DifficultyStats.fromJson(Map<String, dynamic> json);
}
```

**Why:** Comprehensive stats system, extensible for future achievements

---

#### File: `sudoku/lib/models/pencil_marks.dart`

```dart
class PencilMarks {
  // 9x9 grid of sets (each cell can have multiple candidate numbers)
  late List<List<Set<int>>> _marks;

  PencilMarks() {
    _marks = List.generate(9, (_) => List.generate(9, (_) => <int>{}));
  }

  // Get marks for a cell
  Set<int> getMarks(int row, int col) => _marks[row][col];

  // Toggle a mark (add if absent, remove if present)
  void toggleMark(int row, int col, int number) {
    if (_marks[row][col].contains(number)) {
      _marks[row][col].remove(number);
    } else {
      _marks[row][col].add(number);
    }
  }

  // Set all marks for a cell
  void setMarks(int row, int col, Set<int> marks) {
    _marks[row][col] = Set.from(marks);
  }

  // Clear marks for a cell
  void clearMarks(int row, int col) {
    _marks[row][col].clear();
  }

  // Clear all marks
  void clearAll() {
    for (var row in _marks) {
      for (var cell in row) {
        cell.clear();
      }
    }
  }

  // Auto-clear marks when number is placed
  void clearRelatedMarks(int row, int col, int number) {
    // Clear in row
    for (int c = 0; c < 9; c++) {
      _marks[row][c].remove(number);
    }
    // Clear in column
    for (int r = 0; r < 9; r++) {
      _marks[r][col].remove(number);
    }
    // Clear in 3x3 box
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        _marks[r][c].remove(number);
      }
    }
  }

  // Serialization
  Map<String, dynamic> toJson();
  factory PencilMarks.fromJson(Map<String, dynamic> json);

  // Deep copy
  PencilMarks copy();
}
```

**Why:** Clean separation of pencil mark logic from main game state

---

#### File: `sudoku/lib/models/game_state.dart`

```dart
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

  // Create from existing game (for migration)
  factory GameState.fromExistingGame({
    required List<List<int>> game,
    required List<List<int>> gameCopy,
    required List<List<int>> gameSolved,
    required String difficulty,
  }) {
    return GameState(
      currentGrid: game,
      initialGrid: gameCopy,
      solutionGrid: gameSolved,
      difficulty: difficulty,
    );
  }

  // Serialization for saving
  Map<String, dynamic> toJson();
  factory GameState.fromJson(Map<String, dynamic> json);

  // Deep copy
  GameState copy();

  // Helper methods
  bool hasInProgressGame() => !isCompleted && moveCount > 0;
}
```

**Why:** Single source of truth for game state, easy to serialize/restore

---

### 1.2 Create Utility Classes

#### File: `sudoku/lib/utils/storage_manager.dart`

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_state.dart';
import '../models/statistics.dart';

class StorageManager {
  static const String _keyGameState = 'saved_game_state';
  static const String _keyStatistics = 'game_statistics';
  static const String _keySettings = 'app_settings';

  final SharedPreferences _prefs;

  StorageManager(this._prefs);

  static Future<StorageManager> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageManager(prefs);
  }

  // Game State
  Future<bool> saveGameState(GameState state) async {
    try {
      final json = jsonEncode(state.toJson());
      return await _prefs.setString(_keyGameState, json);
    } catch (e) {
      print('Error saving game state: $e');
      return false;
    }
  }

  GameState? loadGameState() {
    try {
      final json = _prefs.getString(_keyGameState);
      if (json == null) return null;
      return GameState.fromJson(jsonDecode(json));
    } catch (e) {
      print('Error loading game state: $e');
      return null;
    }
  }

  Future<bool> clearGameState() async {
    return await _prefs.remove(_keyGameState);
  }

  // Statistics
  Future<bool> saveStatistics(GameStatistics stats) async {
    try {
      final json = jsonEncode(stats.toJson());
      return await _prefs.setString(_keyStatistics, json);
    } catch (e) {
      print('Error saving statistics: $e');
      return false;
    }
  }

  GameStatistics loadStatistics() {
    try {
      final json = _prefs.getString(_keyStatistics);
      if (json == null) return GameStatistics();
      return GameStatistics.fromJson(jsonDecode(json));
    } catch (e) {
      print('Error loading statistics: $e');
      return GameStatistics();
    }
  }

  // Settings (existing + new)
  Future<bool> saveSetting(String key, dynamic value) async {
    if (value is String) {
      return await _prefs.setString(key, value);
    } else if (value is bool) {
      return await _prefs.setBool(key, value);
    } else if (value is int) {
      return await _prefs.setInt(key, value);
    }
    return false;
  }

  T? getSetting<T>(String key, {T? defaultValue}) {
    if (T == String) {
      return (_prefs.getString(key) ?? defaultValue) as T?;
    } else if (T == bool) {
      return (_prefs.getBool(key) ?? defaultValue) as T?;
    } else if (T == int) {
      return (_prefs.getInt(key) ?? defaultValue) as T?;
    }
    return defaultValue;
  }
}
```

**Why:** Centralized storage, easier testing, cleaner main.dart

---

#### File: `sudoku/lib/utils/timer_controller.dart`

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';

class TimerController extends ChangeNotifier {
  Duration _elapsedTime = Duration.zero;
  DateTime? _startTime;
  Timer? _timer;
  bool _isPaused = false;

  Duration get elapsedTime => _elapsedTime;
  bool get isPaused => _isPaused;
  bool get isRunning => _timer != null && !_isPaused;

  // Start or resume timer
  void start() {
    if (_timer != null && !_isPaused) return; // Already running

    _startTime = DateTime.now().subtract(_elapsedTime);
    _isPaused = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedTime = DateTime.now().difference(_startTime!);
      notifyListeners();
    });

    notifyListeners();
  }

  // Pause timer
  void pause() {
    if (_timer == null || _isPaused) return;

    _isPaused = true;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  // Stop and reset timer
  void reset() {
    _timer?.cancel();
    _timer = null;
    _elapsedTime = Duration.zero;
    _startTime = null;
    _isPaused = false;
    notifyListeners();
  }

  // Set time (for loading saved games)
  void setTime(Duration duration) {
    _elapsedTime = duration;
    notifyListeners();
  }

  // Format time as string
  String formatTime() {
    int hours = _elapsedTime.inHours;
    int minutes = _elapsedTime.inMinutes.remainder(60);
    int seconds = _elapsedTime.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
```

**Why:** Separate timer logic, uses ChangeNotifier for efficient UI updates

---

### 1.3 Update `pubspec.yaml`

No new dependencies needed! All features use existing packages:
- `shared_preferences` - already included
- `flutter` core packages - for UI

---

## Phase 2: Undo/Redo System

**Duration:** 2-3 days
**Dependencies:** Phase 1 complete
**Risk:** Medium (requires careful state management)

### 2.1 Integrate Move History into `main.dart`

**Changes to `HomePageState`:**

```dart
class HomePageState extends State<HomePage> {
  // ... existing fields ...

  // NEW: Add move history
  late MoveHistory moveHistory;
  late PencilMarks pencilMarks;

  @override
  void initState() {
    super.initState();
    moveHistory = MoveHistory();
    pencilMarks = PencilMarks();
    // ... rest of initialization ...
  }

  // MODIFIED: Update callback to record moves
  void callback(List<int> index, int? number) {
    setState(() {
      if (number == null) return;

      final row = index[0];
      final col = index[1];
      final previousValue = game[row][col] == 0 ? null : game[row][col];
      final newValue = number == 0 ? null : number;

      // Record move
      moveHistory.addMove(GameMove(
        row: row,
        col: col,
        previousValue: previousValue,
        newValue: newValue,
        previousNotes: pencilMarks.getMarks(row, col).toList(),
        newNotes: null, // Not using notes in this move
      ));

      // Apply move
      game[row][col] = number;

      if (number != 0) {
        // Clear pencil marks when placing number
        pencilMarks.clearMarks(row, col);
        pencilMarks.clearRelatedMarks(row, col, number);
        checkResult();
      }
    });
  }

  // NEW: Undo method
  void undoMove() {
    final move = moveHistory.undo();
    if (move == null) return;

    setState(() {
      game[move.row][move.col] = move.previousValue ?? 0;

      // Restore pencil marks
      if (move.previousNotes != null) {
        pencilMarks.setMarks(move.row, move.col, move.previousNotes!.toSet());
      }
    });
  }

  // NEW: Redo method
  void redoMove() {
    final move = moveHistory.redo();
    if (move == null) return;

    setState(() {
      game[move.row][move.col] = move.newValue ?? 0;

      // Restore pencil marks
      if (move.newNotes != null) {
        pencilMarks.setMarks(move.row, move.col, move.newNotes!.toSet());
      } else if (move.newValue != null && move.newValue != 0) {
        pencilMarks.clearMarks(move.row, move.col);
      }
    });
  }

  // MODIFIED: Clear history on new/restart game
  void newGame([String difficulty = 'easy']) {
    setState(() {
      isFABDisabled = !isFABDisabled;
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() {
        setGame(2, difficulty);
        moveHistory.clear(); // Clear undo/redo
        pencilMarks.clearAll(); // Clear pencil marks
        isButtonDisabled = isButtonDisabled ? !isButtonDisabled : isButtonDisabled;
        gameOver = false;
        isFABDisabled = !isFABDisabled;
      });
    });
  }

  void restartGame() {
    setState(() {
      game = copyGrid(gameCopy);
      moveHistory.clear(); // Clear undo/redo
      pencilMarks.clearAll(); // Clear pencil marks
      isButtonDisabled = isButtonDisabled ? !isButtonDisabled : isButtonDisabled;
      gameOver = false;
    });
  }
}
```

### 2.2 Add Undo/Redo UI

**Option A: Add to AppBar (Desktop)**

```dart
// In build() method, modify AppBar actions
AppBar(
  centerTitle: true,
  title: const Text('Sudoku'),
  backgroundColor: Styles.primaryColor,
  actions: [
    // Undo button
    IconButton(
      icon: const Icon(Icons.undo),
      tooltip: 'Undo',
      onPressed: moveHistory.canUndo && !isButtonDisabled ? undoMove : null,
    ),
    // Redo button
    IconButton(
      icon: const Icon(Icons.redo),
      tooltip: 'Redo',
      onPressed: moveHistory.canRedo && !isButtonDisabled ? redoMove : null,
    ),
    // ... existing desktop buttons ...
  ],
)
```

**Option B: Add to Options Modal Sheet (Mobile)**

```dart
// In showOptionModalSheet(), add before "Restart Game"
ListTile(
  leading: Icon(Icons.undo, color: Styles.foregroundColor),
  title: Text('Undo', style: customStyle),
  enabled: moveHistory.canUndo && !isButtonDisabled,
  onTap: moveHistory.canUndo && !isButtonDisabled ? () {
    Navigator.pop(context);
    Timer(const Duration(milliseconds: 200), undoMove);
  } : null,
),
ListTile(
  leading: Icon(Icons.redo, color: Styles.foregroundColor),
  title: Text('Redo', style: customStyle),
  enabled: moveHistory.canRedo && !isButtonDisabled,
  onTap: moveHistory.canRedo && !isButtonDisabled ? () {
    Navigator.pop(context);
    Timer(const Duration(milliseconds: 200), redoMove);
  } : null,
),
```

**Option C: Floating Action Buttons (Best UX)**

```dart
// Replace single FAB with stack of FABs
Stack(
  alignment: Alignment.bottomRight,
  children: [
    // Redo button (higher)
    Positioned(
      bottom: 140,
      right: 0,
      child: FloatingActionButton(
        mini: true,
        heroTag: 'redo',
        onPressed: moveHistory.canRedo && !isButtonDisabled ? redoMove : null,
        backgroundColor: moveHistory.canRedo && !isButtonDisabled
            ? Styles.primaryColor
            : Styles.primaryColor[900],
        child: const Icon(Icons.redo, size: 20),
      ),
    ),
    // Undo button (middle)
    Positioned(
      bottom: 80,
      right: 0,
      child: FloatingActionButton(
        mini: true,
        heroTag: 'undo',
        onPressed: moveHistory.canUndo && !isButtonDisabled ? undoMove : null,
        backgroundColor: moveHistory.canUndo && !isButtonDisabled
            ? Styles.primaryColor
            : Styles.primaryColor[900],
        child: const Icon(Icons.undo, size: 20),
      ),
    ),
    // Menu button (existing, at bottom)
    Positioned(
      bottom: 0,
      right: 0,
      child: FloatingActionButton(
        heroTag: 'menu',
        foregroundColor: Styles.primaryBackgroundColor,
        backgroundColor: isFABDisabled ? Styles.primaryColor[900] : Styles.primaryColor,
        onPressed: isFABDisabled ? null : () => showOptionModalSheet(context),
        child: const Icon(Icons.menu_rounded),
      ),
    ),
  ],
)
```

**Recommendation:** Use **Option C** for mobile, **Option A** for desktop

---

## Phase 3: Timer & Statistics

**Duration:** 3-4 days
**Dependencies:** Phase 1 complete
**Risk:** Low

### 3.1 Add Timer to Main Game

**Changes to `HomePageState`:**

```dart
class HomePageState extends State<HomePage> {
  // ... existing fields ...

  // NEW: Timer controller
  late TimerController timerController;
  late GameStatistics statistics;
  late StorageManager storageManager;

  @override
  void initState() {
    super.initState();
    timerController = TimerController();

    // Load statistics
    StorageManager.create().then((manager) {
      storageManager = manager;
      statistics = manager.loadStatistics();
      setState(() {});
    });

    // ... rest of initialization ...
  }

  @override
  void dispose() {
    timerController.dispose();
    super.dispose();
  }

  // MODIFIED: Start timer when starting new game
  void newGame([String difficulty = 'easy']) {
    setState(() {
      isFABDisabled = !isFABDisabled;
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() {
        setGame(2, difficulty);
        moveHistory.clear();
        pencilMarks.clearAll();
        timerController.reset(); // Reset timer
        timerController.start(); // Start timer
        isButtonDisabled = isButtonDisabled ? !isButtonDisabled : isButtonDisabled;
        gameOver = false;
        isFABDisabled = !isFABDisabled;
      });
    });
  }

  // MODIFIED: Reset timer on restart
  void restartGame() {
    setState(() {
      game = copyGrid(gameCopy);
      moveHistory.clear();
      pencilMarks.clearAll();
      timerController.reset();
      timerController.start();
      isButtonDisabled = isButtonDisabled ? !isButtonDisabled : isButtonDisabled;
      gameOver = false;
    });
  }

  // MODIFIED: Stop timer and record stats when game completes
  void checkResult() {
    try {
      if (SudokuUtilities.isSolved(game)) {
        isButtonDisabled = !isButtonDisabled;
        gameOver = true;
        timerController.pause(); // Stop timer

        // Record statistics
        statistics.recordGame(
          difficulty: currentDifficultyLevel!,
          completed: true,
          timeTaken: timerController.elapsedTime,
          moveCount: moveHistory._undoStack.length,
        );
        statistics.updateStreak(true);
        storageManager.saveStatistics(statistics);

        Timer(const Duration(milliseconds: 500), () {
          showAnimatedDialog<void>(
              animationType: DialogTransitionType.fadeScale,
              barrierDismissible: true,
              duration: const Duration(milliseconds: 350),
              context: context,
              builder: (_) => AlertGameOver(
                timeTaken: timerController.formatTime(),
                moveCount: moveHistory._undoStack.length,
              )).whenComplete(() {
            // ... existing completion logic ...
          });
        });
      }
    } on InvalidSudokuConfigurationException {
      return;
    }
  }

  // NEW: Pause/Resume game
  void togglePause() {
    setState(() {
      if (timerController.isPaused) {
        timerController.start();
        isButtonDisabled = false;
      } else {
        timerController.pause();
        isButtonDisabled = true;
      }
    });
  }
}
```

### 3.2 Add Timer Display to UI

**Add timer display above the Sudoku board:**

```dart
// In build() method, modify Column children:
Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    // Timer display
    Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pause/Play button
          IconButton(
            icon: Icon(
              timerController.isPaused ? Icons.play_arrow : Icons.pause,
              color: Styles.foregroundColor,
            ),
            onPressed: togglePause,
          ),
          const SizedBox(width: 8),
          // Timer text
          ListenableBuilder(
            listenable: timerController,
            builder: (context, _) {
              return Text(
                timerController.formatTime(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Styles.foregroundColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              );
            },
          ),
        ],
      ),
    ),
    // Existing grid
    ...createRows(),
  ],
)
```

### 3.3 Create Statistics Dialog

#### File: `sudoku/lib/alerts/statistics.dart`

```dart
import 'package:flutter/material.dart';
import '../models/statistics.dart';
import '../styles.dart';

class AlertStatistics extends StatelessWidget {
  final GameStatistics statistics;

  const AlertStatistics({Key? key, required this.statistics}) : super(key: key);

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
                _StatRow('Current Streak', '${statistics.currentStreak} 🔥'),
                _StatRow('Longest Streak', statistics.longestStreak.toString()),
              ],
            ),
            const SizedBox(height: 16),

            // Per-difficulty stats
            _buildDifficultyStats('Beginner', statistics.difficultyStats['beginner']!),
            _buildDifficultyStats('Easy', statistics.difficultyStats['easy']!),
            _buildDifficultyStats('Medium', statistics.difficultyStats['medium']!),
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
        if (stats.bestTime != null)
          _StatRow('Best Time', _formatDuration(stats.bestTime!)),
        if (stats.averageTime != null)
          _StatRow('Avg Time', _formatDuration(stats.averageTime!)),
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
```

### 3.4 Add Statistics to Options Menu

```dart
// In showOptionModalSheet(), add:
ListTile(
  leading: Icon(Icons.bar_chart, color: Styles.foregroundColor),
  title: Text('Statistics', style: customStyle),
  onTap: () {
    Navigator.pop(context);
    Timer(
      const Duration(milliseconds: 200),
      () => showAnimatedDialog<void>(
        animationType: DialogTransitionType.fadeScale,
        barrierDismissible: true,
        duration: const Duration(milliseconds: 350),
        context: outerContext,
        builder: (_) => AlertStatistics(statistics: statistics),
      ),
    );
  },
),
```

### 3.5 Update Game Over Dialog

**Modify `sudoku/lib/alerts/game_over.dart`:**

```dart
// Add parameters to constructor
class AlertGameOver extends StatelessWidget {
  final String? timeTaken;
  final int? moveCount;

  const AlertGameOver({
    Key? key,
    this.timeTaken,
    this.moveCount,
  }) : super(key: key);

  // ... existing code ...

  // Add to content:
  if (timeTaken != null) ...[
    const SizedBox(height: 16),
    Text(
      'Time: $timeTaken',
      style: TextStyle(
        fontSize: 16,
        color: Styles.foregroundColor,
      ),
    ),
  ],
  if (moveCount != null) ...[
    const SizedBox(height: 8),
    Text(
      'Moves: $moveCount',
      style: TextStyle(
        fontSize: 16,
        color: Styles.foregroundColor,
      ),
    ),
  ],
}
```

---

## Phase 4: Pencil Marks

**Duration:** 3-4 days
**Dependencies:** Phase 1 & 2 complete
**Risk:** Medium (complex UI rendering)

### 4.1 Modify Numbers Dialog

**Update `sudoku/lib/alerts/numbers.dart`:**

```dart
class AlertNumbersState extends StatefulWidget {
  final bool isPencilMode;
  final Set<int> currentMarks;

  const AlertNumbersState({
    Key? key,
    this.isPencilMode = false,
    this.currentMarks = const {},
  }) : super(key: key);

  static int? number;
  static Set<int>? pencilMarks;

  @override
  State<StatefulWidget> createState() => AlertNumbers();
}

class AlertNumbers extends State<AlertNumbersState> {
  late Set<int> selectedMarks;

  @override
  void initState() {
    super.initState();
    selectedMarks = Set.from(widget.currentMarks);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Styles.secondaryBackgroundColor,
      title: Text(
        widget.isPencilMode ? 'Pencil Marks' : 'Choose Number',
        style: TextStyle(color: Styles.foregroundColor),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Number grid
          for (int row = 0; row < 3; row++)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int col = 0; col < 3; col++)
                  _buildNumberButton(row * 3 + col + 1),
              ],
            ),

          // Clear button
          if (!widget.isPencilMode)
            TextButton(
              onPressed: () {
                AlertNumbersState.number = 0;
                Navigator.pop(context);
              },
              child: Text(
                'Clear',
                style: TextStyle(color: Styles.secondaryColor),
              ),
            ),

          // Done button for pencil mode
          if (widget.isPencilMode)
            ElevatedButton(
              onPressed: () {
                AlertNumbersState.pencilMarks = selectedMarks;
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Styles.primaryColor,
              ),
              child: const Text('Done'),
            ),
        ],
      ),
    );
  }

  Widget _buildNumberButton(int number) {
    final isSelected = widget.isPencilMode && selectedMarks.contains(number);

    return Container(
      width: 60,
      height: 60,
      margin: const EdgeInsets.all(4),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? Styles.primaryColor
              : Styles.primaryBackgroundColor,
          foregroundColor: Styles.foregroundColor,
        ),
        onPressed: () {
          if (widget.isPencilMode) {
            setState(() {
              if (selectedMarks.contains(number)) {
                selectedMarks.remove(number);
              } else {
                selectedMarks.add(number);
              }
            });
          } else {
            AlertNumbersState.number = number;
            Navigator.pop(context);
          }
        },
        child: Text(
          number.toString(),
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
```

### 4.2 Add Pencil Mode Toggle to Main UI

**Add state field:**

```dart
class HomePageState extends State<HomePage> {
  // ... existing fields ...

  bool isPencilMode = false; // NEW
}
```

**Add toggle button in AppBar or as FAB:**

```dart
// Option A: Add to AppBar actions (desktop)
IconButton(
  icon: Icon(isPencilMode ? Icons.edit : Icons.edit_outlined),
  tooltip: isPencilMode ? 'Normal Mode' : 'Pencil Mode',
  onPressed: () {
    setState(() {
      isPencilMode = !isPencilMode;
    });
  },
  color: isPencilMode ? Colors.yellow : null,
),

// Option B: Add to FAB stack
FloatingActionButton(
  mini: true,
  heroTag: 'pencil',
  backgroundColor: isPencilMode
      ? Colors.yellow[700]
      : Styles.primaryColor,
  onPressed: () {
    setState(() {
      isPencilMode = !isPencilMode;
    });
  },
  child: Icon(
    isPencilMode ? Icons.edit : Icons.edit_outlined,
    size: 20,
    color: isPencilMode ? Colors.black : null,
  ),
),
```

### 4.3 Modify Button Callback for Pencil Marks

**Update callback in `main.dart`:**

```dart
// In createButtons(), modify onPressed:
onPressed: isButtonDisabled || gameCopy[k][i] != 0
    ? null
    : () {
        showAnimatedDialog<void>(
          animationType: DialogTransitionType.fade,
          barrierDismissible: true,
          duration: const Duration(milliseconds: 300),
          context: context,
          builder: (_) => AlertNumbersState(
            isPencilMode: isPencilMode,
            currentMarks: pencilMarks.getMarks(k, i),
          ),
        ).whenComplete(() {
          if (isPencilMode) {
            // Handle pencil marks
            if (AlertNumbersState.pencilMarks != null) {
              setState(() {
                pencilMarks.setMarks(k, i, AlertNumbersState.pencilMarks!);
                AlertNumbersState.pencilMarks = null;
              });
            }
          } else {
            // Handle normal number placement
            callback([k, i], AlertNumbersState.number);
            AlertNumbersState.number = null;
          }
        });
      },
```

### 4.4 Render Pencil Marks in Cells

**Create helper method in `board_style.dart`:**

```dart
Widget buildCellContent(
  int value,
  Set<int> marks,
  bool isOriginal,
  bool gameOver,
) {
  if (value != 0) {
    // Show number
    return Text(
      value.toString(),
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: buttonFontSize()),
    );
  } else if (marks.isNotEmpty) {
    // Show pencil marks in 3x3 grid
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          final number = index + 1;
          final hasMarks = marks.contains(number);

          return Center(
            child: Text(
              hasMarks ? number.toString() : '',
              style: TextStyle(
                fontSize: buttonSize() / 8,
                color: Styles.foregroundColor.withOpacity(0.6),
              ),
            ),
          );
        },
      ),
    );
  } else {
    // Empty cell
    return const Text(' ');
  }
}
```

**Update `createButtons()` in `main.dart`:**

```dart
child: buildCellContent(
  game[k][i],
  pencilMarks.getMarks(k, i),
  gameCopy[k][i] != 0,
  gameOver,
),
```

---

## Phase 5: Number Highlighting

**Duration:** 1-2 days
**Dependencies:** None (can be done in parallel)
**Risk:** Low

### 5.1 Add Selected Cell Tracking

```dart
class HomePageState extends State<HomePage> {
  // ... existing fields ...

  int? selectedRow;
  int? selectedCol;
  int? selectedNumber; // The number in the selected cell
}
```

### 5.2 Add Highlight Color to Styles

**Update `sudoku/lib/styles.dart`:**

```dart
class Styles {
  // ... existing colors ...

  // NEW: Highlight colors
  static Color get highlightColor => primaryColor.withOpacity(0.2);
  static Color get selectedCellColor => primaryColor.withOpacity(0.4);
}
```

### 5.3 Modify Button Color Logic

**Update `board_style.dart`:**

```dart
Color buttonColor(
  int row,
  int col,
  int? selectedRow,
  int? selectedCol,
  int? selectedNumber,
  int currentValue,
) {
  // Selected cell
  if (row == selectedRow && col == selectedCol) {
    return Styles.selectedCellColor;
  }

  // Highlight cells with same number
  if (selectedNumber != null &&
      selectedNumber != 0 &&
      currentValue == selectedNumber) {
    return Styles.highlightColor;
  }

  // Highlight same row/column (optional - can be removed if too busy)
  if (row == selectedRow || col == selectedCol) {
    return Styles.highlightColor.withOpacity(0.1);
  }

  // Original logic
  if ((row >= 0 && row <= 2) || (row >= 6 && row <= 8)) {
    if ((col >= 0 && col <= 2) || (col >= 6 && col <= 8)) {
      return Styles.primaryBackgroundColor;
    } else {
      return Styles.secondaryBackgroundColor;
    }
  } else {
    if ((col >= 3 && col <= 5)) {
      return Styles.primaryBackgroundColor;
    } else {
      return Styles.secondaryBackgroundColor;
    }
  }
}
```

### 5.4 Update Button Creation

**Modify `createButtons()` in `main.dart`:**

```dart
SizedBox(
  // ... existing properties ...
  child: TextButton(
    onPressed: isButtonDisabled || gameCopy[k][i] != 0
        ? null
        : () {
            // Set selected cell
            setState(() {
              selectedRow = k;
              selectedCol = i;
              selectedNumber = game[k][i];
            });

            // Show dialog
            showAnimatedDialog<void>(
              // ... existing dialog code ...
            ).whenComplete(() {
              // Clear selection after dialog closes
              setState(() {
                selectedRow = null;
                selectedCol = null;
                selectedNumber = null;
              });

              // ... existing completion code ...
            });
          },
    style: ButtonStyle(
      backgroundColor: MaterialStateProperty.all<Color>(
        buttonColor(k, i, selectedRow, selectedCol, selectedNumber, game[k][i]),
      ),
      // ... rest of styling ...
    ),
    // ... child ...
  ),
)
```

---

## Phase 6: Save Game State

**Duration:** 2-3 days
**Dependencies:** All previous phases complete
**Risk:** Low

### 6.1 Auto-Save Game State

**Add auto-save logic to `main.dart`:**

```dart
class HomePageState extends State<HomePage> {
  // ... existing fields ...

  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();

    // ... existing initialization ...

    // Set up auto-save every 30 seconds
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _saveGameState();
    });

    // Load saved game on startup
    _loadSavedGame();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    timerController.dispose();
    super.dispose();
  }

  Future<void> _saveGameState() async {
    if (gameOver || firstRun) return; // Don't save completed/unstarted games

    final state = GameState(
      currentGrid: game,
      initialGrid: gameCopy,
      solutionGrid: gameSolved,
      difficulty: currentDifficultyLevel!,
      pencilMarks: pencilMarks,
      moveHistory: moveHistory,
      elapsedTime: timerController.elapsedTime,
      isPaused: timerController.isPaused,
      isCompleted: gameOver,
      moveCount: moveHistory._undoStack.length,
    );

    await storageManager.saveGameState(state);
  }

  Future<void> _loadSavedGame() async {
    final savedState = storageManager.loadGameState();

    if (savedState != null && !savedState.isCompleted) {
      // Show dialog asking to resume
      showAnimatedDialog<void>(
        animationType: DialogTransitionType.fadeScale,
        barrierDismissible: false,
        duration: const Duration(milliseconds: 350),
        context: context,
        builder: (_) => AlertResumeGame(savedState: savedState),
      ).whenComplete(() {
        if (AlertResumeGame.shouldResume) {
          _resumeGame(savedState);
        } else {
          storageManager.clearGameState();
        }
        AlertResumeGame.shouldResume = false;
      });
    }
  }

  void _resumeGame(GameState state) {
    setState(() {
      game = state.currentGrid;
      gameCopy = state.initialGrid;
      gameSolved = state.solutionGrid;
      currentDifficultyLevel = state.difficulty;
      pencilMarks = state.pencilMarks;
      moveHistory = state.moveHistory;

      timerController.setTime(state.elapsedTime);
      if (!state.isPaused) {
        timerController.start();
      }

      gameOver = false;
      firstRun = false;
    });
  }

  // MODIFIED: Clear saved game when starting new game
  void newGame([String difficulty = 'easy']) {
    storageManager.clearGameState(); // Clear saved game

    setState(() {
      isFABDisabled = !isFABDisabled;
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() {
        setGame(2, difficulty);
        moveHistory.clear();
        pencilMarks.clearAll();
        timerController.reset();
        timerController.start();
        isButtonDisabled = isButtonDisabled ? !isButtonDisabled : isButtonDisabled;
        gameOver = false;
        isFABDisabled = !isFABDisabled;
      });
    });
  }

  // MODIFIED: Save on pause
  void togglePause() {
    setState(() {
      if (timerController.isPaused) {
        timerController.start();
        isButtonDisabled = false;
      } else {
        timerController.pause();
        isButtonDisabled = true;
        _saveGameState(); // Save when pausing
      }
    });
  }
}
```

### 6.2 Create Resume Game Dialog

#### File: `sudoku/lib/alerts/resume_game.dart`

```dart
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../styles.dart';

class AlertResumeGame extends StatelessWidget {
  final GameState savedState;

  static bool shouldResume = false;

  const AlertResumeGame({Key? key, required this.savedState}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Styles.secondaryBackgroundColor,
      title: Text(
        'Resume Game?',
        style: TextStyle(color: Styles.foregroundColor),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You have an unfinished game:',
            style: TextStyle(color: Styles.foregroundColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Difficulty: ${_capitalize(savedState.difficulty)}',
            style: TextStyle(
              color: Styles.foregroundColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Time: ${_formatDuration(savedState.elapsedTime)}',
            style: TextStyle(color: Styles.foregroundColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Moves: ${savedState.moveCount}',
            style: TextStyle(color: Styles.foregroundColor),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            shouldResume = false;
            Navigator.pop(context);
          },
          child: Text(
            'New Game',
            style: TextStyle(color: Styles.secondaryColor),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            shouldResume = true;
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Styles.primaryColor,
          ),
          child: const Text('Resume'),
        ),
      ],
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
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
```

### 6.3 Update Barrel Export

**Add to `sudoku/lib/alerts/all.dart`:**

```dart
export 'resume_game.dart';
export 'statistics.dart';
```

### 6.4 Save on App Lifecycle Changes

**Add lifecycle observer to `main.dart`:**

```dart
class HomePageState extends State<HomePage> with WidgetsBindingObserver {
  // ... existing code ...

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // ... rest of init ...
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveTimer?.cancel();
    timerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Save game when app goes to background
      _saveGameState();
      if (!gameOver) {
        timerController.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      // Resume timer if game was active
      if (!gameOver && !timerController.isPaused) {
        timerController.start();
      }
    }
  }
}
```

---

## Testing Strategy

### Unit Tests (Priority: High)

**File: `sudoku/test/models/move_history_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/move_history.dart';

void main() {
  group('MoveHistory', () {
    test('adds and undoes moves correctly', () {
      final history = MoveHistory();
      final move = GameMove(row: 0, col: 0, previousValue: null, newValue: 5);

      history.addMove(move);
      expect(history.canUndo, true);
      expect(history.canRedo, false);

      final undoneMove = history.undo();
      expect(undoneMove, equals(move));
      expect(history.canUndo, false);
      expect(history.canRedo, true);
    });

    test('clears redo stack when new move added', () {
      final history = MoveHistory();
      history.addMove(GameMove(row: 0, col: 0, newValue: 5));
      history.undo();
      expect(history.canRedo, true);

      history.addMove(GameMove(row: 0, col: 1, newValue: 3));
      expect(history.canRedo, false);
    });
  });
}
```

**File: `sudoku/test/models/pencil_marks_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/pencil_marks.dart';

void main() {
  group('PencilMarks', () {
    test('toggles marks correctly', () {
      final marks = PencilMarks();

      marks.toggleMark(0, 0, 5);
      expect(marks.getMarks(0, 0), contains(5));

      marks.toggleMark(0, 0, 5);
      expect(marks.getMarks(0, 0), isEmpty);
    });

    test('clears related marks correctly', () {
      final marks = PencilMarks();

      // Add mark 5 to multiple cells
      marks.toggleMark(0, 0, 5); // Same row
      marks.toggleMark(0, 5, 5); // Same row
      marks.toggleMark(5, 0, 5); // Same column
      marks.toggleMark(1, 1, 5); // Same 3x3 box

      marks.clearRelatedMarks(0, 0, 5);

      expect(marks.getMarks(0, 0), isEmpty);
      expect(marks.getMarks(0, 5), isEmpty);
      expect(marks.getMarks(5, 0), isEmpty);
      expect(marks.getMarks(1, 1), isEmpty);
    });
  });
}
```

### Integration Tests

**File: `sudoku/test/integration/game_flow_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/game_state.dart';
import 'package:sudoku/models/statistics.dart';

void main() {
  testWidgets('Complete game flow with stats recording', (tester) async {
    // Test complete flow:
    // 1. Start new game
    // 2. Make moves
    // 3. Undo/redo
    // 4. Complete game
    // 5. Verify stats updated

    // Implementation depends on widget structure
  });
}
```

### Manual Testing Checklist

- [ ] **Undo/Redo**
  - [ ] Undo after placing number
  - [ ] Undo after erasing number
  - [ ] Redo after undo
  - [ ] Undo with pencil marks
  - [ ] Cannot undo pre-filled numbers
  - [ ] Undo/redo buttons disabled appropriately

- [ ] **Timer**
  - [ ] Starts on new game
  - [ ] Resets on restart
  - [ ] Pauses/resumes correctly
  - [ ] Displays correct time format
  - [ ] Stops when game completed

- [ ] **Statistics**
  - [ ] Records completed games
  - [ ] Tracks best time per difficulty
  - [ ] Calculates averages correctly
  - [ ] Updates streak on wins
  - [ ] Persists across app restarts

- [ ] **Pencil Marks**
  - [ ] Toggle mode works
  - [ ] Marks display correctly in cells
  - [ ] Multiple marks can be selected
  - [ ] Marks clear when number placed
  - [ ] Related marks clear correctly
  - [ ] Undo restores pencil marks

- [ ] **Number Highlighting**
  - [ ] Selected cell highlighted
  - [ ] Same numbers highlighted
  - [ ] Highlights clear after dialog closes
  - [ ] Works with different accent colors

- [ ] **Save Game**
  - [ ] Auto-saves periodically
  - [ ] Saves on pause
  - [ ] Saves on app background
  - [ ] Resume dialog shows on restart
  - [ ] Saved state loads correctly
  - [ ] Clears on new game

---

## Future Enhancements

### Phase 7 (Optional Extensions)

1. **Smart Hints**
   - Use existing solver to suggest next move
   - Highlight cells with only one possibility
   - Show conflicts/errors

2. **Keyboard Support (Desktop)**
   - Number keys 1-9 for input
   - Arrow keys for navigation
   - Ctrl+Z / Ctrl+Y for undo/redo
   - Space for pencil mode toggle

3. **Sound Effects**
   - Success sound on completion
   - Click sounds (toggleable)
   - Error sound on conflicts

4. **Achievements**
   - Badge system based on statistics
   - "Speed Demon", "Perfect Week", etc.
   - Display in statistics screen

5. **Export/Share**
   - Share puzzle code
   - Screenshot with time/stats
   - Export statistics

---

## Implementation Timeline

| Phase | Feature | Duration | Start After |
|-------|---------|----------|-------------|
| 1 | Foundation & Data Models | 3-4 days | Immediate |
| 2 | Undo/Redo System | 2-3 days | Phase 1 |
| 3 | Timer & Statistics | 3-4 days | Phase 1 |
| 4 | Pencil Marks | 3-4 days | Phase 1 & 2 |
| 5 | Number Highlighting | 1-2 days | Anytime |
| 6 | Save Game State | 2-3 days | All phases |

**Total Estimated Time:** 14-20 days (3-4 weeks)

**Parallel Work Opportunities:**
- Phase 5 (Number Highlighting) can be done independently
- Phase 3 (Timer) can start as soon as Phase 1 completes
- Testing can begin as each phase completes

---

## Risk Mitigation

### High-Risk Areas

1. **State Serialization** (Phase 6)
   - **Risk:** Corrupted save data crashes app
   - **Mitigation:** Try-catch all JSON parsing, fallback to new game

2. **Pencil Mark Rendering** (Phase 4)
   - **Risk:** Performance issues with complex UI
   - **Mitigation:** Use const constructors, minimize rebuilds

3. **Move History Memory** (Phase 2)
   - **Risk:** Large undo stacks consume memory
   - **Mitigation:** Limit stack size (e.g., 100 moves max)

### Testing Early

- Test serialization with corrupted data
- Load test with 100+ undo operations
- Test save/resume on different platforms

---

## Success Criteria

Each feature is complete when:

1. ✅ Code follows existing project patterns
2. ✅ Works on web, mobile, and desktop
3. ✅ Persists across app restarts (where applicable)
4. ✅ No crashes or errors in normal use
5. ✅ UI matches existing Material Design style
6. ✅ Manual testing checklist passed
7. ✅ Code committed with descriptive message

---

## Notes for Implementation

### Code Style Consistency

- Follow existing naming conventions (camelCase, PascalCase)
- Use `late` for non-nullable fields initialized in initState
- Prefer `const` constructors where possible
- Use existing color system from `Styles`
- Extract large widgets to separate methods/files

### Performance Considerations

- Use `ListenableBuilder` for timer to avoid full rebuilds
- Don't save game state on every move (use debouncing)
- Limit undo history to reasonable size
- Use `const` for static widgets

### Platform Compatibility

- Test keyboard shortcuts on desktop
- Verify touch targets on mobile (min 48x48)
- Ensure auto-save works on web (localStorage)
- Test window minimize/restore (desktop)

---

**End of Implementation Plan**

Questions or clarifications needed before starting implementation?
