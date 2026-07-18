import 'package:flutter/material.dart';

import '../data/game.dart';
import '../data/game_store.dart';
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
  });

  final Game game;
  final VoidCallback onNewGame;

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
        roundNumber: game.rounds.length + 1,
      ),
    );
    if (scores == null) return;
    setState(() => game.addRound(scores));
    await GameStore.save(game);
  }

  Future<void> _undoLastRound() async {
    setState(() => game.undoLastRound());
    await GameStore.save(game);
  }

  Future<void> _endGame() async {
    final confirmed = await _confirm('End this game and show final standings?');
    if (!confirmed) return;
    setState(() => game.endedManually = true);
    await GameStore.save(game);
  }

  Future<void> _newGame() async {
    final confirmed = await _confirm('Discard this game and start a new one?');
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
    if (game.isOver) {
      return 'Final standings · $played round$plural played';
    }
    if (target != null) {
      return 'Round ${played + 1} of $target';
    }
    return played == 0 ? 'No rounds played yet' : '$played round$plural played';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skóre'),
        actions: [
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
    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        scrollDirection: Axis.horizontal,
        itemCount: game.players.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final isLeader = leaders.contains(i);
          return Card(
            color: isLeader
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLeader) ...[
                        const Icon(Icons.emoji_events, size: 16),
                        const SizedBox(width: 4),
                      ],
                      Text(game.players[i],
                          style: Theme.of(context).textTheme.labelLarge),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${totals[i]}',
                      style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _historyTable(BuildContext context) {
    if (game.rounds.isEmpty) {
      return const Center(
        child: Text('Add the first round with the button below.'),
      );
    }
    // Newest round first, so the latest scores are visible without scrolling.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: [
            const DataColumn(label: Text('#')),
            for (final name in game.players) DataColumn(label: Text(name)),
          ],
          rows: [
            for (var r = game.rounds.length - 1; r >= 0; r--)
              DataRow(
                cells: [
                  DataCell(Text('R${r + 1}')),
                  for (final score in game.rounds[r]) DataCell(Text('$score')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _finalStandings(BuildContext context) {
    final totals = game.totals;
    final standings = game.standings;
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
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: standings.length,
            itemBuilder: (context, position) {
              final playerIndex = standings[position];
              final isWinner = winners.contains(playerIndex);
              return ListTile(
                leading: CircleAvatar(child: Text('${position + 1}')),
                title: Text(game.players[playerIndex]),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isWinner) ...[
                      const Icon(Icons.emoji_events, size: 18),
                      const SizedBox(width: 6),
                    ],
                    Text('${totals[playerIndex]}',
                        style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              );
            },
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
}
