import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_data.dart';
import 'game.dart';

/// Persists all app data as a single JSON blob. Callers save after every
/// mutation, so whatever is on screen survives an app restart.
class GameStore {
  static const _key = 'skore.data';

  /// Pre-history format: just the current game. Migrated on load, removed
  /// on the next save.
  static const _legacyKey = 'skore.game';

  static Future<AppData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        return AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // A blob we cannot parse is unrecoverable — start fresh instead of
        // crashing on every launch.
        return AppData();
      }
    }
    final legacy = prefs.getString(_legacyKey);
    if (legacy != null) {
      try {
        return AppData(
          current: Game.fromJson(jsonDecode(legacy) as Map<String, dynamic>),
        );
      } catch (_) {
        return AppData();
      }
    }
    return AppData();
  }

  static Future<void> save(AppData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toJson()));
    await prefs.remove(_legacyKey);
  }

  /// Removes every stored game — history and any game in progress.
  static Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_legacyKey);
  }
}
