import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skore/data/app_data.dart';
import 'package:skore/data/game.dart';
import 'package:skore/data/game_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppData', () {
    test('archiveCurrent moves the game to history', () {
      final data = AppData(
        current: Game(players: ['A'], targetRounds: 1)..addRound([5]),
      );
      data.archiveCurrent();
      expect(data.current, isNull);
      expect(data.history, hasLength(1));
    });

    test('archiving an unfinished game marks it ended', () {
      final data = AppData(
        current: Game(players: ['A', 'B'])..addRound([1, 2]),
      );
      data.archiveCurrent();
      expect(data.history.single.isOver, isTrue);
    });

    test('rematchCurrent archives then starts the same rules', () {
      final original = Game(
        players: ['A', 'B'],
        targetRounds: 3,
        lowestWins: true,
      )..addRound([1, 2]);
      final data = AppData(current: original);
      data.rematchCurrent();
      expect(data.history, hasLength(1));
      expect(data.history.single.rounds, [
        [1, 2],
      ]);
      expect(data.current, isNotNull);
      expect(data.current!.players, ['A', 'B']);
      expect(data.current!.rounds, isEmpty);
      expect(data.current!.targetRounds, 3);
      expect(data.current!.lowestWins, isTrue);
      expect(identical(data.current, original), isFalse);
    });

    test('archiveCurrent without a game is a no-op', () {
      final data = AppData()..archiveCurrent();
      expect(data.history, isEmpty);
      expect(data.current, isNull);
    });

    test('JSON round-trip preserves current and history', () {
      final data = AppData(
        current: Game(players: ['A', 'B'])..addRound([1, 2]),
        history: [
          Game(players: ['C'], targetRounds: 1)..addRound([9]),
        ],
      );
      final copy = AppData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );
      expect(copy.current!.players, ['A', 'B']);
      expect(copy.history.single.players, ['C']);
      expect(copy.history.single.totals, [9]);
    });
  });

  group('GameStore', () {
    test('save/load round-trip', () async {
      await GameStore.save(
        AppData(current: Game(players: ['A', 'B'])..addRound([1, 2])),
      );
      final loaded = await GameStore.load();
      expect(loaded.current!.rounds, [
        [1, 2],
      ]);
      expect(loaded.history, isEmpty);
    });

    test('legacy single-game blobs are migrated and cleaned up', () async {
      SharedPreferences.setMockInitialValues({
        'skore.game':
            '{"players":["Ana"],"rounds":[[7]],"targetRounds":null,'
            '"endedManually":false}',
      });
      final loaded = await GameStore.load();
      expect(loaded.current!.players, ['Ana']);
      expect(loaded.history, isEmpty);

      await GameStore.save(loaded);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('skore.game'), isNull);
      expect(prefs.getString('skore.data'), contains('"Ana"'));
    });

    test('deleteAll wipes everything', () async {
      await GameStore.save(AppData(current: Game(players: ['A'])));
      await GameStore.deleteAll();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('skore.data'), isNull);
      expect((await GameStore.load()).current, isNull);
    });
  });
}
