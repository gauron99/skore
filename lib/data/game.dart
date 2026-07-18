/// Core game model: players, per-round scores, and end-of-game rules.
///
/// Totals, leaders, and standings are always computed from [rounds] — nothing
/// derived is stored, so undoing a round can never leave stale state behind.
class Game {
  Game({
    required this.players,
    List<List<int>>? rounds,
    this.targetRounds,
    this.endedManually = false,
  }) : rounds = rounds ?? [];

  /// Player names in seating order. Fixed for the lifetime of a game.
  final List<String> players;

  /// One entry per played round; each entry holds one score per player.
  final List<List<int>> rounds;

  /// Total number of rounds for a fixed-length game, null for open-ended.
  final int? targetRounds;

  /// Set when an open-ended game is ended with the "End game" action.
  bool endedManually;

  bool get isOver =>
      endedManually || (targetRounds != null && rounds.length >= targetRounds!);

  /// Cumulative score per player across all played rounds.
  List<int> get totals {
    final sums = List<int>.filled(players.length, 0);
    for (final round in rounds) {
      for (var i = 0; i < players.length; i++) {
        sums[i] += round[i];
      }
    }
    return sums;
  }

  /// Indices of the player(s) with the highest total — several when tied.
  /// Empty before the first round so nobody wears the crown at 0:0.
  List<int> get leaders {
    if (rounds.isEmpty) return const [];
    final sums = totals;
    final best = sums.reduce((a, b) => a > b ? a : b);
    return [
      for (var i = 0; i < sums.length; i++)
        if (sums[i] == best) i,
    ];
  }

  /// Player indices ordered by total, highest first (ties keep seating order).
  List<int> get standings {
    final sums = totals;
    final order = List<int>.generate(players.length, (i) => i);
    order.sort((a, b) {
      final byTotal = sums[b].compareTo(sums[a]);
      return byTotal != 0 ? byTotal : a.compareTo(b);
    });
    return order;
  }

  void addRound(List<int> scores) {
    if (isOver) {
      throw StateError('cannot add a round to a finished game');
    }
    if (scores.length != players.length) {
      throw ArgumentError(
          'expected ${players.length} scores, got ${scores.length}');
    }
    rounds.add(List.of(scores));
  }

  /// Drops the most recent round. Also reopens a manually ended game, so the
  /// final standings can always be walked back.
  void undoLastRound() {
    if (rounds.isNotEmpty) {
      rounds.removeLast();
    }
    endedManually = false;
  }

  Map<String, dynamic> toJson() => {
        'players': players,
        'rounds': rounds,
        'targetRounds': targetRounds,
        'endedManually': endedManually,
      };

  factory Game.fromJson(Map<String, dynamic> json) => Game(
        players: (json['players'] as List).cast<String>(),
        rounds: [
          for (final round in json['rounds'] as List)
            (round as List).cast<int>(),
        ],
        targetRounds: json['targetRounds'] as int?,
        endedManually: json['endedManually'] as bool? ?? false,
      );
}
