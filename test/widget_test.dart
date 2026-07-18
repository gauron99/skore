import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skore/main.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const SkoreApp());
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('setup → scoreboard → first round updates totals and saves',
      (tester) async {
    await pumpApp(tester);

    expect(find.text('Start game'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Ana');
    await tester.enterText(find.byType(TextField).at(1), 'Ben');
    await tester.ensureVisible(find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    expect(find.text('Add round'), findsOneWidget);
    await tester.tap(find.text('Add round'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Ana'), '10');
    await tester.enterText(find.widgetWithText(TextField, 'Ben'), '7');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Totals strip and history table both show the scores.
    expect(find.text('10'), findsWidgets);
    expect(find.text('7'), findsWidgets);

    // The mutation was persisted immediately.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('skore.data'), contains('[[10,7]]'));
  });

  testWidgets('fixed-length game auto-ends with final standings',
      (tester) async {
    await pumpApp(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ana');
    await tester.enterText(fields.at(1), 'Ben');
    await tester.enterText(fields.at(2), '1'); // round limit
    await tester.ensureVisible(find.text('Start game'));
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
    expect(find.text('Add round'), findsNothing);

    // The paper-style sheet: round rows and the sums under the double rule.
    expect(find.text('R1'), findsOneWidget);
    expect(find.text('Σ'), findsOneWidget);
    expect(find.text('5'), findsWidgets);
    expect(find.text('3'), findsWidgets);
  });

  testWidgets('finished games are archived, viewable, and deletable',
      (tester) async {
    await pumpApp(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ana');
    await tester.enterText(fields.at(1), 'Ben');
    await tester.enterText(fields.at(2), '1'); // round limit
    await tester.ensureVisible(find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add round'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ana'), '5');
    await tester.enterText(find.widgetWithText(TextField, 'Ben'), '3');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // "New game" archives instead of discarding.
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.text('Start game'), findsOneWidget);

    // The archived game shows up in Past games.
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.text('Ana 5 · Ben 3'), findsOneWidget);
    expect(find.textContaining('winner: Ana'), findsOneWidget);

    // Delete all data -> back on a fresh setup, nothing stored.
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.text('Start game'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('skore.data'), isNull);
  });

  testWidgets('lowest-points-wins game crowns the lowest total',
      (tester) async {
    await pumpApp(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ana');
    await tester.enterText(fields.at(1), 'Ben');
    await tester.enterText(fields.at(2), '1'); // round limit
    await tester.ensureVisible(find.text('Lowest points wins'));
    await tester.tap(find.text('Lowest points wins'));
    await tester.ensureVisible(find.text('Start game'));
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

  testWidgets('a saved game is restored on launch (legacy format migrates)',
      (tester) async {
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
