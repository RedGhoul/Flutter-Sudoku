import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_state.dart';
import '../models/statistics.dart';

/// Centralized storage manager for all persistent data
/// Wraps SharedPreferences and handles serialization/deserialization
class StorageManager {
  static const String _keyGameState = 'saved_game_state';
  static const String _keyStatistics = 'game_statistics';
  static const String _keySettings = 'app_settings';

  // Setting keys (for backward compatibility with existing code)
  static const String keyDifficulty = 'currentDifficultyLevel';
  static const String keyTheme = 'currentTheme';
  static const String keyAccentColor = 'currentAccentColor';

  final SharedPreferences _prefs;

  StorageManager(this._prefs);

  /// Factory method to create StorageManager instance
  static Future<StorageManager> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageManager(prefs);
  }

  // ===== GAME STATE =====

  /// Save current game state
  Future<bool> saveGameState(GameState state) async {
    try {
      final json = jsonEncode(state.toJson());
      return await _prefs.setString(_keyGameState, json);
    } catch (e) {
      _logError('Error saving game state', e);
      return false;
    }
  }

  /// Load saved game state
  /// Returns null if no saved game exists or if loading fails
  GameState? loadGameState() {
    try {
      final json = _prefs.getString(_keyGameState);
      if (json == null) return null;

      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return GameState.fromJson(decoded);
    } catch (e) {
      _logError('Error loading game state', e);
      return null;
    }
  }

  /// Clear saved game state
  Future<bool> clearGameState() async {
    try {
      return await _prefs.remove(_keyGameState);
    } catch (e) {
      _logError('Error clearing game state', e);
      return false;
    }
  }

  /// Check if a saved game exists
  bool hasSavedGame() {
    return _prefs.containsKey(_keyGameState);
  }

  // ===== STATISTICS =====

  /// Save game statistics
  Future<bool> saveStatistics(GameStatistics stats) async {
    try {
      final json = jsonEncode(stats.toJson());
      return await _prefs.setString(_keyStatistics, json);
    } catch (e) {
      _logError('Error saving statistics', e);
      return false;
    }
  }

  /// Load game statistics
  /// Returns empty statistics if loading fails
  GameStatistics loadStatistics() {
    try {
      final json = _prefs.getString(_keyStatistics);
      if (json == null) return GameStatistics();

      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return GameStatistics.fromJson(decoded);
    } catch (e) {
      _logError('Error loading statistics', e);
      return GameStatistics();
    }
  }

  /// Clear all statistics
  Future<bool> clearStatistics() async {
    try {
      return await _prefs.remove(_keyStatistics);
    } catch (e) {
      _logError('Error clearing statistics', e);
      return false;
    }
  }

  // ===== SETTINGS =====

  /// Save a setting value
  Future<bool> saveSetting(String key, dynamic value) async {
    try {
      if (value is String) {
        return await _prefs.setString(key, value);
      } else if (value is bool) {
        return await _prefs.setBool(key, value);
      } else if (value is int) {
        return await _prefs.setInt(key, value);
      } else if (value is double) {
        return await _prefs.setDouble(key, value);
      } else {
        _logError('Unsupported value type', value.runtimeType);
        return false;
      }
    } catch (e) {
      _logError('Error saving setting: $key', e);
      return false;
    }
  }

  /// Get a setting value with default fallback
  T? getSetting<T>(String key, {T? defaultValue}) {
    try {
      if (!_prefs.containsKey(key)) return defaultValue;

      if (T == String) {
        return (_prefs.getString(key) ?? defaultValue) as T?;
      } else if (T == bool) {
        return (_prefs.getBool(key) ?? defaultValue) as T?;
      } else if (T == int) {
        return (_prefs.getInt(key) ?? defaultValue) as T?;
      } else if (T == double) {
        return (_prefs.getDouble(key) ?? defaultValue) as T?;
      }

      return defaultValue;
    } catch (e) {
      _logError('Error getting setting: $key', e);
      return defaultValue;
    }
  }

  /// Remove a setting
  Future<bool> removeSetting(String key) async {
    try {
      return await _prefs.remove(key);
    } catch (e) {
      _logError('Error removing setting: $key', e);
      return false;
    }
  }

  /// Check if a setting exists
  bool hasSetting(String key) {
    return _prefs.containsKey(key);
  }

  // ===== GAME SETTINGS (Backward Compatibility) =====

  /// Get current difficulty level
  String getDifficulty() {
    return getSetting<String>(keyDifficulty, defaultValue: 'easy') ?? 'easy';
  }

  /// Set current difficulty level
  Future<bool> setDifficulty(String difficulty) async {
    return await saveSetting(keyDifficulty, difficulty);
  }

  /// Get current theme
  String getTheme() {
    return getSetting<String>(keyTheme, defaultValue: 'dark') ?? 'dark';
  }

  /// Set current theme
  Future<bool> setTheme(String theme) async {
    return await saveSetting(keyTheme, theme);
  }

  /// Get current accent color
  String getAccentColor() {
    return getSetting<String>(keyAccentColor, defaultValue: 'Blue') ?? 'Blue';
  }

  /// Set current accent color
  Future<bool> setAccentColor(String color) async {
    return await saveSetting(keyAccentColor, color);
  }

  // ===== BULK OPERATIONS =====

  /// Clear all app data
  Future<bool> clearAll() async {
    try {
      return await _prefs.clear();
    } catch (e) {
      _logError('Error clearing all data', e);
      return false;
    }
  }

  /// Get all keys
  Set<String> getAllKeys() {
    return _prefs.getKeys();
  }

  /// Export all data as JSON (for backup/debugging)
  Map<String, dynamic> exportData() {
    final data = <String, dynamic>{};

    for (var key in _prefs.getKeys()) {
      final value = _prefs.get(key);
      if (value != null) {
        data[key] = value;
      }
    }

    return data;
  }

  // ===== HELPER METHODS =====

  /// Log errors (can be replaced with proper logging in production)
  void _logError(String message, dynamic error) {
    // In production, you might want to use a logging package
    // For now, just print to console
    // ignore: avoid_print
    print('StorageManager Error: $message - $error');
  }

  /// Get underlying SharedPreferences instance (use sparingly)
  SharedPreferences get prefs => _prefs;

  @override
  String toString() {
    return 'StorageManager(keys: ${_prefs.getKeys().length})';
  }
}
