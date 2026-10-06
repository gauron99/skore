import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../data/game.dart';
import '../data/win_summary.dart';
import 'game_sheet_screen.dart';
import 'same_names_screen.dart';

/// Archived games, newest first, with a win summary of the games left
/// checked. Games can be deleted one at a time, or everything at once
/// (including any game in progress) with "Delete all data".
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
  /// Games left out of the summary. Absent means included.
  final Set<Game> _excluded = {};

  String _date(DateTime d) =>
      '${d.year}'
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
      'Delete ALL data — every past game and any game in progress?',
    );
    if (!confirmed) return;
    await widget.onDeleteAll();
    if (mounted) Navigator.of(context).pop();
  }

  void _showDetails(Game game) {
    final rounds = game.rounds.length;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameSheetScreen(
          game: game,
          title:
              '${_date(game.startedAt)} · $rounds '
              'round${rounds == 1 ? '' : 's'}',
        ),
      ),
    );
  }

  Future<void> _editNames({String person = ''}) async {
    final games = [
      if (widget.data.current != null) widget.data.current!,
      ...widget.data.history,
    ];
    final display = person.isEmpty
        ? ''
        : personRoot(person, widget.data.samePerson);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PersonNameScreen(
          names: knownNames(games, const {}),
          counts: spellingCounts(games),
          display: display,
          samePerson: widget.data.samePerson,
          displayNames: widget.data.displayNames,
          onChanged: widget.onPersist,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// Labels saved with Add name that no spelling points at yet.
  List<String> _pendingNames(Iterable<Game> games) {
    final shown = shownNames(
      knownNames(games, const {}),
      widget.data.samePerson,
    ).toSet();
    final out = <String>[];
    final seen = <String>{};
    for (final raw in widget.data.displayNames) {
      final name = raw.trim();
      if (name.isEmpty || !seen.add(name) || shown.contains(name)) continue;
      out.add(name);
    }
    return out;
  }

  void _toggle(Game game) {
    setState(() {
      if (!_excluded.remove(game)) _excluded.add(game);
    });
  }

  Widget _wins(List<Game> history) {
    final selected = [
      for (final game in history)
        if (!_excluded.contains(game)) game,
    ];
    final rows = winSummary(selected, widget.data.samePerson);
    final pending = _pendingNames([
      if (widget.data.current != null) widget.data.current!,
      ...history,
    ]);
    final theme = Theme.of(context);
    final String count;
    if (selected.isEmpty) {
      count = 'No games selected.';
    } else if (selected.length == history.length) {
      final games = history.length == 1 ? 'game' : 'games';
      count = '${history.length} $games';
    } else {
      count = '${selected.length} of ${history.length} games';
    }
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Wins', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text(count, style: muted),
              ],
            ),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (var i = 0; i < rows.length; i++) _winRow(rows[i], i + 1),
            ],
            for (final name in pending) _pendingRow(name),
            if (selected.length != history.length)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(_excluded.clear),
                  child: const Text('Use all games'),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _editNames,
              icon: const Icon(Icons.add),
              label: const Text('Add name'),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap a name to join spellings. Uncheck a game to leave it out. '
              'A tie counts for each winner.',
              style: muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingRow(String name) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return InkWell(
      onTap: () => _editNames(person: name),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, overflow: TextOverflow.ellipsis),
            Text('No spellings yet', style: muted),
          ],
        ),
      ),
    );
  }

  Widget _winRow(WinSummary row, int place) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final share = row.played == 0 ? 0.0 : row.wins / row.played;
    return InkWell(
      onTap: () => _editNames(person: row.name),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '$place',
                    style: muted,
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.name, overflow: TextOverflow.ellipsis),
                      if (row.also.isNotEmpty)
                        Text(
                          row.also.join(', '),
                          overflow: TextOverflow.ellipsis,
                          style: muted,
                        ),
                    ],
                  ),
                ),
                Text('${row.wins} of ${row.played}'),
                const SizedBox(width: 12),
                SizedBox(
                  width: 48,
                  child: Text('${row.winPercent}%', textAlign: TextAlign.end),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: share,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          ],
        ),
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
          ? const Center(child: Text('No past games yet.'))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _wins(history)),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, i) {
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
                      leading: Checkbox(
                        value: !_excluded.contains(game),
                        onChanged: (_) => _toggle(game),
                      ),
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
                  }, childCount: history.length),
                ),
                SliverPadding(
                  padding: EdgeInsets.only(
                    bottom: 8 + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                ),
              ],
            ),
    );
  }
}
