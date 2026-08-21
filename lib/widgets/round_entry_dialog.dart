import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asks for one score per player and pops with the list of scores, the typed
/// drafts if hidden to see the board, or null on cancel. Empty fields count
/// as 0; card games often go negative, so a leading minus is allowed.
class RoundEntryDialog extends StatefulWidget {
  const RoundEntryDialog({
    super.key,
    required this.players,
    required this.roundNumber,
    this.initialTexts,
  });

  final List<String> players;
  final int roundNumber;

  /// Field text, restored after hiding the popup to see scores.
  final List<String>? initialTexts;

  @override
  State<RoundEntryDialog> createState() => _RoundEntryDialogState();
}

class _RoundEntryDialogState extends State<RoundEntryDialog> {
  late final List<TextEditingController> _scores = [
    for (var i = 0; i < widget.players.length; i++)
      TextEditingController(text: _initialText(i)),
  ];

  String _initialText(int i) {
    final texts = widget.initialTexts;
    if (texts == null || i >= texts.length) return '';
    return texts[i];
  }

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

  void _seeScores() {
    Navigator.of(
      context,
    ).pop([for (final controller in _scores) controller.text]);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _seeScores();
      },
      child: AlertDialog(
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
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
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
          TextButton.icon(
            onPressed: _seeScores,
            icon: const Icon(Icons.expand_more),
            label: const Text('See scores'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: _submit, child: const Text('OK')),
        ],
      ),
    );
  }
}
