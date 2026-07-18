/// Core game model: players, per-round scores, and end-of-game rules.
///
/// Totals, leaders, and standings are always computed from [rounds] — nothing
/// derived is stored, so undoing a round can never leave stale state behind.
class Game {
  Game({
    required this.players,
    List<List<int>>? rounds,
    this.targetRounds,
    this.targetScore,
    this.lowestWins = false,
    this.endedManually = false,
    DateTime? startedAt,
  })  : rounds = rounds ?? [],
        startedAt = startedAt ?? DateTime.now();

  /// Player names in seating order. Fixed for the lifetime of a game.
  final List<String> players;

  /// One entry per played round; each entry holds one score per player.
  final List<List<int>> rounds;

  /// Total number of rounds for a fixed-length game, null for open-ended.
  final int? targetRounds;

  /// Ends the game once any player's total reaches this. Purely an
  /// end-of-game trigger — who wins stays with [lowestWins]. Null = no cap.
  final int? targetScore;

  /// When true the fewest points lead and win (Hearts-style scoring).
  final bool lowestWins;

  /// Set when an open-ended game is ended with the "End game" action.
  bool endedManually;

  /// When the game was created; shown in the past-games list.
  final DateTime startedAt;

  bool get isOver =>
      endedManually ||
      (targetRounds != null && rounds.length >= targetRounds!) ||
      (targetScore != null && totals.any((total) => total >= targetScore!));

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

  /// Indices of the player(s) with the best total — several when tied. Best
  /// means highest, or lowest when [lowestWins] is set. Empty before the
  /// first round so nobody wears the crown at 0:0.
  List<int> get leaders {
    if (rounds.isEmpty) return const [];
    final sums = totals;
    final best = sums.reduce(
      (a, b) => (lowestWins ? a < b : a > b) ? a : b,
    );
    return [
      for (var i = 0; i < sums.length; i++)
        if (sums[i] == best) i,
    ];
  }

  /// Player indices ordered by total, best first (ties keep seating order).
  List<int> get standings {
    final sums = totals;
    final order = List<int>.generate(players.length, (i) => i);
    order.sort((a, b) {
      final byTotal = lowestWins
          ? sums[a].compareTo(sums[b])
          : sums[b].compareTo(sums[a]);
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
        'targetScore': targetScore,
        'lowestWins': lowestWins,
        'endedManually': endedManually,
        'startedAt': startedAt.toIso8601String(),
      };

  factory Game.fromJson(Map<String, dynamic> json) => Game(
        players: (json['players'] as List).cast<String>(),
        rounds: [
          for (final round in json['rounds'] as List)
            (round as List).cast<int>(),
        ],
        targetRounds: json['targetRounds'] as int?,
        targetScore: json['targetScore'] as int?,
        // Missing in blobs saved before the option existed -> highest wins.
        lowestWins: json['lowestWins'] as bool? ?? false,
        endedManually: json['endedManually'] as bool? ?? false,
        // Blobs from before the field existed fall back to "now".
        startedAt: json['startedAt'] == null
            ? null
            : DateTime.parse(json['startedAt'] as String),
      );
}
