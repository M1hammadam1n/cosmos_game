import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget that enforces allowed device orientations based on available width.
///
/// If the available max width is smaller than [minLandscapeWidth], landscape
/// orientations are disabled globally (app will stay in portrait). This is a
/// heuristic to prevent layouts that can't fit in horizontal mode from being
/// shown. Choose [minLandscapeWidth] according to your widest layout needs.
class OrientationEnforcer extends StatefulWidget {
  const OrientationEnforcer({
    required this.child,
    this.minLandscapeWidth = 700.0,
    super.key,
  });

  final Widget child;

  /// Minimum width (in logical pixels) required to allow landscape.
  final double minLandscapeWidth;

  @override
  State<OrientationEnforcer> createState() => _OrientationEnforcerState();
}

class _OrientationEnforcerState extends State<OrientationEnforcer> {
  bool _landscapeAllowed = true;

  Future<void> _updateOrientationIfNeeded(double maxWidth) async {
    final shouldAllowLandscape = maxWidth >= widget.minLandscapeWidth;
    if (shouldAllowLandscape == _landscapeAllowed) return;
    _landscapeAllowed = shouldAllowLandscape;

    if (shouldAllowLandscape) {
      await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Schedule orientation update after layout to get correct constraints.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateOrientationIfNeeded(constraints.maxWidth);
        });
        return widget.child;
      },
    );
  }
}
