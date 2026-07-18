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
