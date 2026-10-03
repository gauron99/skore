import 'package:flutter/material.dart';

import '../data/game.dart';
import '../widgets/paper_score_sheet.dart';
import '../widgets/pinned_first_row.dart';
import '../widgets/podium_board.dart';
import '../widgets/round_entry_dialog.dart';
import '../widgets/whist_bid_dialog.dart';

/// The live game view: running totals with the leader crowned, the round
/// history table, and round entry. Flips to final standings once the game
/// is over.
class ScoreboardScreen extends StatefulWidget {
  const ScoreboardScreen({
    super.key,
    required this.game,
    required this.onRematch,
    required this.onChangeSetup,
    required this.onShowHistory,
    required this.onPersist,
  });

  final Game game;

  /// Archive this game and start another with the same players and rules.
  final VoidCallback onRematch;

  /// Archive this game and return to the setup form.
  final VoidCallback onChangeSetup;

  final VoidCallback onShowHistory;

  /// Called after every mutation of [game] so the owner can save it.
  final Future<void> Function() onPersist;

  @override
  State<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends State<ScoreboardScreen> {
  Game get game => widget.game;
  bool _bidDialogOpen = false;

  /// User hid a progress popup to look at the board. Do not auto-show it
  /// again until they tap the bottom bar (or a new hand starts).
  bool _progressPopupHidden = false;

  /// Bid-order field text kept while the guess popup is hidden.
  List<String>? _bidDrafts;

  /// Score field text kept while the round popup is hidden.
  List<String>? _roundDrafts;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskBids());
  }

  @override
  void didUpdateWidget(ScoreboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskBids());
  }

  Future<void> _maybeAskBids() async {
    if (!mounted ||
        !game.whistAwaitingBids ||
        _bidDialogOpen ||
        _progressPopupHidden) {
      return;
    }
    await _askBids();
  }

  Future<void> _askBids() async {
    if (!mounted || _bidDialogOpen) return;
    _bidDialogOpen = true;
    _progressPopupHidden = false;
    final result = await showDialog<Object>(
      context: context,
      builder: (context) => WhistBidDialog(
        players: game.players,
        handCards: game.whistHandCards,
        bidOrder: game.whistBidOrder,
        initialTexts: _bidDrafts,
      ),
    );
    _bidDialogOpen = false;
    if (!mounted) return;
    if (result is List<int>) {
      _bidDrafts = null;
      _progressPopupHidden = false;
      setState(() => game.lockBids(result));
      await widget.onPersist();
      return;
    }
    if (result is List<String>) {
      _bidDrafts = result;
    }
    _progressPopupHidden = true;
    setState(() {});
  }

  Future<void> _toggleHit(int player) async {
    if (!game.whistMarkingHits) return;
    if (game.whistWouldMarkEveryone(player)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not everyone can have guessed correctly.'),
        ),
      );
      return;
    }
    setState(() => game.toggleWhistHit(player));
    await widget.onPersist();
  }

  Future<void> _finishWhistHand() async {
    if (!game.whistReadyToFinish) return;
    if (game.whistEveryoneHit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not everyone can have guessed correctly.'),
        ),
      );
      return;
    }
    setState(() => game.finishWhistHand());
    _progressPopupHidden = false;
    _bidDrafts = null;
    await widget.onPersist();
    if (mounted && game.whistAwaitingBids) {
      await _maybeAskBids();
    }
  }

  Future<void> _addRound() async {
    final result = await showDialog<Object>(
      context: context,
      builder: (context) => RoundEntryDialog(
        players: game.players,
        roundNumber: game.nextRoundNumber,
        initialTexts: _roundDrafts,
      ),
    );
    if (!mounted) return;
    if (result is List<int>) {
      _roundDrafts = null;
      setState(() => game.addRound(result));
      await widget.onPersist();
      return;
    }
    if (result is List<String>) {
      _roundDrafts = result;
    } else {
      _roundDrafts = null;
    }
    setState(() {});
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

  Future<void> _rematch({required bool confirm}) async {
    if (confirm) {
      final ok = await _confirm(
        'Archive this game and start another with the same players and rules?',
      );
      if (!ok) return;
    }
    widget.onRematch();
  }

  Future<void> _changeSetup({required bool confirm}) async {
    if (confirm) {
      final ok = await _confirm(
        'Archive this game and set up a different one?',
      );
      if (!ok) return;
    }
    widget.onChangeSetup();
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
    final scoreSuffix = game.targetScore == null
        ? ''
        : ' · playing to ${game.targetScore}';
    if (game.isOver) {
      return 'Final standings · $played round$plural played';
    }
    if (game.whist) {
      final dealer = game.players[game.whistDealer];
      final cards = game.whistHandCards;
      final stacks = game.whistCycles;
      final stack = game.whistStackNumber;
      if (game.whistAwaitingBids) {
        return 'Whist · $cards cards · $dealer deals · stack $stack of $stacks';
      }
      if (game.whistMarkingHits) {
        return 'Tap who guessed correctly!';
      }
      return 'Whist · $cards cards · $dealer deals · stack $stack of $stacks';
    }
    if (target != null) {
      return 'Round ${game.nextRoundNumber} of $target$scoreSuffix';
    }
    final base = played == 0
        ? 'No rounds played yet'
        : '$played round$plural played';
    return '$base$scoreSuffix';
  }

  /// After End game, Undo only reopens the game; elsewhere it takes back
  /// the last scores.
  String get _undoLabel =>
      game.whist || game.endedManually ? 'Undo' : 'Undo last round';

  Future<void> _openMenu() async {
    final over = game.isOver;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        void close(VoidCallback action) {
          Navigator.of(context).pop();
          action();
        }

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.undo),
                  title: Text(_undoLabel),
                  enabled: game.canUndo,
                  onTap: game.canUndo ? () => close(_undoLastRound) : null,
                ),
                if (!over) ...[
                  ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: const Text('End game'),
                    subtitle: const Text('Show who won'),
                    onTap: () => close(_endGame),
                  ),
                  ListTile(
                    leading: const Icon(Icons.replay),
                    title: const Text('New game'),
                    subtitle: const Text('Same players and rules'),
                    onTap: () => close(() => _rematch(confirm: true)),
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Back to setup'),
                  subtitle: const Text('Change players or rules'),
                  // Nothing is lost once the game is over.
                  onTap: () => close(() => _changeSetup(confirm: !over)),
                ),
                if (over)
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Past games'),
                    onTap: () => close(widget.onShowHistory),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skóre'), centerTitle: true),
      body: game.isOver ? _finalStandings(context) : _runningGame(context),
      bottomNavigationBar: _bottomBar(context),
    );
  }

  Widget _bottomBar(BuildContext context) {
    // Scaffold zeros MediaQuery.padding around the bar; viewPadding is the
    // system nav inset and keeps this row off the phone buttons.
    final navInset = MediaQuery.viewPaddingOf(context).bottom;
    return Material(
      elevation: 3,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + navInset),
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: _openMenu,
              icon: const Icon(Icons.menu),
              label: const Text('Menu'),
            ),
            const SizedBox(width: 12),
            Expanded(child: _primaryButton()),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton() {
    if (game.isOver) {
      return FilledButton.icon(
        onPressed: () => _rematch(confirm: false),
        icon: const Icon(Icons.replay),
        label: const Text('New game'),
      );
    }
    if (game.whistAwaitingBids) {
      return FilledButton.icon(
        onPressed: _askBids,
        icon: const Icon(Icons.edit),
        label: Text(_progressPopupHidden ? 'Back to guesses' : 'Enter guesses'),
      );
    }
    if (game.whistMarkingHits) {
      return FilledButton.icon(
        onPressed: _finishWhistHand,
        icon: const Icon(Icons.check),
        label: const Text('Finish round'),
      );
    }
    return FilledButton.icon(
      onPressed: _addRound,
      icon: const Icon(Icons.add),
      label: Text(_roundDrafts != null ? 'Back to scores' : 'Add round'),
    );
  }

  Widget _runningGame(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            _progressLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        _totalsStrip(context),
        const Divider(height: 1),
        Expanded(child: _historyTable(context)),
      ],
    );
  }

  Widget _totalsStrip(BuildContext context) {
    if (game.whistMarkingHits) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Column(
          children: [
            Text(
              'Guesses',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFFF9A825),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Tap who guessed correctly',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  for (var i = 0; i < game.players.length; i++)
                    _hitGuessButton(context, i),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (!game.whist && game.players.length > 3) {
      if (game.rounds.isEmpty) {
        return _playerChips(context);
      }
      return PodiumBoard(game: game);
    }
    final totals = game.totals;
    final leaders = game.leaders.toSet();
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

  Widget _playerChips(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [for (final name in game.players) Chip(label: Text(name))],
      ),
    );
  }

  Widget _hitGuessButton(BuildContext context, int index) {
    final theme = Theme.of(context);
    final hit = game.whistHit(index);
    const waiting = Color(0xFFFFE082);
    const made = Color(0xFF2E7D32);
    final onChip = hit ? Colors.white : Colors.black87;
    return Material(
      color: hit ? made : waiting,
      elevation: hit ? 2 : 0,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _toggleHit(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hit) ...[
                    const Icon(Icons.check, size: 18, color: Colors.white),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    game.players[index],
                    style: theme.textTheme.labelLarge?.copyWith(color: onChip),
                  ),
                  if (_isDealer(index)) ...[
                    const SizedBox(width: 6),
                    _dealerBadge(context, onChip, hit ? made : waiting),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${game.whistBids![index]}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: onChip,
                ),
              ),
              Text(
                'guess',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: onChip.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isDealer(int index) =>
      game.whist && !game.isOver && index == game.whistDealer;

  /// Small "D" chip next to the dealer's name during live Whist play.
  Widget _dealerBadge(BuildContext context, Color fill, Color text) {
    return Tooltip(
      message: 'Dealer',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'D',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _playerCard(
    BuildContext context,
    int index,
    int total,
    bool isLeader,
  ) {
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
                Text(
                  game.players[index],
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (_isDealer(index)) ...[
                  const SizedBox(width: 6),
                  _dealerBadge(
                    context,
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.onPrimary,
                  ),
                ],
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
      return Center(
        child: Text(
          game.whistAwaitingBids
              ? 'Enter guesses with the button below.'
              : game.whist
              ? 'Tap who guessed correctly (or nobody), then Finish round.'
              : 'Add the first round with the button below.',
        ),
      );
    }
    final theme = Theme.of(context);
    final columnLine = BorderSide(
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
    );
    // DataTable drew row lines in Material 3's divider color, not the
    // faded column color.
    final rowLine = BorderSide(color: theme.colorScheme.outlineVariant);
    // Between Whist stacks: heavier than the grid, matching the paper sheet.
    final stackLine = BorderSide(color: theme.colorScheme.outline, width: 2);
    final headingStyle = theme.textTheme.titleSmall;
    final sumStyle = headingStyle?.copyWith(fontWeight: FontWeight.w700);
    final totals = game.totals;

    // A plain Table with DataTable's metrics (heading 56, rows 48, margins
    // 24, column gap 56): DataRow has no border of its own, and the line
    // between stacks needs one.
    Widget cell(int column, Widget child, {double height = 48}) => Container(
      height: height,
      padding: EdgeInsetsDirectional.only(
        start: column == 0 ? 24 : 28,
        end: column == game.players.length ? 24 : 28,
      ),
      alignment: AlignmentDirectional.centerStart,
      child: child,
    );

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: PinnedFirstRow(
            table: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder(verticalInside: columnLine),
              children: [
                TableRow(
                  children: [
                    cell(0, Text('#', style: headingStyle), height: 56),
                    for (var i = 0; i < game.players.length; i++)
                      cell(
                        i + 1,
                        Center(
                          child: Text(game.players[i], style: headingStyle),
                        ),
                        height: 56,
                      ),
                  ],
                ),
                for (var r = 0; r < game.rounds.length; r++)
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                        top: game.startsWhistStack(r) ? stackLine : rowLine,
                      ),
                    ),
                    children: [
                      cell(0, Text('R${game.roundNumber(r)}')),
                      for (var i = 0; i < game.players.length; i++)
                        cell(
                          i + 1,
                          Center(child: Text('${game.rounds[r][i]}')),
                        ),
                    ],
                  ),
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(top: rowLine),
                    color: theme.colorScheme.secondaryContainer,
                  ),
                  children: [
                    cell(0, Text('SUM', style: sumStyle)),
                    for (var i = 0; i < game.players.length; i++)
                      cell(
                        i + 1,
                        Center(child: Text('${totals[i]}', style: sumStyle)),
                      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            _progressLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        WinnerBanner(game: game),
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PaperScoreSheet(game: game),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
