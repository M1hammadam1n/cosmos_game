import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../audio/game_audio_controller.dart';
import '../game.dart';

class WinnerOverlay extends StatelessWidget {
  const WinnerOverlay({required this.game, super.key});

  static const String overlayId = 'winner';

  final CyberRunnerGame game;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        image: DecorationImage(
          image: const AssetImage('assets/images/winner_banner.png'),
          fit: isLandscape ? BoxFit.cover : BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shortestSide = MediaQuery.sizeOf(context).shortestSide;
            final isTablet = shortestSide >= 600;
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            final horizontalPadding = isTablet ? 40.0 : 22.0;
            final verticalPadding = isLandscape ? 8.0 : 18.0;
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
              availableWidth * 0.9,
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
                  child: isLandscape
                      ? _WinnerLandscapePanel(
                          availableWidth: availableWidth,
                          availableHeight: availableHeight,
                          score: game.stars.value,
                          best: game.bestStars.value,
                          onRestart: game.restart,
                          onMenu: game.onExitToMenu,
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: contentWidth,
                            child: _WinnerPanel(
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

class _WinnerLandscapePanel extends StatelessWidget {
  const _WinnerLandscapePanel({
    required this.availableWidth,
    required this.availableHeight,
    required this.score,
    required this.best,
    required this.onRestart,
    required this.onMenu,
  });

  final double availableWidth;
  final double availableHeight;
  final int score;
  final int best;
  final Future<void> Function() onRestart;
  final Future<void> Function() onMenu;

  @override
  Widget build(BuildContext context) {
    final gap = (availableWidth * 0.05).clamp(28.0, 56.0).toDouble();
    final buttonWidth = math
        .min(availableWidth * 0.34, availableHeight * 1.65)
        .clamp(300.0, 420.0)
        .toDouble();
    final resultWidth = math.max(260.0, availableWidth - buttonWidth - gap);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: resultWidth,
          height: availableHeight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: math.min(resultWidth, 520.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/winner.png',
                    width: math.min(resultWidth, 500.0),
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  _WinnerScoreBox(
                    contentMaxWidth: math.min(resultWidth, 520.0),
                    score: score,
                    best: best,
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: gap),
        SizedBox(
          width: buttonWidth,
          height: availableHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: buttonWidth,
                  child: _WinnerImageButton(
                    imagePath: 'assets/images/start_again.png',
                    label: 'Start again',
                    onPressed: onRestart,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: buttonWidth,
                  child: _WinnerImageButton(
                    imagePath: 'assets/images/back_to_menu.png',
                    label: 'Back to menu',
                    onPressed: onMenu,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WinnerPanel extends StatelessWidget {
  const _WinnerPanel({
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
          'assets/images/winner.png',
          width: titleWidth,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 10),
        _WinnerScoreBox(
          contentMaxWidth: contentWidth,
          score: score,
          best: best,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: buttonWidth,
          child: _WinnerImageButton(
            imagePath: 'assets/images/start_again.png',
            label: 'Start again',
            onPressed: onRestart,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: buttonWidth,
          child: _WinnerImageButton(
            imagePath: 'assets/images/back_to_menu.png',
            label: 'Back to menu',
            onPressed: onMenu,
          ),
        ),
      ],
    );
  }
}

class _WinnerScoreBox extends StatelessWidget {
  const _WinnerScoreBox({
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
                        _WinnerScoreValue(label: 'score', value: score),
                        const SizedBox(height: 10),
                        _WinnerScoreValue(label: 'best', value: best),
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

class _WinnerScoreValue extends StatelessWidget {
  const _WinnerScoreValue({required this.label, required this.value});

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

class _WinnerImageButton extends StatefulWidget {
  const _WinnerImageButton({
    required this.imagePath,
    required this.label,
    required this.onPressed,
  });

  final String imagePath;
  final String label;
  final Future<void> Function() onPressed;

  @override
  State<_WinnerImageButton> createState() => _WinnerImageButtonState();
}

class _WinnerImageButtonState extends State<_WinnerImageButton> {
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
