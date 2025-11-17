class PencilMarks {
  // 9x9 grid of sets (each cell can have multiple candidate numbers)
  late List<List<Set<int>>> _marks;

  PencilMarks() {
    _marks = List.generate(9, (_) => List.generate(9, (_) => <int>{}));
  }

  /// Get marks for a cell
  Set<int> getMarks(int row, int col) {
    _validateCoordinates(row, col);
    return Set.from(_marks[row][col]);
  }

  /// Toggle a mark (add if absent, remove if present)
  void toggleMark(int row, int col, int number) {
    _validateCoordinates(row, col);
    _validateNumber(number);

    if (_marks[row][col].contains(number)) {
      _marks[row][col].remove(number);
    } else {
      _marks[row][col].add(number);
    }
  }

  /// Add a mark to a cell
  void addMark(int row, int col, int number) {
    _validateCoordinates(row, col);
    _validateNumber(number);
    _marks[row][col].add(number);
  }

  /// Remove a mark from a cell
  void removeMark(int row, int col, int number) {
    _validateCoordinates(row, col);
    _validateNumber(number);
    _marks[row][col].remove(number);
  }

  /// Set all marks for a cell
  void setMarks(int row, int col, Set<int> marks) {
    _validateCoordinates(row, col);
    for (var mark in marks) {
      _validateNumber(mark);
    }
    _marks[row][col] = Set.from(marks);
  }

  /// Clear marks for a cell
  void clearMarks(int row, int col) {
    _validateCoordinates(row, col);
    _marks[row][col].clear();
  }

  /// Clear all marks
  void clearAll() {
    for (var row in _marks) {
      for (var cell in row) {
        cell.clear();
      }
    }
  }

  /// Auto-clear marks when number is placed
  /// Clears the given number from all related cells (same row, column, and 3x3 box)
  void clearRelatedMarks(int row, int col, int number) {
    _validateCoordinates(row, col);
    _validateNumber(number);

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

  /// Check if a cell has any marks
  bool hasMarks(int row, int col) {
    _validateCoordinates(row, col);
    return _marks[row][col].isNotEmpty;
  }

  /// Check if a cell has a specific mark
  bool hasMark(int row, int col, int number) {
    _validateCoordinates(row, col);
    _validateNumber(number);
    return _marks[row][col].contains(number);
  }

  /// Get total number of marks across all cells
  int get totalMarks {
    int count = 0;
    for (var row in _marks) {
      for (var cell in row) {
        count += cell.length;
      }
    }
    return count;
  }

  /// Serialization for saving
  Map<String, dynamic> toJson() {
    List<List<List<int>>> marksList = [];

    for (int row = 0; row < 9; row++) {
      List<List<int>> rowList = [];
      for (int col = 0; col < 9; col++) {
        rowList.add(_marks[row][col].toList()..sort());
      }
      marksList.add(rowList);
    }

    return {'marks': marksList};
  }

  /// Deserialization for loading
  factory PencilMarks.fromJson(Map<String, dynamic> json) {
    final pencilMarks = PencilMarks();

    if (json['marks'] != null) {
      final marksList = json['marks'] as List<dynamic>;
      for (int row = 0; row < 9 && row < marksList.length; row++) {
        final rowList = marksList[row] as List<dynamic>;
        for (int col = 0; col < 9 && col < rowList.length; col++) {
          final cellMarks = (rowList[col] as List<dynamic>).cast<int>();
          pencilMarks._marks[row][col] = Set.from(cellMarks);
        }
      }
    }

    return pencilMarks;
  }

  /// Deep copy
  PencilMarks copy() {
    final newMarks = PencilMarks();
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        newMarks._marks[row][col] = Set.from(_marks[row][col]);
      }
    }
    return newMarks;
  }

  /// Validation helpers
  void _validateCoordinates(int row, int col) {
    if (row < 0 || row > 8 || col < 0 || col > 8) {
      throw ArgumentError('Invalid coordinates: row=$row, col=$col. Must be 0-8.');
    }
  }

  void _validateNumber(int number) {
    if (number < 1 || number > 9) {
      throw ArgumentError('Invalid number: $number. Must be 1-9.');
    }
  }

  @override
  String toString() {
    int totalMarks = 0;
    for (var row in _marks) {
      for (var cell in row) {
        totalMarks += cell.length;
      }
    }
    return 'PencilMarks(totalMarks: $totalMarks)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    if (other is! PencilMarks) return false;

    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (_marks[row][col].length != other._marks[row][col].length) {
          return false;
        }
        if (!_marks[row][col].containsAll(other._marks[row][col])) {
          return false;
        }
      }
    }

    return true;
  }

  @override
  int get hashCode => _marks.hashCode;
}
