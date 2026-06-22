import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  static const Duration displayDuration = Duration(milliseconds: 2500);

  @override
  Widget build(BuildContext context) {
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFF050713),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            'assets/images/Background 2.png',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 120.0 : 40.0,
                vertical: isLandscape ? 20.0 : 40.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),
                  // Animated Loading Indicator
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                      strokeWidth: 4.0,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Loading image/text
                  SizedBox(
                    height: isLandscape ? 40 : 60,
                    child: Image.asset(
                      'assets/images/loading.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: isLandscape ? 10 : 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
