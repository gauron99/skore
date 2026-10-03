import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skore/data/app_data.dart';
import 'package:skore/data/game.dart';
import 'package:skore/main.dart';
import 'package:skore/screens/game_sheet_screen.dart';
import 'package:skore/screens/scoreboard_screen.dart';
import 'package:skore/screens/setup_screen.dart';
import 'package:skore/widgets/paper_score_sheet.dart';
import 'package:skore/widgets/whist_bid_dialog.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const SkoreApp());
  await tester.pumpAndSettle();
}

Widget scoreboardApp(
  Game game, {
  VoidCallback? onChangeSetup,
  VoidCallback? onShowHistory,
}) => MaterialApp(
  home: ScoreboardScreen(
    game: game,
    onRematch: () {},
    onChangeSetup: onChangeSetup ?? () {},
    onShowHistory: onShowHistory ?? () {},
    onPersist: () async {},
  ),
);

/// Menu item titles, top to bottom.
List<String> menuTitles(WidgetTester tester) => [
  for (final tile in tester.widgetList<ListTile>(
    find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(ListTile),
    ),
  ))
    (tile.title! as Text).data!,
];

final screenKey = GlobalKey();

/// [home] at phone size (420x800, 1 px per point), ready for [pixelsOf].
Future<void> pumpPhone(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(420, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: screenKey,
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
}

/// The RGBA bytes of [area] on screen, so two moments can be compared.
Future<Uint8List> pixelsOf(WidgetTester tester, Rect area) async {
  final screen = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(screenKey),
  );
  final bytes = (await tester.runAsync(() async {
    final image = await screen.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;
  final width = screen.size.width.round();
  final box = area.intersect(Offset.zero & screen.size);
  final left = box.left.round(), right = box.right.round();
  return Uint8List.fromList([
    for (var y = box.top.round(); y < box.bottom.round(); y++)
      ...bytes.sublist((y * width + left) * 4, (y * width + right) * 4),
  ]);
}

/// The same pixels as [expected], give or take anti-aliasing: a row at a
/// fractional position can differ by a level or two at its edges.
Matcher samePixels(Uint8List expected) => predicate<Uint8List>(
  (actual) =>
      actual.length == expected.length &&
      Iterable<int>.generate(
        actual.length,
      ).every((i) => (actual[i] - expected[i]).abs() <= 2),
  'the same pixels, give or take anti-aliasing',
);

/// Where the round table's names row is on screen right now.
Rect namesRow(WidgetTester tester) {
  final table = tester.renderObject<RenderTable>(find.byType(Table));
  return MatrixUtils.transformRect(
    table.getTransformTo(null),
    table.getRowBox(0),
  );
}

/// A game of [rounds] rounds with made-up scores.
Game longGame(List<String> players, int rounds, {int? targetRounds}) {
  final game = Game(players: players, targetRounds: targetRounds);
  for (var r = 0; r < rounds; r++) {
    game.addRound([
      for (var i = 0; i < players.length; i++) (r * 7 + i * 3) % 13,
    ]);
  }
  return game;
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

    // Back to setup archives the rematch too. The archived games show up in
    // Past games (setup's history icon) as score sheets.
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to setup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.text('Players'), findsOneWidget);
    await tester.tap(find.byTooltip('Past games'));
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

    // Delete all data -> back on a blank setup, nothing stored.
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.text('Players'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);

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

  testWidgets('running menu: Undo, End game, New game, Back to setup', (
    tester,
  ) async {
    await tester.pumpWidget(
      scoreboardApp(Game(players: ['Ana', 'Ben'])..addRound([1, 2])),
    );
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    expect(menuTitles(tester), [
      'Undo last round',
      'End game',
      'New game',
      'Back to setup',
    ]);
    expect(find.text('Show who won'), findsOneWidget);
    expect(find.text('Same players and rules'), findsOneWidget);
    expect(find.text('Change players or rules'), findsOneWidget);
    expect(find.text('Past games'), findsNothing);
  });

  testWidgets('game-over menu: Undo, Back to setup (no confirm), Past games', (
    tester,
  ) async {
    var backToSetup = 0;
    var pastGames = 0;
    await tester.pumpWidget(
      scoreboardApp(
        Game(players: ['Ana', 'Ben'], targetRounds: 1)..addRound([5, 3]),
        onChangeSetup: () => backToSetup++,
        onShowHistory: () => pastGames++,
      ),
    );
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(menuTitles(tester), [
      'Undo last round',
      'Back to setup',
      'Past games',
    ]);

    await tester.tap(find.text('Past games'));
    await tester.pumpAndSettle();
    expect(pastGames, 1);

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to setup'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(backToSetup, 1);
  });

  testWidgets('Undo after End game reopens the game with every round', (
    tester,
  ) async {
    final game = Game(players: ['Ana', 'Ben'])
      ..addRound([1, 2])
      ..addRound([3, 4]);
    await tester.pumpWidget(scoreboardApp(game));

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.text('Ben wins with 6 points!'), findsOneWidget);

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(menuTitles(tester).first, 'Undo');
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(game.isOver, isFalse);
    expect(game.rounds, hasLength(2));
    expect(find.text('Add round'), findsOneWidget);
    expect(find.text('R1'), findsOneWidget);
    expect(find.text('R2'), findsOneWidget);
  });

  testWidgets('Back to setup opens setup filled in from the archived game', (
    tester,
  ) async {
    String fieldText(int i) =>
        tester.widget<TextField>(find.byType(TextField).at(i)).controller!.text;
    bool switchOn(String title) => tester
        .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title))
        .value;

    await pumpApp(tester);
    await tester.tap(find.text('Add player'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ana');
    await tester.enterText(fields.at(1), 'Ben');
    await tester.enterText(fields.at(2), 'Cara');
    await tester.enterText(fields.at(3), '5'); // round limit
    await tester.enterText(fields.at(4), '50'); // score target
    await scrollTo(tester, find.text('Count rounds down'));
    await tester.tap(find.text('Count rounds down'));
    await scrollTo(tester, find.text('Lowest points wins'));
    await tester.tap(find.text('Lowest points wins'));
    await scrollTo(tester, find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to setup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    expect(find.text('Players'), findsOneWidget);
    expect(fieldText(0), 'Ana');
    expect(fieldText(1), 'Ben');
    expect(fieldText(2), 'Cara');
    expect(fieldText(3), '5');
    expect(fieldText(4), '50');
    expect(switchOn('Whist'), isFalse);
    expect(switchOn('Count rounds down'), isTrue);
    expect(switchOn('Lowest points wins'), isTrue);
  });

  testWidgets('setup fills in a Whist table from history, labels and all', (
    tester,
  ) async {
    String? labelOf(String name) => tester
        .widget<TextField>(find.widgetWithText(TextField, name))
        .decoration!
        .labelText;

    final last = Game(
      players: ['Ana', 'Ben', 'Cara'],
      whist: true,
      whistFirstDealer: 2,
    );
    SharedPreferences.setMockInitialValues({
      'skore.data': jsonEncode(AppData(history: [last]).toJson()),
    });
    await pumpApp(tester);

    expect(
      tester
          .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Whist'))
          .value,
      isTrue,
    );
    expect(labelOf('Ana'), 'Bids 1st');
    expect(labelOf('Ben'), 'Bids 2nd');
    expect(labelOf('Cara'), 'Deals · bids last');

    await tester.timedDrag(
      find.byIcon(Icons.drag_handle).at(0),
      const Offset(0, 200),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();
    expect(labelOf('Ben'), 'Bids 1st');
    expect(labelOf('Cara'), 'Bids 2nd');
    expect(labelOf('Ana'), 'Deals · bids last');
  });

  testWidgets('a heavier line splits Whist stacks in both round tables', (
    tester,
  ) async {
    /// Table rows whose top line is heavier than the 1px grid.
    List<int> heavyRows(Finder table) {
      double topWidth(TableRow row) =>
          ((row.decoration as BoxDecoration?)?.border as Border?)?.top.width ??
          0;
      final rows = tester.widget<Table>(table).children;
      return [
        for (var i = 0; i < rows.length; i++)
          if (topWidth(rows[i]) > 1) i,
      ];
    }

    final sheet = find.descendant(
      of: find.byType(PaperScoreSheet),
      matching: find.byType(Table),
    );
    Game whistAfter(int hands) {
      final game = Game(
        players: ['Ana', 'Ben', 'Cara'],
        whist: true,
        whistMaxHand: 2,
        whistCycles: 3,
      );
      for (var i = 0; i < hands; i++) {
        game.lockBids([0, 0, 0]);
        game.finishWhistHand();
      }
      return game;
    }

    Future<void> show(Game game) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(scoreboardApp(game));
      await tester.pumpAndSettle();
    }

    // Stacks of 2-then-1 hands: stacks 2 and 3 open at hands 3 and 5,
    // which are table rows 3 and 5 under the heading row.
    await show(whistAfter(5));
    expect(heavyRows(find.byType(Table)), [3, 5]);
    await show(whistAfter(6));
    expect(heavyRows(sheet), [3, 5]);

    // Not Whist: 9 rounds, past where an 8-card stack would end.
    final plain = Game(players: ['Ana', 'Ben']);
    for (var i = 0; i < 9; i++) {
      plain.addRound([1, 2]);
    }
    await show(plain);
    expect(heavyRows(find.byType(Table)), isEmpty);
    plain.endedManually = true;
    await show(plain);
    expect(heavyRows(sheet), isEmpty);
  });

  testWidgets('live round table keeps the names row on screen', (tester) async {
    await pumpPhone(
      tester,
      ScoreboardScreen(
        game: longGame(['Ana', 'Ben', 'Cara'], 30),
        onRematch: () {},
        onChangeSetup: () {},
        onShowHistory: () {},
        onPersist: () async {},
      ),
    );
    final names = namesRow(tester);
    final atRest = await pixelsOf(tester, names);

    await tester.dragFrom(
      names.center.translate(0, 200),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();

    // The real names row scrolled away; the pinned one shows it in place.
    expect(namesRow(tester).bottom, lessThan(names.top));
    expect(await pixelsOf(tester, names), samePixels(atRest));
  });

  testWidgets(
    'pinned names row stays over its columns when scrolled sideways',
    (tester) async {
      await pumpPhone(
        tester,
        ScoreboardScreen(
          game: longGame([
            'Anastasia',
            'Benedikt',
            'Caroline',
            'Dominika',
            'Eliska',
            'Frantisek',
          ], 30),
          onRematch: () {},
          onChangeSetup: () {},
          onShowHistory: () {},
          onPersist: () async {},
        ),
      );
      final names = namesRow(tester);
      expect(names.width, greaterThan(420)); // wider than the phone
      final start = Offset(210, names.bottom + 100);
      await tester.dragFrom(start, const Offset(-200, 0));
      await tester.pumpAndSettle();
      final sideways = namesRow(tester);
      expect(sideways.left, lessThan(names.left));
      final header = await pixelsOf(tester, sideways);

      await tester.dragFrom(start, const Offset(0, -400));
      await tester.pumpAndSettle();

      // Same columns, same pixels: the pinned row moved sideways with them.
      expect(namesRow(tester).left, sideways.left);
      expect(namesRow(tester).bottom, lessThan(sideways.top));
      expect(await pixelsOf(tester, sideways), samePixels(header));
    },
  );

  testWidgets('paper sheet keeps the names row on screen', (tester) async {
    final game = longGame(['Ana', 'Ben', 'Cara'], 30, targetRounds: 30);

    // Final standings: the sheet scrolls under the winner banner.
    await pumpPhone(
      tester,
      ScoreboardScreen(
        game: game,
        onRematch: () {},
        onChangeSetup: () {},
        onShowHistory: () {},
        onPersist: () async {},
      ),
    );
    var names = namesRow(tester);
    var atRest = await pixelsOf(tester, names);
    await tester.dragFrom(
      names.center.translate(0, 200),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(namesRow(tester).bottom, lessThan(names.top));
    expect(await pixelsOf(tester, names), samePixels(atRest));

    // Past games: banner and sheet scroll together, then the names row
    // stays at the top of the list. Compare it there with the real row
    // scrolled to exactly that spot, so both sit on the same pixels.
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpPhone(tester, GameSheetScreen(game: game, title: 'Past game'));
    final listTop = tester.getRect(find.byType(ListView)).top;
    final list = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    list.jumpTo(namesRow(tester).top - listTop);
    await tester.pump();
    names = namesRow(tester);
    expect(names.top, moreOrLessEquals(listTop));
    atRest = await pixelsOf(tester, names);
    list.jumpTo(list.pixels + 300);
    await tester.pump();
    expect(namesRow(tester).bottom, lessThan(listTop));
    expect(await pixelsOf(tester, names), samePixels(atRest));
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
