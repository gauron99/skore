import 'package:flutter/material.dart';

import '../data/game.dart';
import 'medals.dart';

/// Live 1st / 2nd / 3rd as a small three-step stand for tables of 4+ players.
///
/// 2nd on the left, 1st tall in the middle, 3rd on the right. Place is
/// [Game.standings] (highest points, or lowest when [Game.lowestWins]).
class PodiumBoard extends StatelessWidget {
  const PodiumBoard({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final order = game.standings;
    final totals = game.totals;
    final first = order[0];
    final second = order[1];
    final third = order[2];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: _Step(
                  place: '2nd',
                  name: game.players[second],
                  total: totals[second],
                  color: Medal.silver,
                  standHeight: 64,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                flex: 4,
                child: _Step(
                  place: '1st',
                  name: game.players[first],
                  total: totals[first],
                  color: Medal.gold,
                  standHeight: 96,
                  crowned: true,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                flex: 3,
                child: _Step(
                  place: '3rd',
                  name: game.players[third],
                  total: totals[third],
                  color: Medal.bronze,
                  standHeight: 48,
                ),
              ),
            ],
          ),
          Container(
            height: 10,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFD8DCE0),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.place,
    required this.name,
    required this.total,
    required this.color,
    required this.standHeight,
    this.crowned = false,
  });

  final String place;
  final String name;
  final int total;
  final Color color;
  final double standHeight;
  final bool crowned;

  @override
  Widget build(BuildContext context) {
    final onStand = color.computeLuminance() > 0.5
        ? Colors.black54
        : Colors.white;
    final theme = Theme.of(context);
    return Semantics(
      label: '$place $name $total',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (crowned) ...[
            Icon(
              Icons.emoji_events,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 2),
          ],
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge,
          ),
          Text(
            '$total',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: standHeight,
            width: double.infinity,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Text(
              place,
              style: theme.textTheme.labelMedium?.copyWith(
                color: onStand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
