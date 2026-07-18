import 'package:flutter/material.dart';

import 'data/app_data.dart';
import 'data/game.dart';
import 'data/game_store.dart';
import 'screens/history_screen.dart';
import 'screens/scoreboard_screen.dart';
import 'screens/setup_screen.dart';

void main() {
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

  @override
  void initState() {
    super.initState();
    GameStore.load().then((data) {
      if (!mounted) return;
      setState(() => _data = data);
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

  /// "New game" from the scoreboard: archive what's there, back to setup.
  Future<void> _archiveAndNew() async {
    setState(() => _data!.archiveCurrent());
    await _persist();
  }

  Future<void> _deleteAll() async {
    setState(() => _data = AppData());
    await GameStore.deleteAll();
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
    final data = _data;
    if (data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final game = data.current;
    return game == null
        ? SetupScreen(onStart: _startGame, onShowHistory: _showHistory)
        : ScoreboardScreen(
            game: game,
            onNewGame: _archiveAndNew,
            onShowHistory: _showHistory,
            onPersist: _persist,
          );
  }
}
