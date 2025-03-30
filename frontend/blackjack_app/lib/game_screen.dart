import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  final _playerCardsController = TextEditingController();
  final _dealerCardController = TextEditingController();
  final _drawnCardController = TextEditingController();

  List<String> _playerCards = [];
  String _dealerCard = "";
  String _agentAction = "";
  bool _awaitingNewCard = false;
  bool _gameOver = false;
  String _gameResult = "";

  Map<String, dynamic> _currentState = {};

  late AnimationController _controller;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(seconds: 1));
    _fadeInAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();
  }

  @override
  void dispose() {
    _playerCardsController.dispose();
    _dealerCardController.dispose();
    _drawnCardController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _calculateHandStateFromBackend() async {
    String url = "http://localhost:5000/calculate_hand";
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "cards": _playerCards,
          "dealer_card": _dealerCard.trim().toUpperCase()
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _currentState = data;
          if (data['hand_value'] > 21) {
            _gameOver = true;
            _agentAction = "You busted!";
            _submitResult("bust");
          }
        });
      } else {
        setState(() {
          _agentAction = "Failed to calculate hand.";
        });
      }
    } catch (e) {
      setState(() {
        _agentAction = "Backend error: $e";
      });
    }
  }

  Future<void> _getAgentAction() async {
    setState(() {
      _agentAction = "";
    });

    await _calculateHandStateFromBackend();

    if (_gameOver) return;

    String url = "http://localhost:5000/get_action";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"state": _currentState}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _agentAction = data['action'] ?? "No action returned";
        });

        if (_agentAction == "Hit") {
          setState(() {
            _awaitingNewCard = true;
          });
        } else if (_agentAction == "Stand") {
          setState(() {
            _gameOver = true;
          });
        }
      } else {
        setState(() {
          _agentAction = "Error: \${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _agentAction = "Request failed: $e";
      });
    }
  }

  Future<void> _submitNewCard() async {
    String newCard = _drawnCardController.text.trim().toUpperCase();
    _playerCards.add(newCard);
    _drawnCardController.clear();
    setState(() {
      _awaitingNewCard = false;
    });
    await _getAgentAction();
  }

  Future<void> _submitResult(String result) async {
    final url = Uri.parse("http://localhost:5000/get_result_response");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"result": result}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _gameResult = data["message"] ?? "Result received.";
        });
      } else {
        setState(() {
          _gameResult = "❌ Failed to get response from server.";
        });
      }
    } catch (e) {
      setState(() {
        _gameResult = "❌ Error: $e";
      });
    }
  }


  void _startNewGame() {
    setState(() {
      _playerCards = _playerCardsController.text.split(',');
      _dealerCard = _dealerCardController.text;
      _agentAction = "";
      _awaitingNewCard = false;
      _gameOver = false;
      _gameResult = "";
    });
    _controller.forward(from: 0);
    _getAgentAction();
  }

  InputDecoration _textInputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.grey),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.amberAccent, width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.amberAccent, width: 2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.white, width: 3),
    ),
  );

  ButtonStyle _fancyButtonStyle(Color color) => ElevatedButton.styleFrom(
    backgroundColor: color,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  );

  Widget _buildLabel(String text) => Text(
    text,
    style: GoogleFonts.lato(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      shadows: const [Shadow(blurRadius: 2, color: Colors.black, offset: Offset(1, 1))],
    ),
  );

  Widget _buildAgentResponse() => Center(
    child: AnimatedOpacity(
      opacity: 1,
      duration: const Duration(seconds: 1),
      child: Text(" $_agentAction",
          style: GoogleFonts.cinzel(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.yellowAccent)),
    ),
  );

  Widget _buildDrawCardSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("🃏 Enter drawn card:", style: TextStyle(color: Colors.white)),
      TextField(
        controller: _drawnCardController,
        style: const TextStyle(color: Colors.white),
        decoration: _textInputDecoration('e.g. 5'),
      ),
      ElevatedButton(
        onPressed: _submitNewCard,
        style: _fancyButtonStyle(Colors.deepPurple),
        child: Text("Submit Drawn Card",
            style: GoogleFonts.cinzel(fontSize: 16, color: Colors.white)),
      ),
    ],
  );

  Widget _buildResultButtons() => Column(
    children: [
      const Text("🏁 Game Over. What was the result?", style: TextStyle(color: Colors.white)),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(onPressed: () => _submitResult("win"), style: _fancyButtonStyle(Colors.green), child: const Text("Win")),
          const SizedBox(width: 10),
          ElevatedButton(onPressed: () => _submitResult("loss"), style: _fancyButtonStyle(Colors.red), child: const Text("Loss")),
          const SizedBox(width: 10),
          ElevatedButton(onPressed: () => _submitResult("draw"), style: _fancyButtonStyle(Colors.blueGrey), child: const Text("Draw")),
        ],
      ),
    ],
  );

  Widget _buildResultConfirmation() => Center(
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(seconds: 1),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(scale: value, child: child),
      ),
      child: Text(" $_gameResult",
          style: const TextStyle(fontSize: 18, color: Colors.white12)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: Text(
          "♠️ BlackJack Bot ♣️",
          style: GoogleFonts.playfairDisplay(fontSize: 24, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/background_table_v2.jpg"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            FadeTransition(
              opacity: _fadeInAnimation,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Enter your cards:"),
                      TextField(
                        controller: _playerCardsController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _textInputDecoration('e.g. 10, 6').copyWith(
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width:2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildLabel("Dealer's card:"),
                      TextField(
                        controller: _dealerCardController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _textInputDecoration('e.g. K'),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: ElevatedButton(
                          onPressed: _startNewGame,
                          style: _fancyButtonStyle(Colors.deepPurple),
                          child: Text("Start Game", style: GoogleFonts.cinzel(fontSize: 16, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_agentAction.isNotEmpty) _buildAgentResponse(),
                      if (_awaitingNewCard) _buildDrawCardSection(),
                      if (_gameOver && _gameResult == "" && _agentAction != "You busted!") _buildResultButtons(),
                      if (_gameResult.isNotEmpty) _buildResultConfirmation(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}