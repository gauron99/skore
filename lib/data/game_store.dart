import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_data.dart';
import 'game.dart';

/// Result of [GameStore.load]. [blocked] means the blob is still on disk
/// and must not be overwritten with an empty app.
class GameLoad {
  const GameLoad.ready(AppData this.data) : blocked = false;

  const GameLoad.blocked() : data = null, blocked = true;

  final AppData? data;
  final bool blocked;
}

/// Persists all app data as a single JSON blob. Callers save after every
/// mutation, so whatever is on screen survives an app restart.
class GameStore {
  static const _key = 'skore.data';

  /// Pre-history format: just the current game. Migrated on load, removed
  /// on the next save.
  static const _legacyKey = 'skore.game';

  static Future<GameLoad> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      return _readBlob(raw);
    }
    final legacy = prefs.getString(_legacyKey);
    if (legacy != null) {
      try {
        final decoded = jsonDecode(legacy);
        if (decoded is! Map) return const GameLoad.blocked();
        return GameLoad.ready(
          AppData(current: Game.fromJson(Map<String, dynamic>.from(decoded))),
        );
      } catch (_) {
        return const GameLoad.blocked();
      }
    }
    return GameLoad.ready(AppData());
  }

  /// A current game we cannot show blocks the load. The raw string stays
  /// on disk until the user deletes it. Broken history entries are skipped
  /// inside [AppData.fromJson] and do not block.
  static GameLoad _readBlob(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const GameLoad.blocked();
      return GameLoad.ready(
        AppData.fromJson(Map<String, dynamic>.from(decoded)),
      );
    } catch (_) {
      return const GameLoad.blocked();
    }
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
