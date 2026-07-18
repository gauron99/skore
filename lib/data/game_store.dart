import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'game.dart';

/// Persists the whole current game as a single JSON blob. Callers save after
/// every mutation, so whatever is on screen survives an app restart.
class GameStore {
  static const _key = 'skore.game';

  static Future<Game?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return Game.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A blob we cannot parse is unrecoverable — start fresh instead of
      // crashing on every launch.
      return null;
    }
  }

  static Future<void> save(Game game) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(game.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
