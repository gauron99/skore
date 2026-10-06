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
    this.countDown = false,
    this.lowestWins = false,
    this.endedManually = false,
    this.whist = false,
    this.whistMaxHand = 8,
    int? whistCycles,
    this.whistFirstDealer = 0,
    this.whistBids,
    List<bool>? whistHits,
    DateTime? startedAt,
  }) : rounds = rounds ?? [],
       whistCycles = whistCycles ?? players.length,
       _whistHits = _hitsOrEmpty(players.length, whistHits),
       startedAt = startedAt ?? DateTime.now();

  static List<bool> _hitsOrEmpty(int n, List<bool>? hits) =>
      hits != null && hits.length == n
      ? List<bool>.from(hits)
      : List<bool>.filled(n, false);

  /// Saves from before [whistFirstDealer] existed, or with a seat that no
  /// longer fits, fall back to the first seat.
  static int _seatOrZero(Object? seat, int n) =>
      seat is int && seat >= 0 && seat < n ? seat : 0;

  /// Player names in seating order. Fixed for the lifetime of a game.
  final List<String> players;

  /// One entry per played round; each entry holds one score per player.
  final List<List<int>> rounds;

  /// Total number of rounds for a fixed-length game, null for open-ended.
  final int? targetRounds;

  /// Ends the game once any player's total reaches this. Purely an
  /// end-of-game trigger — who wins stays with [lowestWins]. Null = no cap.
  final int? targetScore;

  /// Number fixed-length rounds from the top (R8, R7, … R1) instead of up.
  /// Only meaningful with [targetRounds]; ignored otherwise.
  final bool countDown;

  /// When true the fewest points lead and win (Hearts-style scoring).
  final bool lowestWins;

  /// Set when an open-ended game is ended with the "End game" action.
  bool endedManually;

  /// Exact-bid trick game (Whist). Hands run [whistMaxHand] down to 1,
  /// and that stack repeats [whistCycles] times (once per dealer).
  final bool whist;

  /// Cards (and tricks) in the first hand of each stack. Then 7, 6, \ldots 1.
  final int whistMaxHand;

  /// How many 8-down-to-1 stacks to play. Default is one per player.
  final int whistCycles;

  /// Seat that deals the first stack. The deal then moves to the next seat
  /// each stack, wrapping to the top.
  final int whistFirstDealer;

  /// Locked guesses for the current hand, or null if still bidding.
  List<int>? whistBids;

  /// True if that player hit their guess this hand. Tap to toggle. Nobody
  /// marked is allowed. Never null; missing/short saves become all-false.
  List<bool>? _whistHits;

  List<bool> get whistHits {
    final hits = _whistHits;
    if (hits == null || hits.length != players.length) {
      _whistHits = List<bool>.filled(players.length, false);
    }
    return _whistHits!;
  }

  set whistHits(List<bool> value) {
    _whistHits = _hitsOrEmpty(players.length, value);
  }

  /// When the game was created; shown in the past-games list.
  final DateTime startedAt;

  bool get isOver =>
      endedManually ||
      (whist && rounds.length >= whistMaxHand * whistCycles) ||
      (targetRounds != null && rounds.length >= targetRounds!) ||
      (targetScore != null && totals.any((total) => total >= targetScore!));

  /// Cards and tricks in the hand being played (8, then 7, \ldots 1).
  int get whistHandCards => whistMaxHand - (rounds.length % whistMaxHand);

  /// 1-based stack (dealer rotation).
  int get whistStackNumber => (rounds.length ~/ whistMaxHand) + 1;

  /// Player who deals this stack (and is last to bid).
  int get whistDealer =>
      (whistFirstDealer + whistStackNumber - 1) % players.length;

  bool get whistAwaitingBids => whist && !isOver && whistBids == null;

  bool get whistMarkingHits => whist && !isOver && whistBids != null;

  bool get whistReadyToFinish => whistMarkingHits;

  bool get whistEveryoneHit =>
      players.length > 1 && whistHits.every((hit) => hit);

  /// True if turning this player on would mark every player as a hit.
  bool whistWouldMarkEveryone(int player) =>
      !whistHit(player) &&
      List<bool>.generate(
        players.length,
        (i) => i == player || whistHit(i),
      ).every((hit) => hit);

  bool get canUndo =>
      endedManually ||
      (whist
          ? whistHits.any((hit) => hit) ||
                whistBids != null ||
                rounds.isNotEmpty
          : rounds.isNotEmpty);

  /// Display number of the round at [index]: 1-based counting up, or
  /// counting down from [targetRounds] when [countDown] is set.
  /// Whist rows are labeled by hand size (8, 7, \ldots 1).
  int roundNumber(int index) {
    if (whist) return whistMaxHand - (index % whistMaxHand);
    return countDown && targetRounds != null
        ? targetRounds! - index
        : index + 1;
  }

  /// Display number of the round about to be played.
  int get nextRoundNumber => roundNumber(rounds.length);

  /// True if the round at [index] opens a new Whist stack (not the first
  /// one). The deal moves on there too.
  bool startsWhistStack(int index) =>
      whist && index > 0 && index % whistMaxHand == 0;

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
    final best = sums.reduce((a, b) => (lowestWins ? a < b : a > b) ? a : b);
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

  /// Finishing place per player, shared on ties: 1, 1, 3. Best is the
  /// highest total, or the lowest when [lowestWins] is set.
  List<int> get places {
    final sums = totals;
    bool beats(int other, int mine) => lowestWins ? other < mine : other > mine;
    return [
      for (final mine in sums)
        1 + sums.where((other) => beats(other, mine)).length,
    ];
  }

  /// Points per player between their total and the winning one, in either
  /// scoring direction. Zero for the winners.
  List<int> get behindWinner {
    final sums = totals;
    final best = sums[standings.first];
    return [for (final total in sums) (total - best).abs()];
  }

  /// One-line result, read out with the final standings.
  String get resultHeadline {
    final winnerIndexes = leaders;
    if (winnerIndexes.isEmpty) {
      return 'Game over. No rounds were played.';
    }
    final names = winnerIndexes.map((i) => players[i]).join(' & ');
    final score = totals[winnerIndexes.first];
    if (winnerIndexes.length == 1) {
      return '$names wins with $score points!';
    }
    return 'Tie! $names share the win with $score points.';
  }

  /// A fresh game with the same players and rules, no rounds.
  Game rematch() => Game(
    players: List.of(players),
    targetRounds: targetRounds,
    targetScore: targetScore,
    countDown: countDown,
    lowestWins: lowestWins,
    whist: whist,
    whistMaxHand: whistMaxHand,
    whistCycles: whistCycles,
    whistFirstDealer: whistFirstDealer,
  );

  bool whistHit(int player) => whistHits[player];

  /// Seating indices in bid order: left of dealer first, dealer last.
  List<int> get whistBidOrder => [
    for (var i = 1; i <= players.length; i++)
      (whistDealer + i) % players.length,
  ];

  /// Guesses must not add up to the number of tricks, or everyone could hit.
  static bool whistBidTotalAllowed(List<int> bids, int handCards) =>
      bids.fold<int>(0, (sum, bid) => sum + bid) != handCards;

  void lockBids(List<int> bids) {
    if (!whist || isOver) {
      throw StateError('not a live whist hand');
    }
    if (whistBids != null) {
      throw StateError('bids are already locked');
    }
    if (bids.length != players.length) {
      throw ArgumentError(
        'expected ${players.length} bids, got ${bids.length}',
      );
    }
    final max = whistHandCards;
    for (final bid in bids) {
      if (bid < 0 || bid > max) {
        throw ArgumentError('bid $bid is outside 0..$max');
      }
    }
    if (!whistBidTotalAllowed(bids, max)) {
      throw ArgumentError('guesses must not add up to $max');
    }
    whistBids = List.of(bids);
    whistHits = List<bool>.filled(players.length, false);
  }

  /// Mark or unmark that this player hit their guess.
  void toggleWhistHit(int player) {
    if (!whistMarkingHits) {
      throw StateError('not marking hits');
    }
    if (player < 0 || player >= players.length) {
      throw ArgumentError('player $player');
    }
    if (whistWouldMarkEveryone(player)) {
      throw StateError('not everyone can hit');
    }
    whistHits[player] = !whistHits[player];
  }

  /// Score the hand: marked players get bid+10, everyone else 0.
  void finishWhistHand() {
    if (!whistReadyToFinish) {
      throw StateError('bids are not locked');
    }
    if (whistEveryoneHit) {
      throw StateError('not everyone can hit');
    }
    final bids = whistBids!;
    final scores = [
      for (var i = 0; i < players.length; i++) whistHits[i] ? bids[i] + 10 : 0,
    ];
    addRound(scores);
    whistBids = null;
    whistHits = List<bool>.filled(players.length, false);
  }

  void addRound(List<int> scores) {
    if (isOver) {
      throw StateError('cannot add a round to a finished game');
    }
    if (scores.length != players.length) {
      throw ArgumentError(
        'expected ${players.length} scores, got ${scores.length}',
      );
    }
    rounds.add(List.of(scores));
  }

  /// Replaces one played round. Totals and [isOver] follow [rounds], so a
  /// game that ended on the score target reopens when the new totals are
  /// under it. A manual end stays ended.
  void replaceRound(int index, List<int> scores) {
    if (index < 0 || index >= rounds.length) {
      throw RangeError.index(index, rounds, 'index');
    }
    if (scores.length != players.length) {
      throw ArgumentError(
        'expected ${players.length} scores, got ${scores.length}',
      );
    }
    rounds[index] = List.of(scores);
  }

  /// Takes back the last step. A manually ended game only reopens, with
  /// every round kept. Otherwise the most recent round is dropped, which
  /// also reopens a game that ended on its own.
  void undoLastRound() {
    if (endedManually) {
      endedManually = false;
      return;
    }
    if (whist) {
      if (whistHits.any((hit) => hit)) {
        whistHits = List<bool>.filled(players.length, false);
        return;
      }
      if (whistBids != null) {
        whistBids = null;
        return;
      }
    }
    if (rounds.isNotEmpty) {
      rounds.removeLast();
    }
  }

  Map<String, dynamic> toJson() => {
    'players': players,
    'rounds': rounds,
    'targetRounds': targetRounds,
    'targetScore': targetScore,
    'countDown': countDown,
    'lowestWins': lowestWins,
    'endedManually': endedManually,
    'whist': whist,
    'whistMaxHand': whistMaxHand,
    'whistCycles': whistCycles,
    'whistFirstDealer': whistFirstDealer,
    'whistBids': whistBids,
    'whistHits': whistHits,
    'startedAt': startedAt.toIso8601String(),
  };

  factory Game.fromJson(Map<String, dynamic> json) => Game(
    players: (json['players'] as List).cast<String>(),
    rounds: [
      for (final round in json['rounds'] as List) (round as List).cast<int>(),
    ],
    targetRounds: json['targetRounds'] as int?,
    targetScore: json['targetScore'] as int?,
    countDown: json['countDown'] as bool? ?? false,
    lowestWins: json['lowestWins'] as bool? ?? false,
    endedManually: json['endedManually'] as bool? ?? false,
    whist: json['whist'] as bool? ?? false,
    whistMaxHand: json['whistMaxHand'] as int? ?? 8,
    whistCycles: json['whistCycles'] as int?,
    whistFirstDealer: _seatOrZero(
      json['whistFirstDealer'],
      (json['players'] as List).length,
    ),
    whistBids: (json['whistBids'] as List?)?.cast<int>(),
    whistHits: (json['whistHits'] as List?)?.map((hit) => hit == true).toList(),
    startedAt: json['startedAt'] == null
        ? null
        : DateTime.parse(json['startedAt'] as String),
  );
}
