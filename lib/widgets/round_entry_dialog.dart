import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asks for one score per player and pops with the list of scores (or null on
/// cancel). Empty fields count as 0; card games often go negative, so a
/// leading minus is allowed.
class RoundEntryDialog extends StatefulWidget {
  const RoundEntryDialog({
    super.key,
    required this.players,
    required this.roundNumber,
  });

  final List<String> players;
  final int roundNumber;

  @override
  State<RoundEntryDialog> createState() => _RoundEntryDialogState();
}

class _RoundEntryDialogState extends State<RoundEntryDialog> {
  late final List<TextEditingController> _scores = [
    for (final _ in widget.players) TextEditingController(),
  ];
  bool _showErrors = false;

  @override
  void dispose() {
    for (final controller in _scores) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _parse(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? 0 : int.tryParse(trimmed);
  }

  void _submit() {
    final parsed = [for (final controller in _scores) _parse(controller.text)];
    if (parsed.contains(null)) {
      setState(() => _showErrors = true);
      return;
    }
    Navigator.of(context).pop(parsed.cast<int>());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Round ${widget.roundNumber} scores'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.players.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _scores[i],
                  autofocus: i == 0,
                  keyboardType:
                      const TextInputType.numberWithOptions(signed: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                  ],
                  decoration: InputDecoration(
                    labelText: widget.players[i],
                    hintText: '0',
                    border: const OutlineInputBorder(),
                    errorText: _showErrors && _parse(_scores[i].text) == null
                        ? 'Enter a number'
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
