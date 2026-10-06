import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/game.dart';

/// Collects player names and the optional round limit, then starts the game.
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.onStart,
    required this.onShowHistory,
    this.lastGame,
  });

  final ValueChanged<Game> onStart;
  final VoidCallback onShowHistory;

  /// Newest archived game, if any. The form starts filled in from it: the
  /// same players in the same order, and the same rules.
  final Game? lastGame;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final List<TextEditingController> _names = [];
  final TextEditingController _roundLimit = TextEditingController();
  final TextEditingController _scoreTarget = TextEditingController();
  bool _countDown = false;
  bool _lowestWins = false;
  bool _whist = false;

  @override
  void initState() {
    super.initState();
    final last = widget.lastGame;
    for (final name in last?.players ?? const ['', '']) {
      _names.add(_nameField(name));
    }
    if (last != null) {
      _whist = last.whist;
      _roundLimit.text = last.targetRounds?.toString() ?? '';
      _scoreTarget.text = last.targetScore?.toString() ?? '';
      _countDown = last.countDown;
      _lowestWins = last.lowestWins;
    }
    // Older saves may hold fewer players than setup now allows.
    _fillSeats();
    // The countdown switch only applies to fixed-length games; re-render as
    // the round limit is typed so its enabled state tracks the field.
    _roundLimit.addListener(() {
      setState(() {
        if (_roundLimit.text.trim().isEmpty) _countDown = false;
      });
    });
  }

  @override
  void dispose() {
    for (final controller in _names) {
      controller.dispose();
    }
    _roundLimit.dispose();
    _scoreTarget.dispose();
    super.dispose();
  }

  TextEditingController _nameField([String text = '']) =>
      TextEditingController(text: text)..addListener(() => setState(() {}));

  void _addPlayer() {
    setState(() => _names.add(_nameField()));
  }

  void _removePlayer(int index) {
    setState(() => _names.removeAt(index).dispose());
  }

  void _movePlayer(int from, int to) {
    setState(() => _names.insert(to, _names.removeAt(from)));
  }

  /// Whist needs three hands at the table; other games need two.
  int get _minPlayers => _whist ? 3 : 2;

  /// Rows whose name (trimmed, any case) already appears in an earlier row.
  Set<int> get _duplicateRows {
    final seen = <String>{};
    final duplicates = <int>{};
    for (var i = 0; i < _names.length; i++) {
      final name = _names[i].text.trim().toLowerCase();
      if (name.isNotEmpty && !seen.add(name)) duplicates.add(i);
    }
    return duplicates;
  }

  bool get _namesReady =>
      _names.every((c) => c.text.trim().isNotEmpty) && _duplicateRows.isEmpty;

  /// Whist row label. Top to bottom is the first hand's bid order; the last
  /// row deals first.
  String _seatLabel(int index) {
    if (index == _names.length - 1) return 'Deals · bids last';
    final n = index + 1;
    final suffix = n % 100 >= 11 && n % 100 <= 13
        ? 'th'
        : switch (n % 10) {
            1 => 'st',
            2 => 'nd',
            3 => 'rd',
            _ => 'th',
          };
    return 'Bids $n$suffix';
  }

  void _start() {
    if (!_namesReady) return;
    final players = [for (final c in _names) c.text.trim()];
    final limitText = _roundLimit.text.trim();
    final limit = limitText.isEmpty ? null : int.parse(limitText);
    if (limit != null && limit < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Round limit must be at least 1.')),
      );
      return;
    }
    final scoreText = _scoreTarget.text.trim();
    final scoreTarget = scoreText.isEmpty ? null : int.parse(scoreText);
    if (scoreTarget != null && scoreTarget < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Score target must be at least 1.')),
      );
      return;
    }
    if (_whist) {
      widget.onStart(
        Game(
          players: players,
          whist: true,
          whistMaxHand: 8,
          whistCycles: players.length,
          whistFirstDealer: players.length - 1,
        ),
      );
      return;
    }
    widget.onStart(
      Game(
        players: players,
        targetRounds: limit,
        targetScore: scoreTarget,
        countDown: limit != null && _countDown,
        lowestWins: _lowestWins,
      ),
    );
  }

  void _setWhist(bool value) {
    setState(() {
      _whist = value;
      _fillSeats();
    });
  }

  /// Adds empty rows up to the minimum for the game type.
  void _fillSeats() {
    while (_names.length < _minPlayers) {
      _names.add(_nameField());
    }
  }

  @override
  Widget build(BuildContext context) {
    final duplicates = _duplicateRows;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skóre — new game'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Past games',
            onPressed: widget.onShowHistory,
          ),
        ],
      ),
      body: ReorderableListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        buildDefaultDragHandles: false,
        // Done typing once a row moves. A focused field would also carry its
        // selection handles into the drag overlay.
        onReorderStart: (_) => FocusScope.of(context).unfocus(),
        onReorderItem: _movePlayer,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Players',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_whist) ...[
              const SizedBox(height: 4),
              Text(
                'Seating order. The last player deals first, then the deal '
                'moves to the next player each stack, wrapping to the top.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addPlayer,
                icon: const Icon(Icons.person_add),
                label: const Text('Add player'),
              ),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              value: _whist,
              onChanged: _setWhist,
              title: const Text('Whist'),
              subtitle: const Text(
                'Guess tricks, then tap who hit. Exact guess is '
                'guess+10, else 0. Totals must not equal the hand. '
                'Hands 8 down to 1, once per player.',
              ),
              contentPadding: EdgeInsets.zero,
            ),
            if (!_whist) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _roundLimit,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Number of rounds (optional)',
                  helperText: 'Leave empty to play until you end the game.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _roundLimit.text.trim().isNotEmpty && _countDown,
                onChanged: _roundLimit.text.trim().isNotEmpty
                    ? (value) => setState(() => _countDown = value)
                    : null,
                title: const Text('Count rounds down'),
                subtitle: const Text(
                  'First round is the highest number (R8, R7, …).',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _scoreTarget,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Play until X points (optional)',
                  helperText:
                      'The game ends once a player reaches this total — who '
                      'wins is still decided by the scoring direction.',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _lowestWins,
                onChanged: (value) => setState(() => _lowestWins = value),
                title: const Text('Lowest points wins'),
                subtitle: const Text(
                  'Crown the fewest points instead of the most (Hearts-style).',
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _namesReady ? _start : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start game'),
            ),
          ],
        ),
        children: [
          for (var i = 0; i < _names.length; i++)
            _playerRow(i, duplicates.contains(i)),
        ],
      ),
    );
  }

  Widget _playerRow(int index, bool duplicate) {
    // Icons sit level with the 56px field even when an error line shows.
    return Padding(
      key: ObjectKey(_names[index]),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 8, 16),
              child: Icon(Icons.drag_handle),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _names[index],
              decoration: InputDecoration(
                labelText: _whist ? _seatLabel(index) : 'Player ${index + 1}',
                errorText: duplicate ? 'Name already used' : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: IconButton(
              onPressed: _names.length > _minPlayers
                  ? () => _removePlayer(index)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'Remove player',
            ),
          ),
        ],
      ),
    );
  }
}
