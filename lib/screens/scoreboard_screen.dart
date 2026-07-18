import 'package:flutter/material.dart';

import '../data/game.dart';
import '../widgets/round_entry_dialog.dart';

enum _MenuAction { undo, endGame, newGame }

/// The live game view: running totals with the leader crowned, the round
/// history table, and round entry. Flips to final standings once the game
/// is over.
class ScoreboardScreen extends StatefulWidget {
  const ScoreboardScreen({
    super.key,
    required this.game,
    required this.onNewGame,
    required this.onShowHistory,
    required this.onPersist,
  });

  final Game game;
  final VoidCallback onNewGame;
  final VoidCallback onShowHistory;

  /// Called after every mutation of [game] so the owner can save it.
  final Future<void> Function() onPersist;

  @override
  State<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends State<ScoreboardScreen> {
  Game get game => widget.game;

  Future<void> _addRound() async {
    final scores = await showDialog<List<int>>(
      context: context,
      builder: (context) => RoundEntryDialog(
        players: game.players,
        roundNumber: game.nextRoundNumber,
      ),
    );
    if (scores == null) return;
    setState(() => game.addRound(scores));
    await widget.onPersist();
  }

  Future<void> _undoLastRound() async {
    setState(() => game.undoLastRound());
    await widget.onPersist();
  }

  Future<void> _endGame() async {
    final confirmed = await _confirm('End this game and show final standings?');
    if (!confirmed) return;
    setState(() => game.endedManually = true);
    await widget.onPersist();
  }

  Future<void> _newGame() async {
    final confirmed =
        await _confirm('Archive this game and start a new one?');
    if (!confirmed) return;
    widget.onNewGame();
  }

  Future<bool> _confirm(String message) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  String get _progressLabel {
    final played = game.rounds.length;
    final target = game.targetRounds;
    final plural = played == 1 ? '' : 's';
    final scoreSuffix =
        game.targetScore == null ? '' : ' · playing to ${game.targetScore}';
    if (game.isOver) {
      return 'Final standings · $played round$plural played';
    }
    if (target != null) {
      return 'Round ${game.nextRoundNumber} of $target$scoreSuffix';
    }
    final base =
        played == 0 ? 'No rounds played yet' : '$played round$plural played';
    return '$base$scoreSuffix';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skóre'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Past games',
            onPressed: widget.onShowHistory,
          ),
          PopupMenuButton<_MenuAction>(
            onSelected: (action) {
              switch (action) {
                case _MenuAction.undo:
                  _undoLastRound();
                case _MenuAction.endGame:
                  _endGame();
                case _MenuAction.newGame:
                  _newGame();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _MenuAction.undo,
                enabled: game.rounds.isNotEmpty,
                child: const Text('Undo last round'),
              ),
              if (game.targetRounds == null && !game.isOver)
                const PopupMenuItem(
                  value: _MenuAction.endGame,
                  child: Text('End game'),
                ),
              const PopupMenuItem(
                value: _MenuAction.newGame,
                child: Text('New game'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: game.isOver
          ? null
          : FloatingActionButton.extended(
              onPressed: _addRound,
              icon: const Icon(Icons.add),
              label: const Text('Add round'),
            ),
      body: game.isOver ? _finalStandings(context) : _runningGame(context),
    );
  }

  Widget _runningGame(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(_progressLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        _totalsStrip(context),
        const Divider(height: 1),
        Expanded(child: _historyTable(context)),
      ],
    );
  }

  Widget _totalsStrip(BuildContext context) {
    final totals = game.totals;
    final leaders = game.leaders.toSet();
    // Intrinsic height (no fixed size) so the cards grow with the text
    // scale; centered when they fit, horizontally scrollable when not.
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            for (var i = 0; i < game.players.length; i++)
              _playerCard(context, i, totals[i], leaders.contains(i)),
          ],
        ),
      ),
    );
  }

  Widget _playerCard(
      BuildContext context, int index, int total, bool isLeader) {
    return Card(
      color: isLeader ? Theme.of(context).colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLeader) ...[
                  const Icon(Icons.emoji_events, size: 16),
                  const SizedBox(width: 4),
                ],
                Text(game.players[index],
                    style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 4),
            Text('$total', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }

  Widget _historyTable(BuildContext context) {
    if (game.rounds.isEmpty) {
      return const Center(
        child: Text('Add the first round with the button below.'),
      );
    }
    final theme = Theme.of(context);
    // Very light grid: faint verticals between players; DataTable draws the
    // faint horizontals between rounds itself, from the theme dividerColor.
    final gridColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.6);
    // Rounds in play order, first round on top — R1, R2, … normally, or
    // R8, R7, … when counting down (labels come from roundNumber either way).
    // topCenter keeps the table horizontally centered when it fits on screen.
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: Theme(
            data: theme.copyWith(dividerColor: gridColor),
            child: DataTable(
              border: TableBorder(
                verticalInside: BorderSide(width: 1, color: gridColor),
              ),
              columns: [
                const DataColumn(label: Text('#')),
                for (final name in game.players)
                  DataColumn(
                    headingRowAlignment: MainAxisAlignment.center,
                    label: Text(name),
                  ),
              ],
              rows: [
                for (var r = 0; r < game.rounds.length; r++)
                  DataRow(
                    cells: [
                      DataCell(Text('R${game.roundNumber(r)}')),
                      for (final score in game.rounds[r])
                        DataCell(Center(child: Text('$score'))),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _finalStandings(BuildContext context) {
    final totals = game.totals;
    final winners = game.leaders;
    final winnerNames = winners.map((i) => game.players[i]).join(' & ');
    final String headline;
    if (winners.isEmpty) {
      headline = 'Game over — no rounds were played.';
    } else if (winners.length == 1) {
      headline = '$winnerNames wins with ${totals[winners.first]} points!';
    } else {
      headline =
          'Tie! $winnerNames share the win with ${totals[winners.first]} points.';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(_progressLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        Card(
          margin: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.emoji_events),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(headline,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _paperSheet(context),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _newGame,
              icon: const Icon(Icons.replay),
              label: const Text('New game'),
            ),
          ),
        ),
      ],
    );
  }

  /// The finished score sheet, paper style: every round in play order, a
  /// double rule, then the final sums.
  Widget _paperSheet(BuildContext context) {
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
              cell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (winners.contains(i)) ...[
                    const Icon(Icons.emoji_events, size: 16),
                    const SizedBox(width: 4),
                  ],
                  Text(game.players[i], style: theme.textTheme.labelLarge),
                ],
              )),
          ],
        ),
        for (var r = 0; r < game.rounds.length; r++)
          TableRow(
            children: [
              cell(Text('R${game.roundNumber(r)}')),
              for (final score in game.rounds[r]) cell(Text('$score')),
            ],
          ),
        // The double line under the last round, like on a paper score sheet:
        // a short row whose top and bottom borders form the two strokes.
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
              cell(Text(
                '${totals[i]}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              )),
          ],
        ),
      ],
    );
  }
}
