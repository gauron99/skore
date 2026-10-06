import 'game.dart';

/// Everything the app persists: the game being played plus finished games.
class AppData {
  AppData({this.current, List<Game>? history}) : history = history ?? [];

  /// The game on the scoreboard right now (may already be over), or null.
  Game? current;

  /// Archived games, oldest first.
  final List<Game> history;

  /// Moves the current game into [history]. A game abandoned before its end
  /// is archived as manually ended, so the list always shows a winner.
  void archiveCurrent() {
    final game = current;
    if (game == null) return;
    if (!game.isOver) {
      game.endedManually = true;
    }
    history.add(game);
    current = null;
  }

  /// Archives the current game and starts another with the same players and
  /// rules. No-op if there is no current game.
  void rematchCurrent() {
    final game = current;
    if (game == null) return;
    final next = game.rematch();
    archiveCurrent();
    current = next;
  }

  Map<String, dynamic> toJson() => {
    'current': current?.toJson(),
    'history': [for (final game in history) game.toJson()],
  };

  factory AppData.fromJson(Map<String, dynamic> json) {
    final currentRaw = json['current'];
    final Game? current;
    if (currentRaw == null) {
      current = null;
    } else if (currentRaw is Map) {
      current = Game.fromJson(Map<String, dynamic>.from(currentRaw));
    } else {
      throw const FormatException('current');
    }
    final history = <Game>[];
    final historyRaw = json['history'];
    if (historyRaw is List) {
      for (final entry in historyRaw) {
        if (entry is! Map) continue;
        try {
          history.add(Game.fromJson(Map<String, dynamic>.from(entry)));
        } catch (_) {
          // One broken past game must not hide the game on the table.
        }
      }
    }
    return AppData(current: current, history: history);
  }
}
