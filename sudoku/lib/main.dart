import 'dart:async';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animated_dialog/flutter_animated_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_solver_generator/sudoku_solver_generator.dart';

import 'alerts/all.dart';
import 'board_style.dart';
import 'models/move_history.dart';
import 'models/pencil_marks.dart';
import 'models/statistics.dart';
import 'splash_screen_page.dart';
import 'styles.dart';
import 'utils/storage_manager.dart';
import 'utils/timer_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  // SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  static const String versionNumber = '2.4.1';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Styles.primaryColor,
      ),
      home: const SplashScreenPage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool firstRun = true;
  bool gameOver = false;
  int timesCalled = 0;
  bool isButtonDisabled = false;
  bool isFABDisabled = false;
  late List<List<List<int>>> gameList;
  late List<List<int>> game;
  late List<List<int>> gameCopy;
  late List<List<int>> gameSolved;
  static String? currentDifficultyLevel;
  static String? currentTheme;
  static String? currentAccentColor;

  // Undo/Redo support
  late MoveHistory moveHistory;
  late PencilMarks pencilMarks;

  // Timer and Statistics
  late TimerController timerController;
  late GameStatistics statistics;
  late StorageManager storageManager;

  // Pencil Marks Mode
  bool isPencilMode = false;

  // Number Highlighting
  int? selectedRow;
  int? selectedCol;
  int? selectedNumber;

  // Auto-save
  Timer? _autoSaveTimer;

  static String platform = () {
    if (kIsWeb) {
      return 'web-${defaultTargetPlatform.toString().replaceFirst("TargetPlatform.", "").toLowerCase()}';
    } else {
      return defaultTargetPlatform
          .toString()
          .replaceFirst("TargetPlatform.", "")
          .toLowerCase();
    }
  }();
  static bool isDesktop = ['windows', 'linux', 'macos'].contains(platform);

  @override
  void initState() {
    super.initState();

    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Initialize undo/redo support
    moveHistory = MoveHistory();
    pencilMarks = PencilMarks();

    // Initialize timer
    timerController = TimerController();

    // Initialize storage and load statistics
    StorageManager.create().then((manager) {
      storageManager = manager;
      statistics = manager.loadStatistics();

      // Set up auto-save timer (every 30 seconds)
      _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _saveGameState();
      });

      // Try to load saved game
      _loadSavedGame();

      setState(() {});
    });

    try {
      doWhenWindowReady(() {
        appWindow.alignment = Alignment.center;
        appWindow.minSize = const Size(625, 625);
      });
      // ignore: empty_catches
    } on UnimplementedError {}
    getPrefs().whenComplete(() {
      if (currentDifficultyLevel == null) {
        currentDifficultyLevel = 'easy';
        setPrefs('currentDifficultyLevel');
      }
      if (currentTheme == null) {
        if (MediaQuery.maybeOf(context)?.platformBrightness != null) {
          currentTheme =
              MediaQuery.of(context).platformBrightness == Brightness.light
                  ? 'light'
                  : 'dark';
        } else {
          currentTheme = 'dark';
        }
        setPrefs('currentTheme');
      }
      if (currentAccentColor == null) {
        currentAccentColor = 'Blue';
        setPrefs('currentAccentColor');
      }
      // Only start new game if no saved game was loaded
      if (firstRun) {
        newGame(currentDifficultyLevel!);
      }
      changeTheme('set');
      changeAccentColor(currentAccentColor!, true);
    });
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
      if (!gameOver && !timerController.isPaused) {
        timerController.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      // Resume timer if game was active
      if (!gameOver && timerController.isPaused && !isButtonDisabled) {
        timerController.start();
      }
    }
  }

  Future<void> _saveGameState() async {
    if (gameOver || firstRun) return; // Don't save completed/unstarted games

    try {
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
        moveCount: moveHistory.moveCount,
      );

      await storageManager.saveGameState(state);
    } catch (e) {
      // Fail silently - don't disrupt gameplay
    }
  }

  Future<void> _loadSavedGame() async {
    try {
      final savedState = storageManager.loadGameState();

      if (savedState != null && !savedState.isCompleted) {
        // Show resume dialog
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;

          showAnimatedDialog<bool>(
            animationType: DialogTransitionType.fadeScale,
            barrierDismissible: false,
            duration: const Duration(milliseconds: 350),
            context: context,
            builder: (_) => AlertResumeGame(savedState: savedState),
          ).then((shouldResume) {
            if (shouldResume == true) {
              _resumeGame(savedState);
            } else {
              storageManager.clearGameState();
            }
          });
        });
      }
    } catch (e) {
      // Fail silently - corrupted save data
      storageManager.clearGameState();
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
      } else {
        isButtonDisabled = true;
      }

      gameOver = false;
      firstRun = false;
    });
  }

  Future<void> getPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentDifficultyLevel = prefs.getString('currentDifficultyLevel');
      currentTheme = prefs.getString('currentTheme');
      currentAccentColor = prefs.getString('currentAccentColor');
    });
  }

  setPrefs(String property) async {
    final prefs = await SharedPreferences.getInstance();
    if (property == 'currentDifficultyLevel') {
      prefs.setString('currentDifficultyLevel', currentDifficultyLevel!);
    } else if (property == 'currentTheme') {
      prefs.setString('currentTheme', currentTheme!);
    } else if (property == 'currentAccentColor') {
      prefs.setString('currentAccentColor', currentAccentColor!);
    }
  }

  void changeTheme(String mode) {
    setState(() {
      if (currentTheme == 'light') {
        if (mode == 'switch') {
          Styles.primaryBackgroundColor = Styles.darkGrey;
          Styles.secondaryBackgroundColor = Styles.grey;
          Styles.foregroundColor = Styles.white;
          currentTheme = 'dark';
        } else if (mode == 'set') {
          Styles.primaryBackgroundColor = Styles.white;
          Styles.secondaryBackgroundColor = Styles.white;
          Styles.foregroundColor = Styles.darkGrey;
        }
      } else if (currentTheme == 'dark') {
        if (mode == 'switch') {
          Styles.primaryBackgroundColor = Styles.white;
          Styles.secondaryBackgroundColor = Styles.white;
          Styles.foregroundColor = Styles.darkGrey;
          currentTheme = 'light';
        } else if (mode == 'set') {
          Styles.primaryBackgroundColor = Styles.darkGrey;
          Styles.secondaryBackgroundColor = Styles.grey;
          Styles.foregroundColor = Styles.white;
        }
      }
      setPrefs('currentTheme');
    });
  }

  void changeAccentColor(String color, [bool firstRun = false]) {
    setState(() {
      if (Styles.accentColors.keys.contains(color)) {
        Styles.primaryColor = Styles.accentColors[color]!;
      } else {
        currentAccentColor = 'Blue';
        Styles.primaryColor = Styles.accentColors[color]!;
      }
      if (color == 'Red') {
        Styles.secondaryColor = Styles.orange;
      } else {
        Styles.secondaryColor = Styles.lightRed;
      }
      if (!firstRun) {
        setPrefs('currentAccentColor');
      }
    });
  }

  void checkResult() {
    try {
      if (SudokuUtilities.isSolved(game)) {
        isButtonDisabled = !isButtonDisabled;
        gameOver = true;

        // Stop timer and record statistics
        timerController.pause();
        final timeTaken = timerController.elapsedTime;
        final moveCount = moveHistory.moveCount;

        // Record game statistics
        statistics.recordGame(
          difficulty: currentDifficultyLevel!,
          completed: true,
          timeTaken: timeTaken,
          moveCount: moveCount,
        );
        storageManager.saveStatistics(statistics);
        storageManager.clearGameState(); // Clear saved game on completion

        Timer(const Duration(milliseconds: 500), () {
          showAnimatedDialog<void>(
              animationType: DialogTransitionType.fadeScale,
              barrierDismissible: true,
              duration: const Duration(milliseconds: 350),
              context: context,
              builder: (_) => AlertGameOver(
                    timeTaken: timerController.formatTime(),
                    moveCount: moveCount,
                  )).whenComplete(() {
            if (AlertGameOver.newGame) {
              newGame();
              AlertGameOver.newGame = false;
            } else if (AlertGameOver.restartGame) {
              restartGame();
              AlertGameOver.restartGame = false;
            }
          });
        });
      }
    } on InvalidSudokuConfigurationException {
      return;
    }
  }

  static Future<List<List<List<int>>>> getNewGame(
      [String difficulty = 'easy']) async {
    int emptySquares;
    switch (difficulty) {
      case 'test':
        {
          emptySquares = 2;
        }
        break;
      case 'beginner':
        {
          emptySquares = 18;
        }
        break;
      case 'easy':
        {
          emptySquares = 27;
        }
        break;
      case 'medium':
        {
          emptySquares = 36;
        }
        break;
      case 'hard':
        {
          emptySquares = 54;
        }
        break;
      default:
        {
          emptySquares = 2;
        }
        break;
    }
    SudokuGenerator generator = SudokuGenerator(emptySquares: emptySquares);
    return [generator.newSudoku, generator.newSudokuSolved];
  }

  static List<List<int>> copyGrid(List<List<int>> grid) {
    return grid.map((row) => [...row]).toList();
  }

  void setGame(int mode, [String difficulty = 'easy']) async {
    if (mode == 1) {
      game = List.filled(9, [0, 0, 0, 0, 0, 0, 0, 0, 0]);
      gameCopy = List.filled(9, [0, 0, 0, 0, 0, 0, 0, 0, 0]);
      gameSolved = List.filled(9, [0, 0, 0, 0, 0, 0, 0, 0, 0]);
    } else {
      gameList = await getNewGame(difficulty);
      game = gameList[0];
      gameCopy = copyGrid(game);
      gameSolved = gameList[1];
    }
  }

  void showSolution() {
    setState(() {
      game = copyGrid(gameSolved);
      isButtonDisabled =
          !isButtonDisabled ? !isButtonDisabled : isButtonDisabled;
      gameOver = true;
    });
  }

  void newGame([String difficulty = 'easy']) {
    setState(() {
      isFABDisabled = !isFABDisabled;
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() {
        setGame(2, difficulty);
        moveHistory.clear(); // Clear undo/redo history
        pencilMarks.clearAll(); // Clear all pencil marks
        timerController.reset(); // Reset timer
        timerController.start(); // Start timer
        storageManager.clearGameState(); // Clear any saved game
        isButtonDisabled =
            isButtonDisabled ? !isButtonDisabled : isButtonDisabled;
        gameOver = false;
        isFABDisabled = !isFABDisabled;
      });
    });
  }

  void restartGame() {
    setState(() {
      game = copyGrid(gameCopy);
      moveHistory.clear(); // Clear undo/redo history
      pencilMarks.clearAll(); // Clear all pencil marks
      timerController.reset(); // Reset timer
      timerController.start(); // Start timer
      isButtonDisabled =
          isButtonDisabled ? !isButtonDisabled : isButtonDisabled;
      gameOver = false;
    });
  }

  Widget buildCellContent(int row, int col) {
    final value = game[row][col];
    final marks = pencilMarks.getMarks(row, col);

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
            final hasMark = marks.contains(number);

            return Center(
              child: Text(
                hasMark ? number.toString() : '',
                style: TextStyle(
                  fontSize: buttonSize() / 8,
                  color: Styles.foregroundColor.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
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

  List<SizedBox> createButtons() {
    if (firstRun) {
      setGame(1);
      firstRun = false;
    }

    List<SizedBox> buttonList = List<SizedBox>.filled(9, const SizedBox());
    for (var i = 0; i <= 8; i++) {
      var k = timesCalled;
      buttonList[i] = SizedBox(
        key: Key('grid-button-$k-$i'),
        width: buttonSize(),
        height: buttonSize(),
        child: TextButton(
          onPressed: isButtonDisabled || gameCopy[k][i] != 0
              ? null
              : () {
                  // Set selected cell for highlighting
                  setState(() {
                    selectedRow = k;
                    selectedCol = i;
                    selectedNumber = game[k][i];
                  });

                  showAnimatedDialog<void>(
                          animationType: DialogTransitionType.fade,
                          barrierDismissible: true,
                          duration: const Duration(milliseconds: 300),
                          context: context,
                          builder: (_) => AlertNumbersState(
                                isPencilMode: isPencilMode,
                                currentMarks: pencilMarks.getMarks(k, i),
                              ))
                      .whenComplete(() {
                    // Clear selection after dialog closes
                    setState(() {
                      selectedRow = null;
                      selectedCol = null;
                      selectedNumber = null;
                    });

                    if (isPencilMode) {
                      // Handle pencil marks
                      if (AlertNumbersState.pencilMarks != null) {
                        setState(() {
                          final previousNotes =
                              pencilMarks.getMarks(k, i).toList();
                          final newNotes =
                              AlertNumbersState.pencilMarks!.toList();

                          // Record pencil mark change in history
                          moveHistory.addMove(GameMove(
                            row: k,
                            col: i,
                            previousValue: game[k][i] == 0 ? null : game[k][i],
                            newValue: game[k][i] == 0 ? null : game[k][i],
                            previousNotes: previousNotes,
                            newNotes: newNotes,
                          ));

                          // Apply pencil marks
                          pencilMarks.setMarks(
                              k, i, AlertNumbersState.pencilMarks!);
                        });
                        AlertNumbersState.pencilMarks = null;
                      }
                    } else {
                      // Handle normal number placement
                      callback([k, i], AlertNumbersState.number);
                      AlertNumbersState.number = null;
                    }
                  });
                },
          onLongPress: isButtonDisabled || gameCopy[k][i] != 0
              ? null
              : () => callback([k, i], 0),
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all<Color>(buttonColor(
              k,
              i,
              selectedRow: selectedRow,
              selectedCol: selectedCol,
              selectedNumber: selectedNumber,
              currentValue: game[k][i],
            )),
            foregroundColor: MaterialStateProperty.resolveWith<Color>(
                (Set<MaterialState> states) {
              if (states.contains(MaterialState.disabled)) {
                return gameCopy[k][i] == 0
                    ? emptyColor(gameOver)
                    : Styles.foregroundColor;
              }
              return game[k][i] == 0
                  ? buttonColor(
                      k,
                      i,
                      selectedRow: selectedRow,
                      selectedCol: selectedCol,
                      selectedNumber: selectedNumber,
                      currentValue: game[k][i],
                    )
                  : Styles.secondaryColor;
            }),
            shape: MaterialStateProperty.all<OutlinedBorder>(
                RoundedRectangleBorder(
              borderRadius: buttonEdgeRadius(k, i),
            )),
            side: MaterialStateProperty.all<BorderSide>(BorderSide(
              color: Styles.foregroundColor,
              width: 1,
              style: BorderStyle.solid,
            )),
          ),
          child: buildCellContent(k, i),
        ),
      );
    }
    timesCalled++;
    if (timesCalled == 9) {
      timesCalled = 0;
    }
    return buttonList;
  }

  Row oneRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: createButtons(),
    );
  }

  List<Row> createRows() {
    List<Row> rowList = List<Row>.generate(9, (i) => oneRow());
    return rowList;
  }

  void callback(List<int> index, int? number) {
    setState(() {
      if (number == null) {
        return;
      }

      final row = index[0];
      final col = index[1];
      final previousValue = game[row][col] == 0 ? null : game[row][col];
      final newValue = number == 0 ? null : number;

      // Record move in history
      moveHistory.addMove(GameMove(
        row: row,
        col: col,
        previousValue: previousValue,
        newValue: newValue,
        previousNotes: pencilMarks.getMarks(row, col).toList(),
        newNotes: null, // Placing a number clears notes
      ));

      // Apply the move
      game[row][col] = number;

      if (number != 0) {
        // Clear pencil marks when placing a number
        pencilMarks.clearMarks(row, col);
        pencilMarks.clearRelatedMarks(row, col, number);
        checkResult();
      }
    });
  }

  void undoMove() {
    final move = moveHistory.undo();
    if (move == null) return;

    setState(() {
      // Restore previous value
      game[move.row][move.col] = move.previousValue ?? 0;

      // Restore pencil marks
      if (move.previousNotes != null) {
        pencilMarks.setMarks(move.row, move.col, move.previousNotes!.toSet());
      }
    });
  }

  void redoMove() {
    final move = moveHistory.redo();
    if (move == null) return;

    setState(() {
      // Apply new value
      game[move.row][move.col] = move.newValue ?? 0;

      // Restore pencil marks or clear them
      if (move.newNotes != null) {
        pencilMarks.setMarks(move.row, move.col, move.newNotes!.toSet());
      } else if (move.newValue != null && move.newValue != 0) {
        pencilMarks.clearMarks(move.row, move.col);
        pencilMarks.clearRelatedMarks(move.row, move.col, move.newValue!);
      }
    });
  }

  showOptionModalSheet(BuildContext context) {
    BuildContext outerContext = context;
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Styles.secondaryBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(10),
          ),
        ),
        builder: (context) {
          final TextStyle customStyle =
              TextStyle(inherit: false, color: Styles.foregroundColor);
          return Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.refresh, color: Styles.foregroundColor),
                title: Text('Restart Game', style: customStyle),
                onTap: () {
                  Navigator.pop(context);
                  Timer(const Duration(milliseconds: 200), () => restartGame());
                },
              ),
              ListTile(
                leading: Icon(Icons.add_rounded, color: Styles.foregroundColor),
                title: Text('New Game', style: customStyle),
                onTap: () {
                  Navigator.pop(context);
                  Timer(const Duration(milliseconds: 200),
                      () => newGame(currentDifficultyLevel!));
                },
              ),
              ListTile(
                leading: Icon(Icons.lightbulb_outline_rounded,
                    color: Styles.foregroundColor),
                title: Text('Show Solution', style: customStyle),
                onTap: () {
                  Navigator.pop(context);
                  Timer(
                      const Duration(milliseconds: 200), () => showSolution());
                },
              ),
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
                          ));
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.build_outlined, color: Styles.foregroundColor),
                title: Text('Set Difficulty', style: customStyle),
                onTap: () {
                  Navigator.pop(context);
                  Timer(
                      const Duration(milliseconds: 300),
                      () => showAnimatedDialog<void>(
                              animationType: DialogTransitionType.fadeScale,
                              barrierDismissible: true,
                              duration: const Duration(milliseconds: 350),
                              context: outerContext,
                              builder: (_) => AlertDifficultyState(
                                  currentDifficultyLevel!)).whenComplete(() {
                            if (AlertDifficultyState.difficulty != null) {
                              Timer(const Duration(milliseconds: 300), () {
                                newGame(
                                    AlertDifficultyState.difficulty ?? 'test');
                                currentDifficultyLevel =
                                    AlertDifficultyState.difficulty;
                                AlertDifficultyState.difficulty = null;
                                setPrefs('currentDifficultyLevel');
                              });
                            }
                          }));
                },
              ),
              ListTile(
                leading: Icon(Icons.invert_colors_on_rounded,
                    color: Styles.foregroundColor),
                title: Text('Switch Theme', style: customStyle),
                onTap: () {
                  Navigator.pop(context);
                  Timer(const Duration(milliseconds: 200), () {
                    changeTheme('switch');
                  });
                },
              ),
              ListTile(
                leading: Icon(Icons.color_lens_outlined,
                    color: Styles.foregroundColor),
                title: Text('Change Accent Color', style: customStyle),
                onTap: () {
                  Navigator.pop(context);
                  Timer(
                      const Duration(milliseconds: 200),
                      () => showAnimatedDialog<void>(
                              animationType: DialogTransitionType.fadeScale,
                              barrierDismissible: true,
                              duration: const Duration(milliseconds: 350),
                              context: outerContext,
                              builder: (_) => AlertAccentColorsState(
                                  currentAccentColor!)).whenComplete(() {
                            if (AlertAccentColorsState.accentColor != null) {
                              Timer(const Duration(milliseconds: 300), () {
                                currentAccentColor =
                                    AlertAccentColorsState.accentColor;
                                changeAccentColor(
                                    currentAccentColor.toString());
                                AlertAccentColorsState.accentColor = null;
                                setPrefs('currentAccentColor');
                              });
                            }
                          }));
                },
              ),
              ListTile(
                leading: Icon(Icons.info_outline_rounded,
                    color: Styles.foregroundColor),
                title: Text('About', style: customStyle),
                onTap: () {
                  Navigator.pop(context);
                  Timer(
                      const Duration(milliseconds: 200),
                      () => showAnimatedDialog<void>(
                          animationType: DialogTransitionType.fadeScale,
                          barrierDismissible: true,
                          duration: const Duration(milliseconds: 350),
                          context: outerContext,
                          builder: (_) => const AlertAbout()));
                },
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          if (kIsWeb) {
            return false;
          } else {
            showAnimatedDialog<void>(
                animationType: DialogTransitionType.fadeScale,
                barrierDismissible: true,
                duration: const Duration(milliseconds: 350),
                context: context,
                builder: (_) => const AlertExit());
          }
          return true;
        },
        child: Scaffold(
            backgroundColor: Styles.primaryBackgroundColor,
            appBar: PreferredSize(
                preferredSize: const Size.fromHeight(56.0),
                child: isDesktop
                    ? MoveWindow(
                        onDoubleTap: () => appWindow.maximizeOrRestore(),
                        child: AppBar(
                          centerTitle: true,
                          title: const Text('Sudoku'),
                          backgroundColor: Styles.primaryColor,
                          actions: [
                            IconButton(
                              icon: const Icon(Icons.minimize_outlined),
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 15),
                              onPressed: () {
                                appWindow.minimize();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
                              onPressed: () {
                                showAnimatedDialog<void>(
                                    animationType:
                                        DialogTransitionType.fadeScale,
                                    barrierDismissible: true,
                                    duration: const Duration(milliseconds: 350),
                                    context: context,
                                    builder: (_) => const AlertExit());
                              },
                            ),
                          ],
                        ),
                      )
                    : AppBar(
                        centerTitle: true,
                        title: const Text('Sudoku'),
                        backgroundColor: Styles.primaryColor,
                      )),
            body: Builder(builder: (builder) {
              return Center(
                child: Column(
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
                              timerController.isPaused
                                  ? Icons.play_arrow
                                  : Icons.pause,
                              color: Styles.foregroundColor,
                            ),
                            tooltip:
                                timerController.isPaused ? 'Resume' : 'Pause',
                            onPressed: gameOver
                                ? null
                                : () {
                                    setState(() {
                                      if (timerController.isPaused) {
                                        timerController.start();
                                        isButtonDisabled = false;
                                      } else {
                                        timerController.pause();
                                        isButtonDisabled = true;
                                      }
                                    });
                                  },
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
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // Sudoku grid
                    ...createRows(),
                  ],
                ),
              );
            }),
            floatingActionButton: Stack(
              alignment: Alignment.bottomRight,
              children: [
                // Pencil mode toggle (highest)
                Positioned(
                  bottom: 200,
                  right: 0,
                  child: FloatingActionButton(
                    mini: true,
                    heroTag: 'pencil',
                    tooltip: isPencilMode ? 'Normal Mode' : 'Pencil Mode',
                    onPressed: isButtonDisabled
                        ? null
                        : () {
                            setState(() {
                              isPencilMode = !isPencilMode;
                            });
                          },
                    backgroundColor: isPencilMode
                        ? Colors.orange
                        : (isButtonDisabled
                            ? Styles.primaryColor[900]
                            : Styles.primaryColor),
                    foregroundColor: isPencilMode
                        ? Colors.black
                        : Styles.primaryBackgroundColor,
                    child: Icon(
                      isPencilMode ? Icons.edit : Icons.edit_outlined,
                      size: 20,
                    ),
                  ),
                ),
                // Redo button
                Positioned(
                  bottom: 140,
                  right: 0,
                  child: FloatingActionButton(
                    mini: true,
                    heroTag: 'redo',
                    tooltip: 'Redo',
                    onPressed: moveHistory.canRedo && !isButtonDisabled
                        ? redoMove
                        : null,
                    backgroundColor: moveHistory.canRedo && !isButtonDisabled
                        ? Styles.primaryColor
                        : Styles.primaryColor[900],
                    foregroundColor: Styles.primaryBackgroundColor,
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
                    tooltip: 'Undo',
                    onPressed: moveHistory.canUndo && !isButtonDisabled
                        ? undoMove
                        : null,
                    backgroundColor: moveHistory.canUndo && !isButtonDisabled
                        ? Styles.primaryColor
                        : Styles.primaryColor[900],
                    foregroundColor: Styles.primaryBackgroundColor,
                    child: const Icon(Icons.undo, size: 20),
                  ),
                ),
                // Menu button (bottom - existing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: FloatingActionButton(
                    heroTag: 'menu',
                    tooltip: 'Menu',
                    foregroundColor: Styles.primaryBackgroundColor,
                    backgroundColor: isFABDisabled
                        ? Styles.primaryColor[900]
                        : Styles.primaryColor,
                    onPressed: isFABDisabled
                        ? null
                        : () => showOptionModalSheet(context),
                    child: const Icon(Icons.menu_rounded),
                  ),
                ),
              ],
            )));
  }
}
