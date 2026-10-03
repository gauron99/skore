import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:skore/data/game.dart';

void main() {
  test('totals accumulate across rounds', () {
    final game = Game(players: ['A', 'B']);
    game.addRound([10, 7]);
    game.addRound([-3, 5]);
    expect(game.totals, [7, 12]);
  });

  group('leaders', () {
    test('nobody leads before the first round', () {
      expect(Game(players: ['A', 'B']).leaders, isEmpty);
    });

    test('highest total leads', () {
      final game = Game(players: ['A', 'B'])..addRound([1, 4]);
      expect(game.leaders, [1]);
    });

    test('ties crown everyone at the top', () {
      final game = Game(players: ['A', 'B', 'C'])..addRound([4, 4, 1]);
      expect(game.leaders, [0, 1]);
    });
  });

  group('fixed-length games', () {
    test('end after the target round', () {
      final game = Game(players: ['A', 'B'], targetRounds: 2);
      expect(game.isOver, isFalse);
      game.addRound([1, 2]);
      expect(game.isOver, isFalse);
      game.addRound([3, 4]);
      expect(game.isOver, isTrue);
    });

    test('refuse rounds after the end', () {
      final game = Game(players: ['A'], targetRounds: 1)..addRound([1]);
      expect(() => game.addRound([2]), throwsStateError);
    });

    test('undo reopens the game', () {
      final game = Game(players: ['A'], targetRounds: 1)..addRound([1]);
      game.undoLastRound();
      expect(game.isOver, isFalse);
      expect(game.rounds, isEmpty);
    });
  });

  group('open-ended games', () {
    test('run until ended manually', () {
      final game = Game(players: ['A', 'B'])..addRound([1, 2]);
      expect(game.isOver, isFalse);
      game.endedManually = true;
      expect(game.isOver, isTrue);
    });

    test('undo also reopens a manually ended game', () {
      final game = Game(players: ['A', 'B'])..addRound([1, 2]);
      game.endedManually = true;
      game.undoLastRound();
      expect(game.isOver, isFalse);
    });
  });

  group('score-target games', () {
    test('end once a player reaches the target', () {
      final game = Game(players: ['A', 'B'], targetScore: 20);
      game.addRound([10, 5]);
      expect(game.isOver, isFalse);
      game.addRound([10, 5]);
      expect(game.isOver, isTrue);
    });

    test('the target only ends the game — lowest can still win', () {
      final game = Game(players: ['A', 'B'], targetScore: 20, lowestWins: true)
        ..addRound([21, 4]);
      expect(game.isOver, isTrue);
      expect(game.leaders, [1]);
    });

    test('undo drops back below the target and reopens the game', () {
      final game = Game(players: ['A'], targetScore: 10)..addRound([12]);
      expect(game.isOver, isTrue);
      game.undoLastRound();
      expect(game.isOver, isFalse);
    });

    test('combines with a round limit — whichever hits first ends it', () {
      final game = Game(players: ['A'], targetRounds: 5, targetScore: 10);
      game.addRound([11]);
      expect(game.isOver, isTrue);
    });

    test('JSON round-trip preserves the target; old blobs stay uncapped', () {
      final copy = Game.fromJson(
        Game(players: ['A'], targetScore: 50).toJson(),
      );
      expect(copy.targetScore, 50);
      final legacy = Game.fromJson({
        'players': ['A'],
        'rounds': <List<int>>[],
        'targetRounds': null,
        'endedManually': false,
      });
      expect(legacy.targetScore, isNull);
    });
  });

  group('countdown rounds', () {
    test('round numbers count down from the limit', () {
      final game = Game(players: ['A'], targetRounds: 8, countDown: true);
      expect(game.nextRoundNumber, 8);
      game.addRound([1]);
      expect(game.roundNumber(0), 8);
      expect(game.nextRoundNumber, 7);
    });

    test('counting up stays the default', () {
      final game = Game(players: ['A'], targetRounds: 3)..addRound([1]);
      expect(game.roundNumber(0), 1);
      expect(game.nextRoundNumber, 2);
    });

    test('countDown without a round limit falls back to counting up', () {
      final game = Game(players: ['A'], countDown: true)..addRound([1]);
      expect(game.roundNumber(0), 1);
      expect(game.nextRoundNumber, 2);
    });

    test('JSON round-trip preserves the flag', () {
      final copy = Game.fromJson(
        Game(players: ['A'], targetRounds: 2, countDown: true).toJson(),
      );
      expect(copy.countDown, isTrue);
      expect(copy.nextRoundNumber, 2);
    });
  });

  group('whist', () {
    Game fresh() => Game(
      players: ['Ana', 'Ben', 'Cara'],
      whist: true,
      whistMaxHand: 2,
      whistCycles: 3,
    );

    test('hands run 2 then 1, three stacks, then the game is over', () {
      final game = fresh();
      expect(game.whistHandCards, 2);
      expect(game.whistStackNumber, 1);
      expect(game.whistDealer, 0);
      game.lockBids([2, 1, 0]);
      game.toggleWhistHit(0);
      game.toggleWhistHit(2);
      game.finishWhistHand();
      expect(game.rounds, [
        [12, 0, 10],
      ]);
      expect(game.whistHandCards, 1);
      game.lockBids([0, 0, 0]);
      game.toggleWhistHit(1);
      game.toggleWhistHit(2);
      game.finishWhistHand();
      expect(game.rounds.last, [0, 10, 10]);
      expect(game.whistStackNumber, 2);
      expect(game.whistDealer, 1);
      expect(game.whistHandCards, 2);
    });

    test('first dealer starts the deal; it moves one seat per stack', () {
      final game = Game(
        players: ['Ana', 'Ben', 'Cara'],
        whist: true,
        whistMaxHand: 2,
        whistCycles: 3,
        whistFirstDealer: 2,
      );
      expect(game.whistBidOrder, [0, 1, 2]);
      final dealers = <int>[];
      while (!game.isOver) {
        dealers.add(game.whistDealer);
        expect(game.whistBidOrder.last, game.whistDealer);
        game.lockBids([0, 0, 0]);
        game.finishWhistHand();
      }
      expect(dealers, [2, 2, 0, 0, 1, 1]);
    });

    test('marked players score bid plus 10; unmarked score 0', () {
      final game = fresh();
      game.lockBids([2, 1, 0]);
      game.toggleWhistHit(0);
      game.finishWhistHand();
      expect(game.rounds.single, [12, 0, 0]);
    });

    test('nobody marked is allowed and everyone scores 0', () {
      final game = fresh()..lockBids([2, 1, 0]);
      expect(game.whistReadyToFinish, isTrue);
      game.finishWhistHand();
      expect(game.rounds.single, [0, 0, 0]);
    });

    test('cannot mark every player as a hit', () {
      final game = fresh()..lockBids([2, 1, 0]);
      game.toggleWhistHit(0);
      game.toggleWhistHit(1);
      expect(() => game.toggleWhistHit(2), throwsStateError);
      expect(game.whistHits, [true, true, false]);
    });

    test('toggle can unmark a hit', () {
      final game = fresh()..lockBids([2, 1, 0]);
      game.toggleWhistHit(0);
      game.toggleWhistHit(0);
      game.finishWhistHand();
      expect(game.rounds.single, [0, 0, 0]);
    });

    test('guesses must not add up to the number of tricks', () {
      final game = fresh();
      expect(() => game.lockBids([2, 0, 0]), throwsArgumentError);
      game.lockBids([2, 1, 0]);
      expect(game.whistBids, [2, 1, 0]);
    });

    test('undo clears hits, then unlocks bids, then the last hand', () {
      final game = fresh();
      game.lockBids([1, 0, 0]);
      game.toggleWhistHit(1);
      game.undoLastRound();
      expect(game.whistHits, [false, false, false]);
      expect(game.whistBids, [1, 0, 0]);
      game.undoLastRound();
      expect(game.whistBids, isNull);
      game.lockBids([1, 0, 0]);
      game.toggleWhistHit(0);
      game.finishWhistHand();
      expect(game.rounds, hasLength(1));
      game.undoLastRound();
      expect(game.rounds, isEmpty);
      expect(game.whistHandCards, 2);
    });

    test('JSON round-trip keeps bids and hits in flight', () {
      final game = fresh()..lockBids([1, 0, 0]);
      game.toggleWhistHit(2);
      final copy = Game.fromJson(game.toJson());
      expect(copy.whist, isTrue);
      expect(copy.whistBids, [1, 0, 0]);
      expect(copy.whistHits, [false, false, true]);
      expect(copy.whistHandCards, 2);
    });

    test('JSON round-trip keeps the first dealer', () {
      final game = Game(
        players: ['Ana', 'Ben', 'Cara'],
        whist: true,
        whistFirstDealer: 2,
      );
      final copy = Game.fromJson(
        jsonDecode(jsonEncode(game.toJson())) as Map<String, dynamic>,
      );
      expect(copy.whistFirstDealer, 2);
      expect(copy.whistDealer, 2);
    });

    test('saves without a valid first dealer keep the old deal order', () {
      Map<String, dynamic> save(Object? firstDealer) => {
        'players': ['A', 'B', 'C'],
        'rounds': [
          [0, 0, 0],
          [0, 0, 0],
        ],
        'endedManually': false,
        'whist': true,
        'whistMaxHand': 2,
        'whistCycles': 3,
        'whistFirstDealer': ?firstDealer,
      };
      for (final firstDealer in [null, 3, -1, 'x']) {
        final game = Game.fromJson(save(firstDealer));
        expect(game.whistFirstDealer, 0, reason: '$firstDealer');
        // Second stack: seat 1 deals, as before the field existed.
        expect(game.whistDealer, 1, reason: '$firstDealer');
      }
    });

    test('toJson always writes a hits list, even if the save omitted it', () {
      final game = Game.fromJson({
        'players': ['A', 'B', 'C'],
        'rounds': <List<int>>[],
        'endedManually': false,
        'whist': true,
        'whistBids': [1, 0, 0],
      });
      expect(game.whistHits, [false, false, false]);
      final json = game.toJson();
      expect(json['whistHits'], [false, false, false]);
      game.toggleWhistHit(0);
      expect(game.toJson()['whistHits'], [true, false, false]);
    });

    test('legacy saves without whist stay ordinary games', () {
      final copy = Game.fromJson({
        'players': ['A'],
        'rounds': <List<int>>[],
        'targetRounds': null,
        'endedManually': false,
      });
      expect(copy.whist, isFalse);
    });
  });

  test('rematch copies players and rules, not rounds', () {
    final game = Game(
      players: ['A', 'B'],
      targetRounds: 8,
      targetScore: 50,
      countDown: true,
      lowestWins: true,
    )..addRound([1, 2]);
    game.endedManually = true;
    final next = game.rematch();
    expect(next.players, ['A', 'B']);
    expect(next.rounds, isEmpty);
    expect(next.targetRounds, 8);
    expect(next.targetScore, 50);
    expect(next.countDown, isTrue);
    expect(next.lowestWins, isTrue);
    expect(next.endedManually, isFalse);
    expect(next.isOver, isFalse);
  });

  test('rematch keeps whist rules', () {
    final next = Game(
      players: ['A', 'B', 'C'],
      whist: true,
      whistMaxHand: 8,
      whistCycles: 3,
      whistFirstDealer: 2,
    ).rematch();
    expect(next.whist, isTrue);
    expect(next.whistMaxHand, 8);
    expect(next.whistCycles, 3);
    expect(next.whistFirstDealer, 2);
    expect(next.rounds, isEmpty);
  });

  test('resultHeadline names the winner', () {
    final game = Game(players: ['Ana', 'Ben'])..addRound([5, 3]);
    expect(game.resultHeadline, 'Ana wins with 5 points!');
    final tie = Game(players: ['A', 'B'])..addRound([4, 4]);
    expect(tie.resultHeadline, contains('Tie!'));
  });

  test('addRound rejects a score-count mismatch', () {
    final game = Game(players: ['A', 'B']);
    expect(() => game.addRound([1]), throwsArgumentError);
  });

  test('standings sort by total, highest first, ties in seating order', () {
    final game = Game(players: ['A', 'B', 'C'])..addRound([3, 9, 3]);
    expect(game.standings, [1, 0, 2]);
  });

  group('lowest points wins', () {
    test('leader is the lowest total', () {
      final game = Game(players: ['A', 'B'], lowestWins: true)
        ..addRound([5, 2]);
      expect(game.leaders, [1]);
    });

    test('standings sort lowest first', () {
      final game = Game(players: ['A', 'B', 'C'], lowestWins: true)
        ..addRound([3, 9, 1]);
      expect(game.standings, [2, 0, 1]);
    });

    test('JSON round-trip preserves the flag', () {
      final copy = Game.fromJson(
        Game(players: ['A'], lowestWins: true).toJson(),
      );
      expect(copy.lowestWins, isTrue);
    });

    test('saves from before the option existed default to highest wins', () {
      final copy = Game.fromJson({
        'players': ['A'],
        'rounds': <List<int>>[],
        'targetRounds': null,
        'endedManually': false,
      });
      expect(copy.lowestWins, isFalse);
    });
  });

  group('JSON round-trip', () {
    test('preserves an open-ended game', () {
      final game = Game(players: ['Ana', 'Ben'])..addRound([10, -2]);
      final copy = Game.fromJson(game.toJson());
      expect(copy.players, ['Ana', 'Ben']);
      expect(copy.rounds, [
        [10, -2],
      ]);
      expect(copy.targetRounds, isNull);
      expect(copy.endedManually, isFalse);
    });

    test('preserves a finished fixed-length game', () {
      final game = Game(players: ['A'], targetRounds: 1)..addRound([5]);
      final copy = Game.fromJson(game.toJson());
      expect(copy.targetRounds, 1);
      expect(copy.isOver, isTrue);
    });

    test('startedAt survives the round-trip', () {
      final game = Game(players: ['A'], startedAt: DateTime(2026, 7, 18));
      expect(Game.fromJson(game.toJson()).startedAt, DateTime(2026, 7, 18));
    });

    test('survives encoding to actual JSON text', () {
      final game = Game(players: ['A', 'B'], targetRounds: 3)..addRound([1, 2]);
      final copy = Game.fromJson(
        jsonDecode(jsonEncode(game.toJson())) as Map<String, dynamic>,
      );
      expect(copy.rounds, [
        [1, 2],
      ]);
      expect(copy.targetRounds, 3);
    });
  });
}
