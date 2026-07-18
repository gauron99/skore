import 'package:flutter/material.dart';

import 'data/game.dart';
import 'data/game_store.dart';
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

/// Restores any saved game on launch and switches between the setup screen
/// (no game) and the scoreboard (game in progress or finished).
class HomeGate extends StatefulWidget {
  const HomeGate({super.key});

  @override
  State<HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends State<HomeGate> {
  Game? _game;
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    GameStore.load().then((game) {
      if (!mounted) return;
      setState(() {
        _game = game;
        _restored = true;
      });
    });
  }

  Future<void> _startGame(Game game) async {
    await GameStore.save(game);
    if (!mounted) return;
    setState(() => _game = game);
  }

  Future<void> _newGame() async {
    await GameStore.clear();
    if (!mounted) return;
    setState(() => _game = null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_restored) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final game = _game;
    return game == null
        ? SetupScreen(onStart: _startGame)
        : ScoreboardScreen(game: game, onNewGame: _newGame);
  }
}
