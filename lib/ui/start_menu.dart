import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/game_audio_controller.dart';

class StartMenu extends StatefulWidget {
  const StartMenu({required this.onStart, super.key});

  final Future<void> Function() onStart;

  @override
  State<StartMenu> createState() => _StartMenuState();
}

class _StartMenuState extends State<StartMenu> {
  bool _musicEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _language = 'ru';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final audio = GameAudioController.instance;
    await audio.init();
    if (!mounted) {
      return;
    }

    setState(() {
      _musicEnabled = audio.musicEnabled;
      _soundEnabled = audio.soundEnabled;
      _vibrationEnabled = audio.vibrationEnabled;
      _language = audio.language;
    });
  }

  Future<void> _updateSettings(
    StateSetter dialogSetState,
    VoidCallback update,
    Future<void> Function() save,
  ) async {
    setState(update);
    dialogSetState(() {});
    await save();
  }

  Future<void> _openSettings() async {
    await GameAudioController.instance.playTransitionSound();
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xF2071024),
                    border: Border.all(
                      color: const Color(0xCC00E5FF),
                      width: 1.4,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: Color(0x9900E5FF), blurRadius: 30),
                      BoxShadow(color: Color(0x66FF2BD6), blurRadius: 42),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Expanded(
                              child: Text(
                                'Настройки',
                                style: TextStyle(
                                  color: Color(0xFFEAFBFF),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Закрыть',
                              onPressed: () async {
                                await GameAudioController.instance
                                    .playButtonSound();
                                if (!context.mounted) {
                                  return;
                                }
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.close_rounded),
                              color: const Color(0xFFEAFBFF),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _SettingsSwitch(
                          icon: Icons.music_note_rounded,
                          title: 'Музыка',
                          value: _musicEnabled,
                          onChanged: (value) => _updateSettings(
                            dialogSetState,
                            () => _musicEnabled = value,
                            () => GameAudioController.instance.setMusicEnabled(
                              value,
                            ),
                          ),
                        ),
                        _SettingsSwitch(
                          icon: Icons.volume_up_rounded,
                          title: 'Звук',
                          value: _soundEnabled,
                          onChanged: (value) => _updateSettings(
                            dialogSetState,
                            () => _soundEnabled = value,
                            () => GameAudioController.instance.setSoundEnabled(
                              value,
                            ),
                          ),
                        ),
                        _SettingsSwitch(
                          icon: Icons.vibration_rounded,
                          title: 'Вибрация',
                          value: _vibrationEnabled,
                          onChanged: (value) => _updateSettings(
                            dialogSetState,
                            () => _vibrationEnabled = value,
                            () => GameAudioController.instance
                                .setVibrationEnabled(value),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _language,
                          dropdownColor: const Color(0xFF071024),
                          iconEnabledColor: const Color(0xFF00E5FF),
                          decoration: _inputDecoration(
                            icon: Icons.translate_rounded,
                            label: 'Язык',
                          ),
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem(
                              value: 'ru',
                              child: Text('Русский'),
                            ),
                            DropdownMenuItem(
                              value: 'en',
                              child: Text('English'),
                            ),
                            DropdownMenuItem(
                              value: 'uz',
                              child: Text('O‘zbek'),
                            ),
                          ],
                          style: const TextStyle(
                            color: Color(0xFFEAFBFF),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            _updateSettings(
                              dialogSetState,
                              () => _language = value,
                              () => GameAudioController.instance.setLanguage(
                                value,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await GameAudioController.instance
                                .playButtonSound();
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Поддержка: support@space-chicken.game',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.support_agent_rounded),
                          label: const Text('Поддержка'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFFF176),
                            side: const BorderSide(
                              color: Color(0xFFFFF176),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration({
    required IconData icon,
    required String label,
  }) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF00E5FF)),
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFFBDEFFF),
        fontWeight: FontWeight.w800,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0x9900E5FF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFF050713),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF050713),
              Color(0xFF08112A),
              Color(0xFF13051E),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const CustomPaint(painter: _StarFieldPainter()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compactHeight = constraints.maxHeight < 680;
                  final logoSize = compactHeight ? 168.0 : 220.0;

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      math.max(mediaPadding.top, 18),
                      24,
                      math.max(mediaPadding.bottom, 24),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            constraints.maxHeight -
                            mediaPadding.top -
                            mediaPadding.bottom,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          SizedBox(
                            width: logoSize,
                            height: logoSize,
                            child: const CustomPaint(painter: _LogoPainter()),
                          ),
                          const SizedBox(height: 18),
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'SPACE CHICKEN',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFEAFBFF),
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'COSMIC RUN',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFFFF176),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                          SizedBox(height: compactHeight ? 30 : 48),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                _MenuButton(
                                  icon: Icons.play_arrow_rounded,
                                  label: 'Старт',
                                  onPressed: widget.onStart,
                                  filled: true,
                                ),
                                const SizedBox(height: 14),
                                _MenuButton(
                                  icon: Icons.settings_rounded,
                                  label: 'Настройки',
                                  onPressed: _openSettings,
                                ),
                                const SizedBox(height: 14),
                                _MenuButton(
                                  icon: Icons.logout_rounded,
                                  label: 'Выход',
                                  onPressed: () async {
                                    await SystemNavigator.pop();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onPressed;
  final bool filled;

  Future<void> _handlePressed() async {
    await GameAudioController.instance.playButtonSound();
    await onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 28),
        const SizedBox(width: 10),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    final textStyle = const TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w900,
      letterSpacing: 0,
    );

    if (filled) {
      return SizedBox(
        height: 58,
        child: FilledButton(
          onPressed: _handlePressed,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: const Color(0xFF04111F),
            shape: shape,
            textStyle: textStyle,
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      height: 58,
      child: OutlinedButton(
        onPressed: _handlePressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFEAFBFF),
          side: const BorderSide(color: Color(0xFFFF2BD6), width: 1.3),
          shape: shape,
          textStyle: textStyle,
        ),
        child: child,
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: const Color(0xFF00E5FF)),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFEAFBFF),
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      value: value,
      activeThumbColor: const Color(0xFFFFF176),
      activeTrackColor: const Color(0x9900E5FF),
      inactiveThumbColor: const Color(0xFFBDEFFF),
      inactiveTrackColor: const Color(0x66071024),
      onChanged: onChanged,
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  const _StarFieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final starPaint = Paint()..color = const Color(0x99BDEFFF);
    final glowPaint = Paint()
      ..color = const Color(0x2200E5FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36);

    canvas.drawCircle(
      Offset(size.width * 0.24, size.height * 0.18),
      74,
      glowPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.72),
      96,
      glowPaint,
    );

    for (var i = 0; i < 72; i++) {
      final x = ((i * 67) % math.max(size.width.toInt(), 1)).toDouble();
      final y = ((i * 131) % math.max(size.height.toInt(), 1)).toDouble();
      final radius = i % 5 == 0 ? 1.7 : 0.9;
      canvas.drawCircle(Offset(x, y), radius, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.34;
    final glowPaint = Paint()
      ..color = const Color(0xAA00E5FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    final planetPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        colors: const <Color>[
          Color(0xFFFFF176),
          Color(0xFFFF2BD6),
          Color(0xFF8B5CF6),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    final ringPaint = Paint()
      ..color = const Color(0xFFEAFBFF)
      ..strokeWidth = size.shortestSide * 0.035
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final orbitPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = size.shortestSide * 0.018
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius + 8, glowPaint);
    canvas.drawCircle(center, radius, planetPaint);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.34);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 0.94,
        height: size.height * 0.34,
      ),
      ringPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 0.72,
        height: size.height * 0.24,
      ),
      orbitPaint,
    );
    canvas.restore();

    final beakPaint = Paint()..color = const Color(0xFFFFF176);
    final eyePaint = Paint()..color = const Color(0xFF050713);
    final wingPaint = Paint()
      ..color = const Color(0xAAFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.025
      ..strokeCap = StrokeCap.round;

    final beakPath = Path()
      ..moveTo(center.dx + radius * 0.12, center.dy - radius * 0.02)
      ..lineTo(center.dx + radius * 0.64, center.dy + radius * 0.12)
      ..lineTo(center.dx + radius * 0.12, center.dy + radius * 0.24)
      ..close();
    canvas.drawPath(beakPath, beakPaint);
    canvas.drawCircle(
      Offset(center.dx - radius * 0.22, center.dy - radius * 0.22),
      radius * 0.08,
      eyePaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx - radius * 0.12, center.dy + radius * 0.2),
        width: radius * 0.8,
        height: radius * 0.52,
      ),
      0.16,
      2.3,
      false,
      wingPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
