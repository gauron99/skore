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
    GameStore.debugSetString = null;
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

    test('discardCurrent drops the game and leaves history', () {
      final kept = Game(players: ['A'])..addRound([4]);
      final data = AppData(
        current: Game(players: ['B', 'C'])..addRound([1, 2]),
        history: [kept],
      );
      data.discardCurrent();
      expect(data.current, isNull);
      expect(data.history, [kept]);
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
      expect(copy.samePerson, isEmpty);
      expect(copy.displayNames, isEmpty);
    });

    test('samePerson round-trips and a bad entry is skipped', () {
      final data =
          AppData(
              history: [
                Game(players: ['Davca'])..addRound([1]),
              ],
            )
            ..samePerson['Davca'] = 'David'
            ..displayNames.add('Pat');
      final copy = AppData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );
      expect(copy.samePerson, {'Davca': 'David'});
      expect(copy.displayNames, ['Pat']);

      final old = AppData.fromJson({'current': null, 'history': []});
      expect(old.samePerson, isEmpty);
      expect(old.displayNames, isEmpty);

      final messy = AppData.fromJson({
        'current': null,
        'history': [],
        'samePerson': {'Davca': 'David', 'nope': 1, 'Ana': 'Ana', '': 'Ben'},
        'displayNames': [' Dave ', 'Dave', '', 1, 'Pat', 'Pat'],
      });
      expect(messy.samePerson, {'Davca': 'David'});
      expect(messy.displayNames, ['Dave', 'Pat']);
    });
  });

  group('GameStore', () {
    test('save/load round-trip', () async {
      await GameStore.save(
        AppData(current: Game(players: ['A', 'B'])..addRound([1, 2])),
      );
      final loaded = await GameStore.load();
      expect(loaded.data!.current!.rounds, [
        [1, 2],
      ]);
      expect(loaded.data!.history, isEmpty);
    });

    test('legacy single-game blobs are migrated and cleaned up', () async {
      SharedPreferences.setMockInitialValues({
        'skore.game':
            '{"players":["Ana"],"rounds":[[7]],"targetRounds":null,'
            '"endedManually":false}',
      });
      final loaded = await GameStore.load();
      expect(loaded.data!.current!.players, ['Ana']);
      expect(loaded.data!.history, isEmpty);

      await GameStore.save(loaded.data!);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('skore.game'), isNull);
      expect(prefs.getString('skore.data'), contains('"Ana"'));
    });

    test('deleteAll wipes everything', () async {
      await GameStore.save(AppData(current: Game(players: ['A'])));
      await GameStore.deleteAll();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('skore.data'), isNull);
      expect((await GameStore.load()).data!.current, isNull);
    });

    test('a broken past game is skipped and the current game stays', () async {
      final raw = jsonEncode({
        'current': {
          'players': ['Zed', 'Quinn'],
          'rounds': [
            [8, 1],
          ],
        },
        'history': [
          null,
          {
            'players': ['Ana'],
            'rounds': [
              [4],
            ],
            'endedManually': true,
          },
          {
            'players': ['X'],
            'rounds': 'no',
          },
        ],
      });
      SharedPreferences.setMockInitialValues({'skore.data': raw});
      final loaded = await GameStore.load();
      expect(loaded.blocked, isFalse);
      expect(loaded.data!.current!.players, ['Zed', 'Quinn']);
      expect(loaded.data!.current!.totals, [8, 1]);
      expect(loaded.data!.history.single.players, ['Ana']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('skore.data'), raw);
    });

    test('an unreadable current game is left on disk', () async {
      const raw =
          '{"current":{"players":["Zed","Quinn"],"rounds":[[8,"x"]]},'
          '"history":[]}';
      SharedPreferences.setMockInitialValues({'skore.data': raw});
      final loaded = await GameStore.load();
      expect(loaded.blocked, isTrue);
      expect(loaded.data, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('skore.data'), raw);
    });

    test('a failed write keeps the old blob and the legacy key', () async {
      const legacy = '{"players":["Ana"],"rounds":[[7]]}';
      const data = '{"current":null,"history":[]}';
      SharedPreferences.setMockInitialValues({
        'skore.game': legacy,
        'skore.data': data,
      });
      GameStore.debugSetString = (prefs, key, value) async => false;
      await expectLater(
        GameStore.save(AppData(current: Game(players: ['Ben']))),
        throwsA(isA<StateError>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('skore.game'), legacy);
      expect(prefs.getString('skore.data'), data);
    });
  });
}
