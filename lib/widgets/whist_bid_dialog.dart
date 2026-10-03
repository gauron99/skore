import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/game.dart';

/// Lock in trick guesses for a Whist hand. Empty is 0. Bids must be
/// 0..[handCards], and must not add up to [handCards] (dealer bids last).
class WhistBidDialog extends StatefulWidget {
  const WhistBidDialog({
    super.key,
    required this.players,
    required this.handCards,
    required this.bidOrder,
    this.initialTexts,
  });

  final List<String> players;
  final int handCards;

  /// Seating indices in bid order, dealer last ([Game.whistBidOrder]).
  final List<int> bidOrder;

  /// Field text in bid order, restored after hiding the popup to see scores.
  final List<String>? initialTexts;

  @override
  State<WhistBidDialog> createState() => _WhistBidDialogState();
}

class _MaxHandFormatter extends TextInputFormatter {
  const _MaxHandFormatter(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final n = int.tryParse(newValue.text);
    if (n == null || n > max) return oldValue;
    return newValue;
  }
}

class _WhistBidDialogState extends State<WhistBidDialog> {
  List<int> get _order => widget.bidOrder;

  late final List<TextEditingController> _bids = [
    for (var i = 0; i < _order.length; i++)
      TextEditingController(text: _initialText(i)),
  ];

  String _initialText(int i) {
    final texts = widget.initialTexts;
    if (texts == null || i >= texts.length) return '';
    return texts[i];
  }

  String? _error;

  @override
  void initState() {
    super.initState();
    for (final controller in _bids) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final controller in _bids) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _parse(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? 0 : int.tryParse(trimmed);
  }

  List<int?> get _parsed => [
    for (final controller in _bids) _parse(controller.text),
  ];

  /// Seating-order bids, or null if any field is not a number.
  List<int>? get _seatingBids {
    final parsed = _parsed;
    if (parsed.contains(null)) return null;
    final seating = List<int>.filled(widget.players.length, 0);
    for (var i = 0; i < _order.length; i++) {
      seating[_order[i]] = parsed[i]!;
    }
    return seating;
  }

  /// Number the last player must not bid, or null if every 0..handCards is ok
  /// (the others already guessed more than the hand).
  int? get _forbiddenDealerBid {
    if (_parsed.length < 2) return null;
    final earlier = _parsed.sublist(0, _parsed.length - 1);
    if (earlier.contains(null)) return null;
    final forbidden =
        widget.handCards - earlier.fold<int>(0, (sum, b) => sum + b!);
    if (forbidden < 0 || forbidden > widget.handCards) return null;
    return forbidden;
  }

  bool get _lastTypedForbidden {
    final forbidden = _forbiddenDealerBid;
    if (forbidden == null || _parsed.isEmpty) return false;
    return _parsed.last == forbidden;
  }

  void _submit() {
    final seating = _seatingBids;
    if (seating == null) {
      setState(() => _error = 'Enter a whole number for every player.');
      return;
    }
    final max = widget.handCards;
    for (final bid in seating) {
      if (bid < 0 || bid > max) {
        setState(() => _error = 'Each guess must be 0 to $max.');
        return;
      }
    }
    if (!Game.whistBidTotalAllowed(seating, max)) {
      setState(
        () => _error = 'Guesses cannot add up to $max, or everyone could hit.',
      );
      return;
    }
    Navigator.of(context).pop(seating);
  }

  void _seeScores() {
    Navigator.of(
      context,
    ).pop([for (final controller in _bids) controller.text]);
  }

  @override
  Widget build(BuildContext context) {
    final dealerName = widget.players[_order.last];
    final forbidden = _forbiddenDealerBid;
    final max = widget.handCards;
    final errorColor = Theme.of(context).colorScheme.error;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _seeScores();
      },
      child: AlertDialog(
        title: Text('$max-card hand'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$dealerName deals and guesses last. Each guess is 0 to $max. '
                'Total guesses must not equal $max.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _order.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Builder(
                    builder: (context) {
                      final last = i == _order.length - 1;
                      final lastBad = last && _lastTypedForbidden;
                      final helper = last
                          ? (forbidden == null
                                ? 'You can guess any number 0 to $max'
                                : 'Cannot guess $forbidden')
                          : '0 to $max';
                      final red = last && forbidden != null;
                      final redSide = BorderSide(color: errorColor, width: 2);
                      return TextField(
                        controller: _bids[i],
                        autofocus: i == 0,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _MaxHandFormatter(max),
                        ],
                        decoration: InputDecoration(
                          labelText: last
                              ? '${widget.players[_order[i]]} (last)'
                              : widget.players[_order[i]],
                          hintText: '0',
                          helperText: helper,
                          helperStyle: TextStyle(
                            color: red ? errorColor : null,
                            fontWeight: lastBad ? FontWeight.w700 : null,
                          ),
                          border: const OutlineInputBorder(),
                          enabledBorder: lastBad
                              ? OutlineInputBorder(borderSide: redSide)
                              : null,
                          focusedBorder: lastBad
                              ? OutlineInputBorder(borderSide: redSide)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              if (_error != null)
                Text(_error!, style: TextStyle(color: errorColor)),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _seeScores,
            icon: const Icon(Icons.expand_more),
            label: const Text('See scores'),
          ),
          FilledButton(onPressed: _submit, child: const Text('Lock guesses')),
        ],
      ),
    );
  }
}
