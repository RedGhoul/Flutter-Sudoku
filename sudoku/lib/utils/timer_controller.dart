import 'dart:async';
import 'package:flutter/foundation.dart';

/// Controller for game timer with pause/resume functionality
/// Uses ChangeNotifier to efficiently update UI when time changes
class TimerController extends ChangeNotifier {
  Duration _elapsedTime = Duration.zero;
  DateTime? _startTime;
  Timer? _timer;
  bool _isPaused = false;

  /// Get current elapsed time
  Duration get elapsedTime => _elapsedTime;

  /// Check if timer is paused
  bool get isPaused => _isPaused;

  /// Check if timer is running
  bool get isRunning => _timer != null && !_isPaused;

  /// Get elapsed time in seconds
  int get elapsedSeconds => _elapsedTime.inSeconds;

  /// Get elapsed time in minutes
  int get elapsedMinutes => _elapsedTime.inMinutes;

  /// Get elapsed time in hours
  int get elapsedHours => _elapsedTime.inHours;

  /// Start or resume timer
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

  /// Pause timer
  void pause() {
    if (_timer == null || _isPaused) return;

    _isPaused = true;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  /// Toggle between pause and resume
  void togglePause() {
    if (isPaused || _timer == null) {
      start();
    } else {
      pause();
    }
  }

  /// Stop and reset timer
  void reset() {
    _timer?.cancel();
    _timer = null;
    _elapsedTime = Duration.zero;
    _startTime = null;
    _isPaused = false;
    notifyListeners();
  }

  /// Set time (for loading saved games)
  void setTime(Duration duration) {
    final wasRunning = isRunning;

    // Stop current timer if running
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }

    _elapsedTime = duration;

    // Restart if it was running
    if (wasRunning) {
      start();
    } else {
      notifyListeners();
    }
  }

  /// Add time to current elapsed time
  void addTime(Duration duration) {
    _elapsedTime += duration;
    if (_startTime != null) {
      _startTime = _startTime!.subtract(duration);
    }
    notifyListeners();
  }

  /// Format time as string (HH:MM:SS or MM:SS)
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

  /// Format time as compact string (e.g., "5m 23s" or "1h 5m")
  String formatTimeCompact() {
    int hours = _elapsedTime.inHours;
    int minutes = _elapsedTime.inMinutes.remainder(60);
    int seconds = _elapsedTime.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Format time as detailed string (e.g., "1 hour 5 minutes 23 seconds")
  String formatTimeDetailed() {
    int hours = _elapsedTime.inHours;
    int minutes = _elapsedTime.inMinutes.remainder(60);
    int seconds = _elapsedTime.inSeconds.remainder(60);

    List<String> parts = [];

    if (hours > 0) {
      parts.add('$hours ${hours == 1 ? 'hour' : 'hours'}');
    }
    if (minutes > 0) {
      parts.add('$minutes ${minutes == 1 ? 'minute' : 'minutes'}');
    }
    if (seconds > 0 || parts.isEmpty) {
      parts.add('$seconds ${seconds == 1 ? 'second' : 'seconds'}');
    }

    return parts.join(' ');
  }

  /// Create a snapshot of current state (for debugging)
  Map<String, dynamic> toSnapshot() {
    return {
      'elapsedTime': _elapsedTime.inSeconds,
      'isPaused': _isPaused,
      'isRunning': isRunning,
      'formattedTime': formatTime(),
    };
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  String toString() {
    return 'TimerController(elapsed: ${formatTime()}, paused: $_isPaused, running: $isRunning)';
  }
}
