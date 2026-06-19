import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/game_audio_controller.dart';
import 'game.dart';
import 'ui/game_hud.dart';
import 'ui/game_over.dart';
import 'ui/start_menu.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const CyberRunnerApp());
}

class CyberRunnerApp extends StatelessWidget {
  const CyberRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Space Chicken',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const _GameShell(),
    );
  }
}

class _GameShell extends StatefulWidget {
  const _GameShell();

  @override
  State<_GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<_GameShell> {
  CyberRunnerGame? _game;

  Future<void> _startGame() async {
    await GameAudioController.instance.playTransitionSound();
    setState(() {
      _game = CyberRunnerGame(onExitToMenu: _exitToMenu);
    });
  }

  Future<void> _exitToMenu() async {
    await GameAudioController.instance.playTransitionSound();
    if (!mounted) {
      return;
    }
    setState(() {
      _game = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;

    if (game == null) {
      return StartMenu(onStart: _startGame);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF050713),
      body: SafeArea(
        top: false,
        bottom: false,
        child: GameWidget<CyberRunnerGame>(
          game: game,
          initialActiveOverlays: const <String>[GameHud.overlayId],
          overlayBuilderMap: <String, OverlayWidgetBuilder<CyberRunnerGame>>{
            GameHud.overlayId: (context, game) => GameHud(game: game),
            GameOverOverlay.overlayId: (context, game) =>
                GameOverOverlay(game: game),
          },
        ),
      ),
    );
  }
}
