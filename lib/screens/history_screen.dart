import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../data/game.dart';

/// Archived games, newest first: date, totals, and the winner. Games can be
/// deleted one at a time, or everything at once (including any game in
/// progress) with "Delete all data".
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.data,
    required this.onPersist,
    required this.onDeleteAll,
  });

  final AppData data;
  final Future<void> Function() onPersist;
  final Future<void> Function() onDeleteAll;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _date(DateTime d) => '${d.year}'
      '-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

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

  Future<void> _deleteGame(int index) async {
    final confirmed = await _confirm('Delete this game from history?');
    if (!confirmed) return;
    setState(() => widget.data.history.removeAt(index));
    await widget.onPersist();
  }

  Future<void> _deleteAll() async {
    final confirmed = await _confirm(
        'Delete ALL data — every past game and any game in progress?');
    if (!confirmed) return;
    await widget.onDeleteAll();
    if (mounted) Navigator.of(context).pop();
  }

  void _showDetails(Game game) {
    final totals = game.totals;
    final winners = game.leaders.toSet();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${_date(game.startedAt)} · ${game.rounds.length} '
          'round${game.rounds.length == 1 ? '' : 's'}',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final i in game.standings)
              ListTile(
                dense: true,
                leading: winners.contains(i)
                    ? const Icon(Icons.emoji_events, size: 18)
                    : const SizedBox(width: 18),
                title: Text(game.players[i]),
                trailing: Text('${totals[i]}'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = widget.data.history;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Past games'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) => _deleteAll(),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'wipe', child: Text('Delete all data')),
            ],
          ),
        ],
      ),
      body: history.isEmpty
          ? const Center(child: Text('No finished games yet.'))
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, i) {
                // Newest first.
                final index = history.length - 1 - i;
                final game = history[index];
                final totals = game.totals;
                final winners = game.leaders;
                final summary = [
                  for (final s in game.standings)
                    '${game.players[s]} ${totals[s]}',
                ].join(' · ');
                final winnerText = winners.isEmpty
                    ? '—'
                    : winners.map((w) => game.players[w]).join(' & ');
                return ListTile(
                  title: Text(summary),
                  subtitle: Text(
                    '${_date(game.startedAt)} · ${game.rounds.length} '
                    'round${game.rounds.length == 1 ? '' : 's'} · '
                    'winner: $winnerText',
                  ),
                  onTap: () => _showDetails(game),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete game',
                    onPressed: () => _deleteGame(index),
                  ),
                );
              },
            ),
    );
  }
}
