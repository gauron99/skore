import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/game.dart';

/// Collects player names and the optional round limit, then starts the game.
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.onStart,
    required this.onShowHistory,
  });

  final ValueChanged<Game> onStart;
  final VoidCallback onShowHistory;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final List<TextEditingController> _names = [
    TextEditingController(),
    TextEditingController(),
  ];
  final TextEditingController _roundLimit = TextEditingController();
  final TextEditingController _scoreTarget = TextEditingController();
  bool _countDown = false;
  bool _lowestWins = false;
  bool _whist = false;

  @override
  void initState() {
    super.initState();
    // The countdown switch only applies to fixed-length games; re-render as
    // the round limit is typed so its enabled state tracks the field.
    _roundLimit.addListener(() => setState(() {}));
    for (final controller in _names) {
      controller.addListener(() => setState(() {}));
    }
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

  void _addPlayer() {
    final controller = TextEditingController();
    controller.addListener(() => setState(() {}));
    setState(() => _names.add(controller));
  }

  void _removePlayer(int index) {
    setState(() => _names.removeAt(index).dispose());
  }

  bool get _namesReady => _names.every((c) => c.text.trim().isNotEmpty);

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
      if (value) {
        while (_names.length < 3) {
          final controller = TextEditingController();
          controller.addListener(() => setState(() {}));
          _names.add(controller);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          Text(
            'Players',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _names.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _names[i],
                      decoration: InputDecoration(
                        labelText: 'Player ${i + 1}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _names.length > 2
                        ? () => _removePlayer(i)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Remove player',
                  ),
                ],
              ),
            ),
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
    );
  }
}
