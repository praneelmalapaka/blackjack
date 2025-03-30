import 'package:flutter/material.dart';
import 'game_screen.dart';

void main() {
  runApp(BlackjackApp());
}

class BlackjackApp extends StatelessWidget {
  const BlackjackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blackjack Table',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: GameScreen(),
    );
  }
}
