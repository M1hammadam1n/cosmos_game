import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../audio/game_audio_controller.dart';

const List<DeviceOrientation> _portraitOrientations = <DeviceOrientation>[
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

const List<DeviceOrientation> _bonusNotificationOrientations =
    <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ];

class BonusNotificationScreen extends StatefulWidget {
  const BonusNotificationScreen({
    super.key,
    required this.onBonusPressed,
    required this.onDismiss,
  });

  final VoidCallback onBonusPressed;
  final VoidCallback onDismiss;

  @override
  State<BonusNotificationScreen> createState() =>
      _BonusNotificationScreenState();
}

class _BonusNotificationScreenState extends State<BonusNotificationScreen> {
  static const Color _background = Color(0xFF050713);

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(_bonusNotificationOrientations);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(_portraitOrientations);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            isLandscape
                ? 'assets/images/BGforNotifications_gorezantal.jpg'
                : 'assets/images/BGforNotifications.jpg',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Spacer(flex: isLandscape ? 70 : 20),

                  Image.asset(
                    isLandscape
                        ? 'assets/images/Allow notifications about bonuses and promos_2.png'
                        : 'assets/images/Allow notifications about bonuses and promos.png',
                    height: isLandscape ? 15 : 40,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 20),

                  Image.asset(
                    isLandscape
                        ? 'assets/images/Stay tuned with best offers from our casino_2.png'
                        : 'assets/images/Stay tuned with best offers from our casino.png',
                    height: isLandscape ? 16 : 20,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 12),
                  Text(
                    'This app uses a push token and app usage data to deliver bonus notifications and improve the experience. You can review the privacy policy in Settings.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.moul(
                      color: const Color.fromARGB(45, 255, 255, 255),
                      fontSize: isLandscape ? 18 : 14,
                    ),
                  ),

                  const Spacer(flex: 3),

                  _BonusButton(
                    onPressed: () async {
                      await GameAudioController.instance.playButtonSound();
                      widget.onBonusPressed();
                    },
                    child: Image.asset(
                      isLandscape
                          ? 'assets/images/Rectangle 4076_2.png'
                          : 'assets/images/Rectangle 4077.png',
                      fit: BoxFit.cover,
                      width: isLandscape ? 465 : 30,
                      height: 50,
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () async {
                      await GameAudioController.instance.playButtonSound();
                      widget.onDismiss();
                    },
                    child: Text(
                      'Skip',
                      style: GoogleFonts.moul(
                        color: Colors.white54,
                        fontSize: isLandscape ? 30 : 25,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BonusButton extends StatelessWidget {
  const _BonusButton({required this.onPressed, this.child});

  final VoidCallback onPressed;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 280,
          child:
              child ??
              Text(
                'Bonus',
                textAlign: TextAlign.center,
                style: GoogleFonts.moul(
                  color: const Color(0xFF2A1B00),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
        ),
      ),
    );
  }
}
