import 'package:flutter/material.dart';
import 'package:space_chicken/ui/settings_page.dart';

import '../game.dart';

class GameHud extends StatelessWidget {
  const GameHud({required this.game, super.key});

  static const String overlayId = 'game_hud';

  final CyberRunnerGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: <Widget>[
          Positioned(left: 18, top: 14, child: _ScoreBar(game: game)),
          Positioned(
            right: 18,
            top: 14,
            child: Row(
              children: [
                _IconButton(
                  imagePath: 'assets/images/Pause.png',
                  onPressed: () {
                    game.pauseEngine();
                  },
                ),
                const SizedBox(width: 10),
                _IconButton(
                  imagePath: 'assets/images/Menu.png',
                  onPressed: () async {
                    game.pauseEngine();
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                    game.resumeEngine();
                  },
                ),
              ],
            ),
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
      ),
    );
  }
}

// Универсальный виджет для кнопок Pause/Menu
class _IconButton extends StatelessWidget {
  const _IconButton({required this.imagePath, required this.onPressed});

  final String imagePath;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool isPauseButton = imagePath.contains('Pause');

    return GestureDetector(
      onTap: onPressed,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Image.asset(
          imagePath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              isPauseButton ? Icons.pause_rounded : Icons.menu_rounded,
              size: 34,
              color: const Color(0xFFEAFBFF),
            );
          },
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.game});

  final CyberRunnerGame game;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment
          .start, // Выравнивание по левому краю для плашки с очками
      children: <Widget>[
        // Кастомный счетчик STARS с яйцом и плашкой
        _EggScorePill(listenable: game.stars),
      ],
    );
  }
}

// Новый виджет для отображения очков в виде яйца, плашки и текста
class _EggScorePill extends StatelessWidget {
  const _EggScorePill({required this.listenable});

  final ValueNotifier<int> listenable;

  @override
  Widget build(BuildContext context) {
    // Размеры подбираются под дизайн вашей игры
    const double plateWidth = 150.0;
    const double plateHeight = 54.0;
    const double eggSize = 100.0;

    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) {
        return SizedBox(
          // Общая ширина: плашка + выступающая слева часть яйца
          width: plateWidth + (eggSize * 0.2),
          height: eggSize,
          child: Stack(
            clipBehavior:
                Clip.none, // Позволяет элементам выходить за рамки контейнера
            children: <Widget>[
              // 1. СЛОЙ СЗАДИ: Картинка яйца (general_shot.png)
              // Размещаем её у самого левого края. Она займет свои 20% пространства слева
              Positioned(
                bottom: 45,
                left: 0,
                top: 0,
                child: Image.asset(
                  'assets/images/general_shot.png',
                  width: eggSize,
                  height: eggSize,
                  fit: BoxFit.contain,
                ),
              ),

              // 2. СЛОЙ СВЕРХУ: Плашка под цифры (gold_egg_for_number.png)
              // Объявляем её ПРАВЕЕ и НИЖЕ в Stack, чтобы она перекрыла яйцо сверху
              Positioned(
                right: 80,
                // top:
                //     (eggSize - plateHeight) /
                //     2, // Центрируем плашку по вертикали относительно яйца
                child: SizedBox(
                  width: plateWidth,
                  height: plateHeight,
                  child: Stack(
                    children: [
                      // Фоновая картинка самой плашки (занимает всю выделенную ей ширину)
                      Positioned.fill(
                        child: Image.asset(
                          'assets/images/gold_egg_for_number.png',
                          fit: BoxFit.contain,
                        ),
                      ),

                      // 3. Текст по центру плашки со смещением на 32% слева
                      Positioned(
                        left: plateWidth * 0.65,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          alignment: Alignment.center,
                          child: Text(
                            '${listenable.value}',
                            style: const TextStyle(
                              color: Color(
                                0xFFEAFBFF,
                              ), // Бело-голубой неоновый цвет текста
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LaneButton extends StatefulWidget {
  const _LaneButton({required this.imagePath, required this.onPressed});

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
