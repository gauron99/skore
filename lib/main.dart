import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/app_data.dart';
import 'data/game.dart';
import 'data/game_store.dart';
import 'screens/history_screen.dart';
import 'screens/scoreboard_screen.dart';
import 'screens/setup_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const SkoreApp());
}

class SkoreApp extends StatelessWidget {
  const SkoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skóre',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      // Tie text size to the window: phone-sized screens keep the native
      // size, bigger windows scale up (capped at 1.8x) so scores are
      // readable from across the table. Composed with the system
      // accessibility text scale instead of replacing it.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final windowScale = (media.size.shortestSide / 600).clamp(1.0, 1.8);
        final systemScale = media.textScaler.scale(14) / 14;
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(systemScale * windowScale),
          ),
          child: child!,
        );
      },
      home: const HomeGate(),
    );
  }
}

/// Restores saved data on launch and switches between the setup screen (no
/// active game) and the scoreboard. Owns every mutation of [AppData].
class HomeGate extends StatefulWidget {
  const HomeGate({super.key});

  @override
  State<HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends State<HomeGate> {
  AppData? _data;
  bool _savedGameBlocked = false;

  @override
  void initState() {
    super.initState();
    GameStore.load().then((loaded) {
      if (!mounted) return;
      setState(() {
        _savedGameBlocked = loaded.blocked;
        _data = loaded.data;
      });
    });
  }

  Future<void> _persist() async {
    final data = _data;
    if (data != null) {
      await GameStore.save(data);
    }
  }

  Future<void> _startGame(Game game) async {
    setState(() => _data!.current = game);
    await _persist();
  }

  /// Archive the current game and start another with the same players/rules.
  Future<void> _rematch() async {
    setState(() => _data!.rematchCurrent());
    await _persist();
  }

  /// Archive the current game and return to the setup form.
  Future<void> _archiveAndSetup() async {
    setState(() => _data!.archiveCurrent());
    await _persist();
  }

  Future<void> _deleteAll() async {
    setState(() {
      _savedGameBlocked = false;
      _data = AppData();
    });
    await GameStore.deleteAll();
  }

  Future<void> _discardBlockedSave() async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text('Delete the saved game and start over?'),
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
    if (answer != true || !mounted) return;
    await _deleteAll();
  }

  void _showHistory() {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => HistoryScreen(
              data: _data!,
              onPersist: _persist,
              onDeleteAll: _deleteAll,
            ),
          ),
        )
        .then((_) {
          // Deletions in the history screen may have changed what to show.
          if (mounted) setState(() {});
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_savedGameBlocked) return _blockedSave();
    final data = _data;
    if (data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final game = data.current;
    return game == null
        ? SetupScreen(
            // Delete all data swaps in a new AppData: start a blank form.
            key: ObjectKey(data),
            lastGame: data.history.lastOrNull,
            onStart: _startGame,
            onShowHistory: _showHistory,
          )
        : ScoreboardScreen(
            game: game,
            onRematch: _rematch,
            onChangeSetup: _archiveAndSetup,
            onShowHistory: _showHistory,
            onPersist: _persist,
          );
  }

  Widget _blockedSave() {
    return Scaffold(
      appBar: AppBar(title: const Text('Skóre'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'The saved game could not be opened. It was left on disk.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _discardBlockedSave,
                child: const Text('Delete saved data'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
