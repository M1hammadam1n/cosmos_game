import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../audio/game_audio_controller.dart';
import '../game.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({required this.game, super.key});

  static const String overlayId = 'game_over';

  final CyberRunnerGame game;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/Background_game_over.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shortestSide = MediaQuery.sizeOf(context).shortestSide;
            final isTablet = shortestSide >= 600;
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            final horizontalPadding = isTablet ? 40.0 : 22.0;
            final verticalPadding = isLandscape ? 10.0 : 18.0;
            final availableWidth = math.max(
              0.0,
              constraints.maxWidth - horizontalPadding * 2,
            );
            final availableHeight = math.max(
              0.0,
              constraints.maxHeight - verticalPadding * 2,
            );
            final contentWidth = math.min(
              isTablet ? 620.0 : 560.0,
              availableWidth * (isLandscape ? 0.68 : 0.92),
            );

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Center(
                child: SizedBox(
                  width: availableWidth,
                  height: availableHeight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: contentWidth,
                      child: _GameOverPanel(
                        contentWidth: contentWidth,
                        score: game.stars.value,
                        best: game.bestStars.value,
                        onRestart: game.restart,
                        onMenu: game.onExitToMenu,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GameOverPanel extends StatelessWidget {
  const _GameOverPanel({
    required this.contentWidth,
    required this.score,
    required this.best,
    required this.onRestart,
    required this.onMenu,
  });

  final double contentWidth;
  final int score;
  final int best;
  final Future<void> Function() onRestart;
  final Future<void> Function() onMenu;

  @override
  Widget build(BuildContext context) {
    final titleWidth = math.min(contentWidth, 520.0);
    final buttonWidth = math.min(contentWidth * 0.68, 320.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Image.asset(
          'assets/images/game_over.png',
          width: titleWidth,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 12),
        _ScoreBox(contentMaxWidth: contentWidth, score: score, best: best),
        const SizedBox(height: 16),
        SizedBox(
          width: buttonWidth,
          child: _ImageButton(
            imagePath: 'assets/images/start_again.png',
            label: 'Start again',
            onPressed: onRestart,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: buttonWidth,
          child: _ImageButton(
            imagePath: 'assets/images/back_to_menu.png',
            label: 'Back to menu',
            onPressed: onMenu,
          ),
        ),
      ],
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({
    required this.contentMaxWidth,
    required this.score,
    required this.best,
  });

  final double contentMaxWidth;
  final int score;
  final int best;

  @override
  Widget build(BuildContext context) {
    final double boxWidth = math.min(contentMaxWidth * 0.8, 420.0);

    return SizedBox(
      width: boxWidth,
      child: AspectRatio(
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Transform.scale(
                    scale: 0.8,
                    child: Column(
                      children: [
                        _ScoreValue(label: 'score', value: score),
                        const SizedBox(height: 10),
                        _ScoreValue(label: 'best', value: best),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            style: GoogleFonts.moul(
              color: Colors.white,
              fontSize: 40,
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
            style: GoogleFonts.moul(
              color: Colors.white,
              fontSize: 26,
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
            aspectRatio: 278 / 50,
            child: Image.asset(widget.imagePath, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
