class GameMove {
  final int row;
  final int col;
  final int? previousValue; // null for empty
  final int? newValue; // null for erase
  final List<int>? previousNotes; // For pencil marks
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
  Map<String, dynamic> toJson() {
    return {
      'row': row,
      'col': col,
      'previousValue': previousValue,
      'newValue': newValue,
      'previousNotes': previousNotes,
      'newNotes': newNotes,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory GameMove.fromJson(Map<String, dynamic> json) {
    return GameMove(
      row: json['row'] as int,
      col: json['col'] as int,
      previousValue: json['previousValue'] as int?,
      newValue: json['newValue'] as int?,
      previousNotes: (json['previousNotes'] as List<dynamic>?)?.cast<int>(),
      newNotes: (json['newNotes'] as List<dynamic>?)?.cast<int>(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  String toString() {
    return 'GameMove(row: $row, col: $col, previous: $previousValue, new: $newValue)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is GameMove &&
        other.row == row &&
        other.col == col &&
        other.previousValue == previousValue &&
        other.newValue == newValue;
  }

  @override
  int get hashCode {
    return row.hashCode ^
        col.hashCode ^
        previousValue.hashCode ^
        newValue.hashCode;
  }
}

class MoveHistory {
  final List<GameMove> _undoStack = [];
  final List<GameMove> _redoStack = [];

  // Maximum number of moves to keep in history (prevent memory issues)
  static const int maxHistorySize = 100;

  /// Add a new move to the history
  /// Clears the redo stack when a new move is added
  void addMove(GameMove move) {
    _undoStack.add(move);

    // Clear redo stack when new move is made
    _redoStack.clear();

    // Limit history size
    if (_undoStack.length > maxHistorySize) {
      _undoStack.removeAt(0);
    }
  }

  /// Undo the last move
  /// Returns the move that was undone, or null if nothing to undo
  GameMove? undo() {
    if (_undoStack.isEmpty) return null;

    final move = _undoStack.removeLast();
    _redoStack.add(move);

    return move;
  }

  /// Redo the last undone move
  /// Returns the move that was redone, or null if nothing to redo
  GameMove? redo() {
    if (_redoStack.isEmpty) return null;

    final move = _redoStack.removeLast();
    _undoStack.add(move);

    return move;
  }

  /// Clear all history
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }

  /// Check if undo is available
  bool get canUndo => _undoStack.isNotEmpty;

  /// Check if redo is available
  bool get canRedo => _redoStack.isNotEmpty;

  /// Get the number of moves in the undo stack
  int get moveCount => _undoStack.length;

  /// Get a copy of the undo stack (for stats/debugging)
  List<GameMove> get undoStack => List.unmodifiable(_undoStack);

  /// Get a copy of the redo stack (for stats/debugging)
  List<GameMove> get redoStack => List.unmodifiable(_redoStack);

  /// Serialization for saving
  Map<String, dynamic> toJson() {
    return {
      'undoStack': _undoStack.map((move) => move.toJson()).toList(),
      'redoStack': _redoStack.map((move) => move.toJson()).toList(),
    };
  }

  /// Deserialization for loading
  factory MoveHistory.fromJson(Map<String, dynamic> json) {
    final history = MoveHistory();

    if (json['undoStack'] != null) {
      final undoList = json['undoStack'] as List<dynamic>;
      for (var moveJson in undoList) {
        history._undoStack.add(GameMove.fromJson(moveJson as Map<String, dynamic>));
      }
    }

    if (json['redoStack'] != null) {
      final redoList = json['redoStack'] as List<dynamic>;
      for (var moveJson in redoList) {
        history._redoStack.add(GameMove.fromJson(moveJson as Map<String, dynamic>));
      }
    }

    return history;
  }

  @override
  String toString() {
    return 'MoveHistory(undoStack: ${_undoStack.length}, redoStack: ${_redoStack.length})';
  }
}
