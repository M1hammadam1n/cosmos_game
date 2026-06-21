import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'audio/game_audio_controller.dart';
import 'game.dart';
import 'system_ui_config.dart';
import 'ui/game_hud.dart';
import 'ui/game_over.dart';
import 'ui/loading_screen.dart';
import 'ui/start_menu.dart';
import 'ui/winner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await configureImmersiveSystemUi();

  runApp(const CyberRunnerApp());
}

class CyberRunnerApp extends StatelessWidget {
  const CyberRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00E5FF),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );

    return ImmersiveSystemUiScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Space Chicken',
        theme: baseTheme.copyWith(
          textTheme: GoogleFonts.moulTextTheme(baseTheme.textTheme),
          primaryTextTheme: GoogleFonts.moulTextTheme(baseTheme.primaryTextTheme),
          snackBarTheme: SnackBarThemeData(
            contentTextStyle: GoogleFonts.moul(color: Colors.white),
          ),
        ),
        home: const _GameShell(),
      ),
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
  bool _showLoading = true;

  @override
  void initState() {
    super.initState();
    _finishLoadingScreen();
  }

  Future<void> _finishLoadingScreen() async {
    await Future<void>.delayed(LoadingScreen.displayDuration);
    if (!mounted) {
      return;
    }
    setState(() {
      _showLoading = false;
    });
  }

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

    if (game != null) {
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
              WinnerOverlay.overlayId: (context, game) =>
                  WinnerOverlay(game: game),
            },
          ),
        ),
      );
    }

    if (_showLoading) {
      return const LoadingScreen();
    }

    return StartMenu(onStart: _startGame);
  }
}
