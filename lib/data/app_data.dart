import 'game.dart';

/// Everything the app persists: the game being played plus archived games.
class AppData {
  AppData({
    this.current,
    List<Game>? history,
    Map<String, String>? samePerson,
    List<String>? displayNames,
  }) : history = history ?? [],
       samePerson = samePerson ?? {},
       displayNames = displayNames ?? [];

  /// The game on the scoreboard right now (may already be over), or null.
  Game? current;

  /// Archived games, oldest first.
  final List<Game> history;

  /// Spelling to the person that spelling counts as. Absent means itself.
  /// "Davca" → "David" files Davca's wins under David. The games keep the
  /// spelling that was typed.
  final Map<String, String> samePerson;

  /// Summary labels that have no spellings yet. A label that already has
  /// spellings is the value those spellings point at in [samePerson].
  final List<String> displayNames;

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

  /// Drops the game on the table. It is not added to [history].
  void discardCurrent() {
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
    'samePerson': samePerson,
    'displayNames': displayNames,
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
    return AppData(
      current: current,
      history: history,
      samePerson: _samePerson(json['samePerson']),
      displayNames: _displayNames(json['displayNames']),
    );
  }
}

/// Optional spelling map. A bad entry is skipped. An old save has none.
Map<String, String> _samePerson(Object? raw) {
  if (raw is! Map) return {};
  final out = <String, String>{};
  raw.forEach((key, value) {
    if (key is! String || value is! String) return;
    final from = key.trim();
    final to = value.trim();
    if (from.isEmpty || to.isEmpty || from == to) return;
    out[from] = to;
  });
  return out;
}

/// Labels with no spellings yet. A bad entry is skipped. An old save has none.
List<String> _displayNames(Object? raw) {
  if (raw is! List) return [];
  final out = <String>[];
  final seen = <String>{};
  for (final entry in raw) {
    if (entry is! String) continue;
    final name = entry.trim();
    if (name.isEmpty || !seen.add(name)) continue;
    out.add(name);
  }
  return out;
}
