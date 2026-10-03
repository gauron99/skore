import 'package:flutter/material.dart';

import '../data/game.dart';
import 'medals.dart';

/// Final places as in a race, above the paper sheet of a finished game: one
/// row per player, best first, with place, name and total. Places 1 to 3
/// wear their medal color, the winners (all of them on a tie) stand out, and
/// everyone else shows how far behind the winner they finished.
class FinalStandings extends StatelessWidget {
  const FinalStandings({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    if (game.rounds.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            game.resultHeadline,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }
    final totals = game.totals;
    final places = game.places;
    final behind = game.behindWinner;
    // Screen readers get the result as one sentence, then the rows.
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: game.resultHeadline,
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              for (final player in game.standings)
                _PlaceRow(
                  place: places[player],
                  name: game.players[player],
                  total: totals[player],
                  behind: behind[player],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.place,
    required this.name,
    required this.total,
    required this.behind,
  });

  final int place;
  final String name;
  final int total;
  final int behind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final winner = place == 1;
    final medal = Medal.forPlace(place);
    return MergeSemantics(
      child: Container(
        height: winner ? 48 : 40,
        // Tied winners would touch; keep their rounded rows apart.
        margin: EdgeInsets.symmetric(vertical: winner ? 1 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        // The leader color of the live cards.
        decoration: winner
            ? BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: medal ?? scheme.surfaceContainerHighest,
              child: Text(
                '$place',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: medal == null
                      ? scheme.onSurfaceVariant
                      : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: winner
                          ? theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            )
                          : theme.textTheme.bodyLarge,
                    ),
                  ),
                  if (winner) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.emoji_events, size: 20, color: scheme.primary),
                  ],
                ],
              ),
            ),
            if (!winner)
              Text(
                '$behind behind',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(width: 12),
            // Same-width digits and a common right edge line totals up.
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48),
              child: Text(
                '$total',
                textAlign: TextAlign.end,
                style:
                    (winner
                            ? theme.textTheme.titleLarge
                            : theme.textTheme.titleMedium)
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
