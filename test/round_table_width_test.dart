// The live round table at phone widths. Widths depend on real glyphs, so
// this file loads Roboto from the Flutter SDK instead of the test font
// (every glyph 1em wide). Kept apart from widget_test.dart: a loaded font
// stays loaded for every test in the file.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skore/data/game.dart';
import 'package:skore/screens/scoreboard_screen.dart';
import 'package:skore/widgets/pinned_first_row.dart';

Future<ByteData> _sdkFont(String file) async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) {
    throw StateError('FLUTTER_ROOT is not set; run these tests with flutter');
  }
  final path = '$root/bin/cache/artifacts/material_fonts/$file';
  return ByteData.view((await File(path).readAsBytes()).buffer);
}

/// Shows [players] on the scoreboard at [width]x800 after a few rounds
/// whose totals have three digits.
Future<void> pumpBoard(
  WidgetTester tester,
  double width,
  List<String> players,
) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final game = Game(players: players);
  for (final base in [120, 95, 210, 88]) {
    game.addRound([for (var i = 0; i < players.length; i++) base + i * 7]);
  }
  await tester.pumpWidget(
    MaterialApp(
      home: ScoreboardScreen(
        game: game,
        onRematch: () {},
        onChangeSetup: () {},
        onDiscard: () {},
        onShowHistory: () {},
        onPersist: () async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

RenderTable roundTable(WidgetTester tester) => tester.renderObject<RenderTable>(
  find.descendant(
    of: find.byType(PinnedFirstRow),
    matching: find.byType(Table),
  ),
);

/// How far the round table can scroll sideways.
double sidewaysScroll(WidgetTester tester) => tester
    .stateList<ScrollableState>(find.byType(Scrollable))
    .firstWhere((s) => s.position.axis == Axis.horizontal)
    .position
    .maxScrollExtent;

/// Column widths: a table lays every cell out at its column's width.
List<double> columnWidths(RenderTable table) => [
  for (var x = 0; x < table.columns; x++) table.column(x).first.size.width,
];

/// Every name and total is shown whole: none was squeezed narrower than its
/// own width, so none wraps or is cut off.
void expectWholeTexts(WidgetTester tester, Iterable<String> texts) {
  for (final text in texts) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text(text).last,
    );
    expect(
      paragraph.size.width,
      greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity)),
      reason: text,
    );
  }
}

void main() {
  setUpAll(() async {
    await (FontLoader('Roboto')
          ..addFont(_sdkFont('Roboto-Regular.ttf'))
          ..addFont(_sdkFont('Roboto-Medium.ttf'))
          ..addFont(_sdkFont('Roboto-Bold.ttf')))
        .load();
  });

  const eightLetters = ['Veronika', 'Michaela', 'Leonardo', 'Wolfgang'];

  testWidgets('four players with 8-letter names fill 360 and 420 wide', (
    tester,
  ) async {
    for (final width in [360.0, 420.0]) {
      await pumpBoard(tester, width, eightLetters);
      final table = roundTable(tester);

      expect(sidewaysScroll(tester), 0, reason: '$width');
      expect(table.size.width, moreOrLessEquals(width), reason: '$width');
      expect(table.localToGlobal(Offset.zero).dx, moreOrLessEquals(0));
      expectWholeTexts(tester, [...eightLetters, '513', '541', '569', '597']);

      // The # column stays narrow; the player columns share the rest.
      final widths = columnWidths(table);
      expect(widths.first, lessThan(50));
      for (final w in widths.skip(1)) {
        expect(w, moreOrLessEquals(widths[1]));
        expect(w, greaterThan(widths.first));
      }

      // Names and totals are centered over the same column.
      for (var i = 0; i < eightLetters.length; i++) {
        expect(
          tester.getCenter(find.text(eightLetters[i]).last).dx,
          moreOrLessEquals(
            tester.getCenter(find.text('${513 + i * 28}').last).dx,
            epsilon: 0.5,
          ),
        );
      }
    }
  });

  testWidgets('one long name: the table still ends at the screen edge', (
    tester,
  ) async {
    // The long column keeps its width and the short ones share what is
    // left, instead of each taking an even share and overflowing the screen.
    // (Table trims that overflow column by column, so the short ones can end
    // a few points apart; they are not asserted equal here.)
    const players = ['Mmmmmmmm', 'Ana', 'Ben', 'Eva'];
    await pumpBoard(tester, 360, players);
    final table = roundTable(tester);
    expect(sidewaysScroll(tester), 0);
    expect(table.size.width, moreOrLessEquals(360));
    expectWholeTexts(tester, players);
    final widths = columnWidths(table);
    for (var x = 2; x < widths.length; x++) {
      expect(widths[1], greaterThan(widths[x]));
      // Wider than its widest cell: it got a share of the spare width.
      expect(
        widths[x],
        greaterThan(
          const IntrinsicColumnWidth().maxIntrinsicWidth(
            table.column(x),
            double.infinity,
          ),
        ),
      );
    }
  });

  testWidgets('five players fit when they can, else scroll with whole names', (
    tester,
  ) async {
    const short = ['Ana', 'Ben', 'Cara', 'Dana', 'Eva'];
    await pumpBoard(tester, 360, short);
    expect(sidewaysScroll(tester), 0);
    expect(roundTable(tester).size.width, moreOrLessEquals(360));

    const long = [...eightLetters, 'Kristina'];
    await pumpBoard(tester, 420, long);
    expect(sidewaysScroll(tester), 0);
    expect(roundTable(tester).size.width, moreOrLessEquals(420));

    await pumpBoard(tester, 360, long);
    expect(sidewaysScroll(tester), greaterThan(0));
    expectWholeTexts(tester, long);
  });

  testWidgets('six players with long names scroll sideways', (tester) async {
    const players = [
      'Anastasia',
      'Benedikt',
      'Caroline',
      'Dominika',
      'Frantisek',
      'Gabriela',
    ];
    await pumpBoard(tester, 360, players);
    final table = roundTable(tester);
    expect(sidewaysScroll(tester), greaterThan(0));
    expect(table.size.width, greaterThan(360));
    expectWholeTexts(tester, players);
    // At its natural width: no column grew past its widest cell.
    expect(
      table.size.width,
      moreOrLessEquals(table.getMaxIntrinsicWidth(double.infinity)),
    );
  });
}
