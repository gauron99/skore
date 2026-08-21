import 'package:flutter/material.dart';

import '../data/game.dart';

/// Paper-style score sheet: every round in play order, a double rule, then
/// the sums. Used on final standings and in history.
class PaperScoreSheet extends StatelessWidget {
  const PaperScoreSheet({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = game.totals;
    final winners = game.leaders.toSet();

    Widget cell(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Center(child: child),
    );

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(
        verticalInside: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        horizontalInside: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      children: [
        TableRow(
          children: [
            cell(Text('#', style: theme.textTheme.labelLarge)),
            for (var i = 0; i < game.players.length; i++)
              cell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (winners.contains(i)) ...[
                      const Icon(Icons.emoji_events, size: 16),
                      const SizedBox(width: 4),
                    ],
                    Text(game.players[i], style: theme.textTheme.labelLarge),
                  ],
                ),
              ),
          ],
        ),
        for (var r = 0; r < game.rounds.length; r++)
          TableRow(
            children: [
              cell(Text('R${game.roundNumber(r)}')),
              for (final score in game.rounds[r]) cell(Text('$score')),
            ],
          ),
        // Double line under the last round, like on a paper score sheet.
        TableRow(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.colorScheme.onSurface),
              bottom: BorderSide(color: theme.colorScheme.onSurface),
            ),
          ),
          children: [
            for (var i = 0; i <= game.players.length; i++)
              const SizedBox(height: 3),
          ],
        ),
        TableRow(
          children: [
            cell(Text('Σ', style: theme.textTheme.titleMedium)),
            for (var i = 0; i < game.players.length; i++)
              cell(
                Text(
                  '${totals[i]}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Teal result strip used above a finished sheet.
class WinnerBanner extends StatelessWidget {
  const WinnerBanner({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.emoji_events),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                game.resultHeadline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
