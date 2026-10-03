import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skore/data/game.dart';
import 'package:skore/main.dart';
import 'package:skore/screens/scoreboard_screen.dart';
import 'package:skore/screens/setup_screen.dart';
import 'package:skore/widgets/whist_bid_dialog.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const SkoreApp());
  await tester.pumpAndSettle();
}

/// Scrolls the setup list until [finder] is built and visible. (ListView
/// builds lazily, so off-screen children don't exist for ensureVisible.)
/// Settles first: a caret reveal still queued from enterText would scroll
/// the list back to that field after we jump.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    finder,
    80,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Start game stays off until every player is named', (
    tester,
  ) async {
    FilledButton startButton() => tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Start game'),
        matching: find.byType(FilledButton),
      ),
    );

    await pumpApp(tester);
    await scrollTo(tester, find.text('Start game'));
    expect(startButton().onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Ana');
    await tester.enterText(find.byType(TextField).at(1), 'Ben');
    await tester.pump();
    await scrollTo(tester, find.text('Start game'));
    expect(startButton().onPressed, isNotNull);
  });

  testWidgets('duplicate names block Start and flag the repeat', (
    tester,
  ) async {
    FilledButton startButton() => tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Start game'),
        matching: find.byType(FilledButton),
      ),
    );

    await pumpApp(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ana');
    await tester.enterText(fields.at(1), ' ana ');
    await tester.pump();
    expect(find.text('Name already used'), findsOneWidget);
    expect(
      tester.widget<TextField>(fields.at(1)).decoration!.errorText,
      'Name already used',
    );
    expect(startButton().onPressed, isNull);

    await tester.enterText(fields.at(1), 'Ben');
    await tester.pump();
    expect(find.text('Name already used'), findsNothing);
    expect(startButton().onPressed, isNotNull);
  });

  testWidgets('whist setup keeps at least three players', (tester) async {
    List<bool> removable() => [
      for (final button in tester.widgetList<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove_circle_outline),
      ))
        button.onPressed != null,
    ];

    await pumpApp(tester);
    await tester.tap(find.text('Whist'));
    await tester.pumpAndSettle();
    expect(removable(), [false, false, false]);

    await tester.tap(find.text('Add player'));
    await tester.pumpAndSettle();
    expect(removable(), [true, true, true, true]);

    await tester.tap(find.byTooltip('Remove player').last);
    await tester.pumpAndSettle();
    expect(removable(), [false, false, false]);

    await tester.tap(find.text('Whist'));
    await tester.pumpAndSettle();
    expect(removable(), [true, true, true]);
  });

  testWidgets('whist setup: seat labels follow a reorder', (tester) async {
    String? labelOf(String name) => tester
        .widget<TextField>(find.widgetWithText(TextField, name))
        .decoration!
        .labelText;

    await pumpApp(tester);
    await tester.tap(find.text('Whist'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Seating order.'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ana');
    await tester.enterText(fields.at(1), 'Ben');
    await tester.enterText(fields.at(2), 'Cara');
    await tester.pumpAndSettle();
    expect(labelOf('Ana'), 'Bids 1st');
    expect(labelOf('Ben'), 'Bids 2nd');
    expect(labelOf('Cara'), 'Deals · bids last');

    // Drag Cara's handle above Ana.
    await tester.timedDrag(
      find.byIcon(Icons.drag_handle).at(2),
      const Offset(0, -200),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();

    expect(labelOf('Cara'), 'Bids 1st');
    expect(labelOf('Ana'), 'Bids 2nd');
    expect(labelOf('Ben'), 'Deals · bids last');
  });

  testWidgets('whist Start makes the last seat the first dealer', (
    tester,
  ) async {
    Game? started;
    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(
          onStart: (game) => started = game,
          onShowHistory: () {},
        ),
      ),
    );
    await tester.tap(find.text('Whist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add player'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ana');
    await tester.enterText(fields.at(1), 'Ben');
    await tester.enterText(fields.at(2), 'Cara');
    await tester.enterText(fields.at(3), 'Dana');
    await scrollTo(tester, find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    expect(started!.players, ['Ana', 'Ben', 'Cara', 'Dana']);
    expect(started!.whistFirstDealer, 3);
    expect(started!.whistDealer, 3);
    expect(started!.whistBidOrder, [0, 1, 2, 3]);
  });

  testWidgets('setup → scoreboard → first round updates totals and saves', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Players'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Ana');
    await tester.enterText(find.byType(TextField).at(1), 'Ben');
    await scrollTo(tester, find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    expect(find.text('Add round'), findsOneWidget);
    await tester.tap(find.text('Add round'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Ana'), '10');
    await tester.enterText(find.widgetWithText(TextField, 'Ben'), '7');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Totals strip, history table, and SUM row all show the scores.
    expect(find.text('10'), findsWidgets);
    expect(find.text('7'), findsWidgets);
    expect(find.text('SUM'), findsOneWidget);

    // The mutation was persisted immediately.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('skore.data'), contains('[[10,7]]'));
  });

  testWidgets('fixed-length game auto-ends with final standings', (
    tester,
  ) async {
    await pumpApp(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ana');
    await tester.enterText(fields.at(1), 'Ben');
    await tester.enterText(fields.at(2), '1'); // round limit
    await scrollTo(tester, find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    expect(find.text('Round 1 of 1'), findsOneWidget);
    await tester.tap(find.text('Add round'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ana'), '5');
    await tester.enterText(find.widgetWithText(TextField, 'Ben'), '3');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Ana wins with 5 points!'), findsOneWidget);
    expect(find.text('New game'), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('Add round'), findsNothing);

    // The paper-style sheet: round rows and the sums under the double rule.
    expect(find.text('R1'), findsOneWidget);
    expect(find.text('Σ'), findsOneWidget);
    expect(find.text('5'), findsWidgets);
    expect(find.text('3'), findsWidgets);
  });

  testWidgets('finished games are archived, viewable, and deletable', (
    tester,
  ) async {
    await pumpApp(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ana');
    await tester.enterText(fields.at(1), 'Ben');
    await tester.enterText(fields.at(2), '1'); // round limit
    await scrollTo(tester, find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add round'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ana'), '5');
    await tester.enterText(find.widgetWithText(TextField, 'Ben'), '3');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // "New game" archives and rematches with the same players and rules.
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    expect(find.text('Add round'), findsOneWidget);
    expect(find.text('Ana'), findsWidgets);
    expect(find.text('Ben'), findsWidgets);
    expect(find.text('Players'), findsNothing);

    // The archived game shows up in Past games as a score sheet.
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Past games'));
    await tester.pumpAndSettle();
    expect(find.text('Ana 5 · Ben 3'), findsOneWidget);
    expect(find.textContaining('winner: Ana'), findsOneWidget);

    await tester.tap(find.text('Ana 5 · Ben 3'));
    await tester.pumpAndSettle();
    expect(find.text('Ana wins with 5 points!'), findsOneWidget);
    expect(find.text('R1'), findsOneWidget);
    expect(find.text('Σ'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Delete all data -> back on a fresh setup, nothing stored.
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.text('Players'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('skore.data'), isNull);
  });

  testWidgets('lowest-points-wins game crowns the lowest total', (
    tester,
  ) async {
    await pumpApp(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ana');
    await tester.enterText(fields.at(1), 'Ben');
    await tester.enterText(fields.at(2), '1'); // round limit
    await scrollTo(tester, find.text('Lowest points wins'));
    await tester.tap(find.text('Lowest points wins'));
    await scrollTo(tester, find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add round'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ana'), '5');
    await tester.enterText(find.widgetWithText(TextField, 'Ben'), '3');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Ben wins with 3 points!'), findsOneWidget);
  });

  testWidgets('rounds are listed in play order, first round on top', (
    tester,
  ) async {
    await pumpApp(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ana');
    await tester.enterText(fields.at(1), 'Ben');
    await scrollTo(tester, find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    for (final scores in [
      ['1', '2'],
      ['3', '4'],
    ]) {
      await tester.tap(find.text('Add round'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Ana'), scores[0]);
      await tester.enterText(find.widgetWithText(TextField, 'Ben'), scores[1]);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    final r1y = tester.getTopLeft(find.text('R1')).dy;
    final r2y = tester.getTopLeft(find.text('R2')).dy;
    expect(r1y, lessThan(r2y));
  });

  testWidgets('countdown mode numbers rounds from the top', (tester) async {
    await pumpApp(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ana');
    await tester.enterText(fields.at(1), 'Ben');
    await tester.enterText(fields.at(2), '2'); // round limit
    await scrollTo(tester, find.text('Count rounds down'));
    await tester.tap(find.text('Count rounds down'));
    await scrollTo(tester, find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    expect(find.text('Round 2 of 2'), findsOneWidget);

    await tester.tap(find.text('Add round'));
    await tester.pumpAndSettle();
    expect(find.text('Round 2 scores'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Ana'), '4');
    await tester.enterText(find.widgetWithText(TextField, 'Ben'), '3');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Next round counts down, and the played round is labeled from the top.
    expect(find.text('Round 1 of 2'), findsOneWidget);
    expect(find.text('R2'), findsOneWidget);
  });

  testWidgets('game ends when a player reaches the score target', (
    tester,
  ) async {
    await pumpApp(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ana');
    await tester.enterText(fields.at(1), 'Ben');
    await tester.enterText(fields.at(3), '10'); // score target
    await scrollTo(tester, find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    expect(find.textContaining('playing to 10'), findsOneWidget);

    await tester.tap(find.text('Add round'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ana'), '4');
    await tester.enterText(find.widgetWithText(TextField, 'Ben'), '3');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Add round'), findsOneWidget); // 4:3 — still going

    await tester.tap(find.text('Add round'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ana'), '7');
    await tester.enterText(find.widgetWithText(TextField, 'Ben'), '1');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Ana hit 11 >= 10: game over, standings shown.
    expect(find.text('Ana wins with 11 points!'), findsOneWidget);
    expect(find.text('Add round'), findsNothing);
  });

  testWidgets('text scales up on large screens', (tester) async {
    tester.view.physicalSize = const Size(2400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpApp(tester);

    final context = tester.element(find.byType(HomeGate));
    // shortestSide 1400 -> capped at the 1.8x maximum.
    expect(MediaQuery.textScalerOf(context).scale(14), closeTo(14 * 1.8, 0.1));
  });

  testWidgets('phone-sized screens keep the native text size', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpApp(tester);

    final context = tester.element(find.byType(HomeGate));
    expect(MediaQuery.textScalerOf(context).scale(14), 14);
  });

  testWidgets('whist last guess: cannot-N in red, or any number 0 to hand', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WhistBidDialog(
            players: ['Ana', 'Ben', 'Cara'],
            handCards: 8,
            bidOrder: [1, 2, 0],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cannot guess 8'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Ben'), '9');
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Ben'))
          .controller!
          .text,
      isNot(equals('9')),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Ben'), '5');
    await tester.enterText(find.widgetWithText(TextField, 'Cara'), '4');
    await tester.pump();
    expect(
      find.textContaining('You can guess any number 0 to 8'),
      findsOneWidget,
    );

    await tester.enterText(find.widgetWithText(TextField, 'Cara'), '2');
    await tester.pump();
    expect(find.text('Cannot guess 1'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Ana (last)'), '1');
    await tester.pump();
    expect(find.text('Cannot guess 1'), findsOneWidget);
  });

  testWidgets('whist: lock guesses then tap trick winners to score', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final game = Game(
      players: ['Ana', 'Ben', 'Cara'],
      whist: true,
      whistMaxHand: 2,
      whistCycles: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ScoreboardScreen(
          game: game,
          onRematch: () {},
          onChangeSetup: () {},
          onShowHistory: () {},
          onPersist: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lock guesses'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Ben'), '1');
    await tester.enterText(find.widgetWithText(TextField, 'Cara'), '0');
    await tester.enterText(find.widgetWithText(TextField, 'Ana (last)'), '2');
    await tester.tap(find.text('Lock guesses'));
    await tester.pumpAndSettle();

    expect(find.text('Finish round'), findsOneWidget);
    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cara'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish round'));
    await tester.pumpAndSettle();

    expect(game.rounds.single, [12, 0, 10]);
    expect(find.text('12'), findsWidgets);
    expect(find.text('SUM'), findsOneWidget);
  });

  testWidgets('whist: See scores hides the popup; bottom bar restores drafts', (
    tester,
  ) async {
    final game = Game(
      players: ['Ana', 'Ben', 'Cara'],
      whist: true,
      whistMaxHand: 2,
      whistCycles: 1,
    )..addRound([12, 0, 10]);
    await tester.pumpWidget(
      MaterialApp(
        home: ScoreboardScreen(
          game: game,
          onRematch: () {},
          onChangeSetup: () {},
          onShowHistory: () {},
          onPersist: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lock guesses'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Ben'), '1');
    await tester.tap(find.text('See scores'));
    await tester.pumpAndSettle();

    expect(find.text('Lock guesses'), findsNothing);
    expect(find.text('Back to guesses'), findsOneWidget);
    expect(find.text('SUM'), findsOneWidget);
    expect(find.text('12'), findsWidgets);

    await tester.tap(find.text('Back to guesses'));
    await tester.pumpAndSettle();
    expect(find.text('Lock guesses'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Ben'))
          .controller!
          .text,
      '1',
    );
  });

  testWidgets('whist: D marks the dealer during play, not on final standings', (
    tester,
  ) async {
    Widget board(Game game) => MaterialApp(
      home: ScoreboardScreen(
        game: game,
        onRematch: () {},
        onChangeSetup: () {},
        onShowHistory: () {},
        onPersist: () async {},
      ),
    );

    final game = Game(
      players: ['Ana', 'Ben', 'Cara'],
      whist: true,
      whistMaxHand: 2,
      whistCycles: 1,
      whistFirstDealer: 1,
    );
    await tester.pumpWidget(board(game));
    await tester.pumpAndSettle();

    // Totals cards sit behind the guess popup.
    expect(find.text('D'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(of: find.text('Ben'), matching: find.byType(Card)),
        matching: find.text('D'),
      ),
      findsOneWidget,
    );

    await tester.enterText(find.widgetWithText(TextField, 'Cara'), '1');
    await tester.tap(find.text('Lock guesses'));
    await tester.pumpAndSettle();
    expect(find.text('Finish round'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    expect(
      find.descendant(
        of: find
            .ancestor(of: find.text('D'), matching: find.byType(InkWell))
            .first,
        matching: find.text('Ben'),
      ),
      findsOneWidget,
    );

    final over =
        Game(
            players: ['Ana', 'Ben', 'Cara'],
            whist: true,
            whistMaxHand: 1,
            whistCycles: 1,
            whistFirstDealer: 1,
          )
          ..lockBids([0, 0, 0])
          ..finishWhistHand();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(board(over));
    await tester.pumpAndSettle();
    expect(over.isOver, isTrue);
    expect(find.text('New game'), findsOneWidget);
    expect(find.text('D'), findsNothing);
  });

  testWidgets('round popup: See scores hides it; bottom bar restores drafts', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField).at(0), 'Ana');
    await tester.enterText(find.byType(TextField).at(1), 'Ben');
    await scrollTo(tester, find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add round'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ana'), '10');
    await tester.tap(find.text('See scores'));
    await tester.pumpAndSettle();

    expect(find.text('Round 1 scores'), findsNothing);
    expect(find.text('Back to scores'), findsOneWidget);

    await tester.tap(find.text('Back to scores'));
    await tester.pumpAndSettle();
    expect(find.text('Round 1 scores'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Ana'))
          .controller!
          .text,
      '10',
    );
  });

  testWidgets('four players show a 1st/2nd/3rd podium after the first round', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Add player'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add player'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ana');
    await tester.enterText(fields.at(1), 'Ben');
    await tester.enterText(fields.at(2), 'Cara');
    await tester.enterText(fields.at(3), 'Dana');
    await scrollTo(tester, find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    // No scores yet: names as chips, no podium places.
    expect(find.text('1st'), findsNothing);
    expect(find.text('Ana'), findsWidgets);

    await tester.tap(find.text('Add round'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ana'), '10');
    await tester.enterText(find.widgetWithText(TextField, 'Ben'), '8');
    await tester.enterText(find.widgetWithText(TextField, 'Cara'), '6');
    await tester.enterText(find.widgetWithText(TextField, 'Dana'), '4');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('1st'), findsOneWidget);
    expect(find.text('2nd'), findsOneWidget);
    expect(find.text('3rd'), findsOneWidget);
    expect(find.text('10'), findsWidgets);
    expect(find.text('8'), findsWidgets);
    expect(find.text('6'), findsWidgets);
    expect(find.text('Add round'), findsOneWidget);
  });

  testWidgets('a saved game is restored on launch (legacy format migrates)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'skore.game':
          '{"players":["Ana","Ben"],"rounds":[[4,9]],"targetRounds":null,'
          '"endedManually":false}',
    });
    await pumpApp(tester);

    expect(find.text('Start game'), findsNothing);
    expect(find.text('Ana'), findsWidgets);
    expect(find.text('9'), findsWidgets);
  });
}
