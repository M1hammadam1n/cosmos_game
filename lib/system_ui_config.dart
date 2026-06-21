import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> configureImmersiveSystemUi() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );
}

/// Keeps status and navigation bars hidden; swipe from screen edge reveals them.
class ImmersiveSystemUiScope extends StatefulWidget {
  const ImmersiveSystemUiScope({required this.child, super.key});

  final Widget child;

  @override
  State<ImmersiveSystemUiScope> createState() => _ImmersiveSystemUiScopeState();
}

class _ImmersiveSystemUiScopeState extends State<ImmersiveSystemUiScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    configureImmersiveSystemUi();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      configureImmersiveSystemUi();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
