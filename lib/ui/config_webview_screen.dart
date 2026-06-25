import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../external_link_launcher.dart';

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

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        systemNavigationBarColor: Colors.black,
      ),
    );

    _initWebView();
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      unawaited(_cleanupWebViewStorage(controller, clearLocalStorage: true));
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
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
        onPageFinished: (_) {
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: SizedBox.expand(
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
    );
  }
}
