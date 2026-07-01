import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../external_link_launcher.dart';
import '../system_ui_config.dart';

class ConfigWebViewScreen extends StatefulWidget {
  const ConfigWebViewScreen({
    super.key,
    required this.url,
    required this.onExit,
  });

  final String url;
  final VoidCallback onExit;

  @override
  State<ConfigWebViewScreen> createState() => _ConfigWebViewScreenState();
}

class _ConfigWebViewScreenState extends State<ConfigWebViewScreen>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    unawaited(configureWebViewSystemUi());

    _initWebView();
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      unawaited(_cleanupWebViewStorage(controller, clearLocalStorage: true));
    }
    WidgetsBinding.instance.removeObserver(this);
    unawaited(configureImmersiveSystemUi());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(configureWebViewSystemUi());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      final controller = _controller;
      if (controller != null) {
        unawaited(_cleanupWebViewStorage(controller));
      }
    }
  }

  Future<void> _initWebView() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black);

    await _cleanupWebViewStorage(controller, clearLocalStorage: true);

    String? userAgent;

    if (Platform.isIOS) {
      userAgent =
          'Mozilla/5.0 (iPhone; CPU iPhone OS 18_1_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';
    } else if (Platform.isAndroid) {
      final rawUA = await ExternalLinkLauncher.getDefaultUserAgent();

      if (rawUA != null && rawUA.isNotEmpty) {
        userAgent = rawUA
            .replaceAll(RegExp(r';\s*wv'), '')
            .replaceAll(RegExp(r'Version/\d+\.\d+\s*'), '');
      }
    }

    if (userAgent != null) {
      await controller.setUserAgent(userAgent);
    }

    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (_) {
          if (!mounted) return;

          setState(() {
            _isLoading = true;
          });
        },
        onPageFinished: (_) async {
          if (!mounted) return;

          await _applyOfferLayoutFix(controller);
          if (!mounted) return;

          unawaited(_cleanupWebViewStorage(controller));

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
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);

          if (uri == null) {
            return NavigationDecision.prevent;
          }

          final scheme = uri.scheme.toLowerCase();

          if (scheme != 'http' &&
              scheme != 'https' &&
              scheme != 'about' &&
              scheme != 'javascript') {
            _openExternal(uri);
            return NavigationDecision.prevent;
          }

          return NavigationDecision.navigate;
        },
      ),
    );

    if (Platform.isAndroid && controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;

      await androidController.setMediaPlaybackRequiresUserGesture(false);

      await androidController.setOnShowFileSelector(_androidFilePicker);

      await androidController.setOnPlatformPermissionRequest((request) {
        request.grant();
      });
    }

    await controller.loadRequest(Uri.parse(widget.url));

    if (!mounted) return;

    setState(() {
      _controller = controller;
    });
  }

  Future<void> _cleanupWebViewStorage(
    WebViewController controller, {
    bool clearLocalStorage = false,
  }) async {
    try {
      await controller.clearCache();
      if (clearLocalStorage) {
        await controller.clearLocalStorage();
      }
    } catch (error) {
      debugPrint('WEBVIEW STORAGE CLEANUP failed: $error');
    }
  }

  Future<void> _applyOfferLayoutFix(WebViewController controller) async {
    try {
      await controller.runJavaScript(r'''
        (function () {
          var viewport = document.querySelector('meta[name="viewport"]');
          if (!viewport) {
            viewport = document.createElement('meta');
            viewport.name = 'viewport';
            document.head.appendChild(viewport);
          }
          viewport.content = 'width=device-width, initial-scale=1, viewport-fit=cover';

          var style = document.getElementById('app-webview-landscape-form-fix');
          if (!style) {
            style = document.createElement('style');
            style.id = 'app-webview-landscape-form-fix';
            document.head.appendChild(style);
          }

          style.textContent = [
            'html, body {',
            '  max-width: 100%;',
            '  overflow-x: hidden !important;',
            '  -webkit-text-size-adjust: 100%;',
            '}',
            'input, select, textarea, button {',
            '  box-sizing: border-box;',
            '  max-width: 100%;',
            '  scroll-margin-top: 24px;',
            '  scroll-margin-bottom: 120px;',
            '}',
            '@media (orientation: landscape) and (max-height: 520px) {',
            '  html, body {',
            '    height: auto !important;',
            '    min-height: 100% !important;',
            '    overflow-y: auto !important;',
            '    overscroll-behavior-y: contain;',
            '    -webkit-overflow-scrolling: touch;',
            '  }',
            '  body {',
            '    padding-bottom: max(24px, env(safe-area-inset-bottom)) !important;',
            '  }',
            '  form, [class*="form" i], [id*="form" i],',
            '  [class*="registration" i], [id*="registration" i],',
            '  [class*="signup" i], [id*="signup" i],',
            '  [class*="modal" i], [id*="modal" i] {',
            '    max-height: none !important;',
            '    overflow: visible !important;',
            '  }',
            '}'
          ].join('\n');

          function keepFocusedFieldVisible(event) {
            var target = event.target;
            if (!target || !target.matches || !target.matches('input, select, textarea')) {
              return;
            }

            setTimeout(function () {
              try {
                target.scrollIntoView({
                  behavior: 'smooth',
                  block: 'center',
                  inline: 'nearest'
                });
              } catch (_) {
                target.scrollIntoView(false);
              }
            }, 120);
          }

          if (!window.__appWebViewLandscapeFormFixInstalled) {
            window.__appWebViewLandscapeFormFixInstalled = true;
            document.addEventListener('focusin', keepFocusedFieldVisible, true);
            window.addEventListener('orientationchange', function () {
              setTimeout(function () {
                var focused = document.activeElement;
                if (focused && focused.matches && focused.matches('input, select, textarea')) {
                  keepFocusedFieldVisible({ target: focused });
                }
              }, 300);
            });
          }
        })();
      ''');
    } catch (error) {
      debugPrint('WEBVIEW OFFER LAYOUT FIX failed: $error');
    }
  }

  Future<void> _openExternal(Uri uri) async {
    await ExternalLinkLauncher.open(uri.toString());
  }

  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    try {
      final groups = _acceptedTypeGroupsFor(params);

      if (params.mode == FileSelectorMode.openMultiple) {
        final files = await openFiles(acceptedTypeGroups: groups);

        return files.map((file) => Uri.file(file.path).toString()).toList();
      }

      final file = await openFile(acceptedTypeGroups: groups);

      if (file == null) {
        return const [];
      }

      return [Uri.file(file.path).toString()];
    } catch (_) {
      return const [];
    }
  }

  List<XTypeGroup> _acceptedTypeGroupsFor(FileSelectorParams params) {
    final mimeTypes = params.acceptTypes
        .where((e) => e.isNotEmpty && e != '*/*')
        .toList();

    if (mimeTypes.isEmpty) {
      return const [XTypeGroup(label: 'All files')];
    }

    return [XTypeGroup(label: 'Files', mimeTypes: mimeTypes)];
  }

  Future<void> _handleBack() async {
    final controller = _controller;

    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: SizedBox.expand(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_controller != null)
                    WebViewWidget(controller: _controller!),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
