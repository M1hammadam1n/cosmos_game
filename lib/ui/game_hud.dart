import 'package:flutter/material.dart';

import '../audio/game_audio_controller.dart';
import '../game.dart';

class GameHud extends StatelessWidget {
  const GameHud({required this.game, super.key});

  static const String overlayId = 'game_hud';

  final CyberRunnerGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned(
          top: MediaQuery.paddingOf(context).top + 14,
          left: 18,
          right: 18,
          child: _ScoreBar(game: game),
        ),
        Positioned(
          left: 22,
          bottom: MediaQuery.paddingOf(context).bottom + 22,
          child: _LaneButton(
            imagePath: 'assets/images/Left.png',
            onPressed: game.moveLeft,
          ),
        ),
        Positioned(
          right: 22,
          bottom: MediaQuery.paddingOf(context).bottom + 22,
          child: _LaneButton(
            imagePath: 'assets/images/Right.png',
            onPressed: game.moveRight,
          ),
        ),
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.game});

  final CyberRunnerGame game;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        _HudPill(
          label: 'STARS',
          listenable: game.stars,
          icon: Icons.star_rounded,
        ),
        _ExitButton(onPressed: game.onExitToMenu),
        _HudPill(
          label: 'BEST',
          listenable: game.bestStars,
          icon: Icons.bolt_rounded,
        ),
      ],
    );
  }
}

class _ExitButton extends StatelessWidget {
  const _ExitButton({required this.onPressed});

  final Future<void> Function() onPressed;

  Future<void> _handlePressed() async {
    await GameAudioController.instance.playButtonSound();
    await onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 46,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xDD081025),
          border: Border.all(color: const Color(0xAAFFF176), width: 1.3),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x66FFF176), blurRadius: 18),
          ],
        ),
        child: IconButton(
          tooltip: 'На главную',
          onPressed: _handlePressed,
          icon: const Icon(
            Icons.home_rounded,
            size: 24,
            color: Color(0xFFFFF176),
          ),
        ),
      ),
    );
  }
}

class _HudPill extends StatelessWidget {
  const _HudPill({
    required this.label,
    required this.listenable,
    required this.icon,
  });

  final String label;
  final ValueNotifier<int> listenable;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xCC081025),
            border: Border.all(color: const Color(0xAA00E5FF), width: 1.4),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x6600E5FF),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, color: const Color(0xFFFFF176), size: 20),
                const SizedBox(width: 8),
                Text(
                  '$label ${listenable.value}',
                  style: const TextStyle(
                    color: Color(0xFFEAFBFF),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LaneButton extends StatefulWidget {
  const _LaneButton({
    required this.imagePath, 
    required this.onPressed,
  });

  final String imagePath;
  final VoidCallback onPressed;

  @override
  State<_LaneButton> createState() => _LaneButtonState();
}

class _LaneButtonState extends State<_LaneButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _scale = 1.15; 
        });
      },
      onTapUp: (_) {
        setState(() {
          _scale = 1.0;
        });
        widget.onPressed();
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
        child: SizedBox(
          width: 74,
          height: 74,
          child: Image.asset(
            widget.imagePath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                widget.imagePath.contains('Left') 
                    ? Icons.arrow_back_ios_new_rounded 
                    : Icons.arrow_forward_ios_rounded,
                size: 44,
                color: const Color(0xFFFF2BD6),
              );
            },
          ),
        ),
      ),
    );
  }
}