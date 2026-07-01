import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../audio/game_audio_controller.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({required this.url, super.key});

  final String url;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (_) async {
            await _applyMobileSupportLayout();
            if (!mounted) return;
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _applyMobileSupportLayout() async {
    try {
      await _controller.runJavaScript('''
        (function () {
          var viewport = document.querySelector('meta[name="viewport"]');
          if (!viewport) {
            viewport = document.createElement('meta');
            viewport.name = 'viewport';
            document.head.appendChild(viewport);
          }
          viewport.content = 'width=device-width, initial-scale=1, viewport-fit=cover';

          var style = document.getElementById('app-support-layout-fix');
          if (!style) {
            style = document.createElement('style');
            style.id = 'app-support-layout-fix';
            document.head.appendChild(style);
          }

          style.textContent = [
            'html, body { min-height: 100%; }',
            'body {',
            '  box-sizing: border-box;',
            '  min-height: 100vh;',
            '  display: flex;',
            '  align-items: center;',
            '  justify-content: center;',
            '  padding: 16px;',
            '}',
            '.support-container {',
            '  box-sizing: border-box;',
            '  width: 100%;',
            '  max-width: 400px;',
            '  margin: 0 auto;',
            '  padding: 24px 20px 20px;',
            '}',
            'input, textarea { box-sizing: border-box; }'
          ].join('\\n');
        })();
      ''');
    } catch (error) {
      debugPrint('SUPPORT LAYOUT FIX failed: $error');
    }
  }

  Future<void> _handleBack() async {
    await GameAudioController.instance.playButtonSound();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _handleSystemBack(bool didPop, Object? result) async {
    if (didPop) {
      return;
    }

    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handleSystemBack,
      child: Scaffold(
        backgroundColor: const Color(0xFF050713),
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              WebViewWidget(controller: _controller),
              Positioned(
                left: 12,
                top: 12,
                child: _SupportBackButton(onTap: _handleBack),
              ),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF00E5FF),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportBackButton extends StatelessWidget {
  const _SupportBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Image.asset(
          'assets/images/back.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
