import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/game.dart';

/// Collects player names and the optional round limit, then starts the game.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.onStart});

  final ValueChanged<Game> onStart;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final List<TextEditingController> _names = [
    TextEditingController(),
    TextEditingController(),
  ];
  final TextEditingController _roundLimit = TextEditingController();

  @override
  void dispose() {
    for (final controller in _names) {
      controller.dispose();
    }
    _roundLimit.dispose();
    super.dispose();
  }

  void _addPlayer() {
    setState(() => _names.add(TextEditingController()));
  }

  void _removePlayer(int index) {
    setState(() => _names.removeAt(index).dispose());
  }

  void _start() {
    final players = [
      for (var i = 0; i < _names.length; i++)
        _names[i].text.trim().isEmpty
            ? 'Player ${i + 1}'
            : _names[i].text.trim(),
    ];
    final limitText = _roundLimit.text.trim();
    final limit = limitText.isEmpty ? null : int.parse(limitText);
    if (limit != null && limit < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Round limit must be at least 1.')),
      );
      return;
    }
    widget.onStart(Game(players: players, targetRounds: limit));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skóre — new game')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Players', style: Theme.of(context).textTheme.titleMedium),
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
                    onPressed: _names.length > 2 ? () => _removePlayer(i) : null,
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
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start game'),
          ),
        ],
      ),
    );
  }
}
