import 'package:flutter/material.dart';

import '../audio/game_audio_controller.dart';
import '../game.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({required this.game, super.key});

  static const String overlayId = 'game_over';

  final CyberRunnerGame game;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF3A0B0B),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Image.asset(
                    'assets/images/game_over.png',
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  _ScoreBox(
                    score: game.stars.value,
                    best: game.bestStars.value,
                  ),
                  const SizedBox(height: 14),
                  _ImageButton(
                    imagePath: 'assets/images/start_again.png',
                    label: 'Start again',
                    onPressed: game.restart,
                  ),
                  const SizedBox(height: 10),
                  _ImageButton(
                    imagePath: 'assets/images/back_to_menu.png',
                    label: 'Back to menu',
                    onPressed: game.onExitToMenu,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({required this.score, required this.best});

  final int score;
  final int best;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 498 / 396,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(
            child: Image.asset(
              'assets/images/game_over_box.png',
              fit: BoxFit.contain,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(54, 64, 54, 58),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _ScoreValue(label: 'score', value: score),
                const SizedBox(height: 22),
                _ScoreValue(label: 'best', value: best),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreValue extends StatelessWidget {
  const _ScoreValue({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFE6D6),
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$value',
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _ImageButton extends StatefulWidget {
  const _ImageButton({
    required this.imagePath,
    required this.label,
    required this.onPressed,
  });

  final String imagePath;
  final String label;
  final Future<void> Function() onPressed;

  @override
  State<_ImageButton> createState() => _ImageButtonState();
}

class _ImageButtonState extends State<_ImageButton> {
  double _scale = 1.0;

  Future<void> _handlePressed() async {
    await GameAudioController.instance.playButtonSound();
    await widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            _scale = 0.96;
          });
        },
        onTapUp: (_) {
          setState(() {
            _scale = 1.0;
          });
          _handlePressed();
        },
        onTapCancel: () {
          setState(() {
            _scale = 1.0;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOutCubic,
          child: AspectRatio(
            aspectRatio: 378 / 150,
            child: Image.asset(widget.imagePath, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
