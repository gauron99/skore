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

  factory AppData.fromJson(Map<String, dynamic> json) => AppData(
    current: json['current'] == null
        ? null
        : Game.fromJson(json['current'] as Map<String, dynamic>),
    history: [
      for (final game in (json['history'] as List?) ?? const [])
        Game.fromJson(game as Map<String, dynamic>),
    ],
  );
}
