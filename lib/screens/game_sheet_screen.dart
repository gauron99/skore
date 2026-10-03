import 'package:flutter/material.dart';

import '../data/game.dart';
import '../widgets/final_standings.dart';
import '../widgets/paper_score_sheet.dart';

/// Full-screen paper sheet for a finished (or archived) game.
class GameSheetScreen extends StatelessWidget {
  const GameSheetScreen({super.key, required this.game, required this.title});

  final Game game;
  final String title;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: ListView(
        padding: EdgeInsets.only(bottom: 16 + bottom),
        children: [
          FinalStandings(game: game),
          Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PaperScoreSheet(game: game),
            ),
          ),
        ],
      ),
    );
  }
}
