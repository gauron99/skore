import 'package:flutter/material.dart';

import '../data/game.dart';
import 'pinned_first_row.dart';

/// Paper-style score sheet: every round in play order, a double rule, then
/// the sums. Used on final standings and in history. The names row stays
/// in view while a long sheet scrolls.
class PaperScoreSheet extends StatelessWidget {
  const PaperScoreSheet({super.key, required this.game, this.onEditRound});

  final Game game;

  /// When set, a tap on a score opens that round for editing.
  final Future<void> Function(int roundIndex)? onEditRound;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = game.totals;
    final winners = game.leaders.toSet();

    Widget cell(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Center(child: child),
    );

    Widget scoreCell(int round, int score) {
      final text = cell(Text('$score'));
      final edit = onEditRound;
      if (edit == null) return text;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => edit(round),
        child: text,
      );
    }

    // Between Whist stacks: heavier than the grid, lighter than the double
    // rule above the sums.
    final stackLine = BoxDecoration(
      border: Border(
        top: BorderSide(color: theme.colorScheme.outline, width: 2),
      ),
    );

    return PinnedFirstRow(
      table: Table(
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
              decoration: game.startsWhistStack(r) ? stackLine : null,
              children: [
                cell(Text('R${game.roundNumber(r)}')),
                for (final score in game.rounds[r]) scoreCell(r, score),
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
      ),
    );
  }
}
