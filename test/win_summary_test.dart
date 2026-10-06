import 'package:flutter_test/flutter_test.dart';
import 'package:skore/data/game.dart';
import 'package:skore/data/win_summary.dart';

void main() {
  test('counts wins, ties, and exact names', () {
    final ana = Game(players: ['Ana', 'Ben'])..addRound([3, 1]);
    final tie = Game(players: ['Ana', 'Ben'])..addRound([2, 2]);
    final low = Game(players: ['Ana', 'Cara'], lowestWins: true)
      ..addRound([5, 1]);
    final spellings = Game(players: ['Davca', 'David'])..addRound([4, 1]);
    final blank = Game(players: [' Ana ', 'Ben']);

    final rows = winSummary([ana, tie, low, spellings, blank]);
    expect(
      [for (final row in rows) '${row.name} ${row.wins} of ${row.played}'],
      [
        'Ana 2 of 4',
        'Cara 1 of 1',
        'Davca 1 of 1',
        'Ben 1 of 3',
        'David 0 of 1',
      ],
    );
    expect(rows.first.winPercent, 50);
    expect(rows[1].winPercent, 100);
  });

  test('linked spellings add up under one person', () {
    final davca = Game(players: ['Davca', 'Ben'])..addRound([2, 0]);
    final david = Game(players: ['David', 'Ben'])..addRound([3, 0]);
    final rows = winSummary([davca, david], {'Davca': 'David'});
    expect(
      [for (final row in rows) '${row.name} ${row.wins} of ${row.played}'],
      ['David 2 of 2', 'Ben 0 of 2'],
    );
    expect(rows.first.winPercent, 100);
    expect(rows.first.also, ['Davca']);
  });

  test('two spellings in one game count as one seat', () {
    final game = Game(players: ['Davca', 'David'])..addRound([2, 2]);
    final rows = winSummary([game], {'Davca': 'David'});
    expect(rows.single.name, 'David');
    expect(rows.single.played, 1);
    expect(rows.single.wins, 1);
  });

  test('a chain counts as the last person, a loop stays together', () {
    final rows = winSummary(
      [
        Game(players: ['Davca'])..addRound([1]),
        Game(players: ['David'])..addRound([1]),
      ],
      {'Davca': 'David', 'David': 'Dana'},
    );
    expect(rows.single.name, 'Dana');
    expect(rows.single.wins, 2);

    const loop = {'Davca': 'David', 'David': 'Davca'};
    expect(personRoot('Davca', loop), 'Davca');
    expect(personRoot('David', loop), 'Davca');
  });

  test('same person links flatten and can be split', () {
    final links = <String, String>{};
    applySamePerson(links, 'David', 'Dana');
    applySamePerson(links, 'Davca', 'David');
    expect(links, {'David': 'Dana', 'Davca': 'Dana'});

    // Dana's row picks Davca, so the group is called Davca.
    applySamePerson(links, 'Dana', 'Davca');
    expect(personRoot('Dana', links), 'Davca');
    expect(personRoot('David', links), 'Davca');
    expect(personRoot('Davca', links), 'Davca');

    applySamePerson(links, 'David', 'David');
    expect(links.containsKey('David'), isFalse);
    expect(personRoot('David', links), 'David');
    expect(personRoot('Davca', links), 'Davca');
    expect(personRoot('Dana', links), 'Davca');
  });

  test('a group shows one name and leaves the others behind', () {
    final links = <String, String>{'Davca': 'David'};
    applyGroup(
      links,
      allNames: ['Ana', 'Davca', 'davca', 'David'],
      previousDisplay: 'David',
      display: 'David',
      members: {'David', 'Davca', 'davca'},
    );
    expect(links, {'Davca': 'David', 'davca': 'David'});

    applyGroup(
      links,
      allNames: ['Ana', 'Davca', 'davca', 'David'],
      previousDisplay: 'David',
      display: 'Davca',
      members: {'David', 'Davca', 'davca'},
    );
    expect(personRoot('David', links), 'Davca');
    expect(personRoot('davca', links), 'Davca');
    expect(links.containsKey('Davca'), isFalse);

    applyGroup(
      links,
      allNames: ['Ana', 'Davca', 'davca', 'David'],
      previousDisplay: 'Davca',
      display: 'Davca',
      members: {'Davca', 'David'},
    );
    expect(personRoot('davca', links), 'davca');
    expect(personRoot('David', links), 'Davca');

    applyGroup(
      links,
      allNames: ['Ana', 'Davca', 'davca', 'David'],
      previousDisplay: 'Ana',
      display: 'Ana',
      members: {'Ana', 'David'},
    );
    expect(personRoot('David', links), 'Ana');
    expect(personRoot('Davca', links), 'Davca');
  });

  test('the most used spelling wins, and a tie breaks by name', () {
    final twice = Game(players: ['Davca', 'David', 'Davca'])
      ..addRound([1, 1, 1]);
    final david = Game(players: ['David', 'Ben'])..addRound([2, 0]);
    final counts = spellingCounts([twice, david]);
    expect(counts, {'Davca': 1, 'David': 2, 'Ben': 1});
    expect(mostFrequent(['Davca', 'David', 'Ben'], counts), 'David');
    expect(
      mostFrequent(const ['David', 'Davca'], const {'Davca': 1, 'David': 1}),
      'Davca',
    );
    expect(mostFrequent(const ['  ', ''], counts), isNull);
  });
}
