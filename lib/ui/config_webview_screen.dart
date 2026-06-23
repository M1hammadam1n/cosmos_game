import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
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

class _ConfigWebViewScreenState extends State<ConfigWebViewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _canGoBack = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF050713));

    // Resolve and set a clean User Agent that doesn't indicate webview
    String? userAgent;
    if (Platform.isIOS) {
      userAgent =
          'Mozilla/5.0 (iPhone; CPU iPhone OS 18_1_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';
    } else if (Platform.isAndroid) {
      final rawUA = await ExternalLinkLauncher.getDefaultUserAgent();
      if (rawUA != null && rawUA.isNotEmpty) {
        // Clean out webview indicators "; wv" and "Version/X.X"
        userAgent = rawUA
            .replaceAll(RegExp(r';\s*wv'), '')
            .replaceAll(RegExp(r'Version/\d+\.\d+\s*'), '');
      } else {
        // High-quality fallback user agent for Android
        userAgent =
            'Mozilla/5.0 (Linux; Android 13; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';
      }
    }

    if (userAgent != null) {
      await controller.setUserAgent(userAgent);
      debugPrint('SETTING USER AGENT: $userAgent');
    }

    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (_) {
          if (!mounted) {
            return;
          }
          setState(() => _isLoading = true);
        },
        onPageFinished: (_) => _refreshNavigationState(),
        onWebResourceError: (error) {
          debugPrint(
            'WEBVIEW ERROR: ${error.errorCode} ${error.description} '
            'url=${error.url}',
          );
          // Handle ERR_TOO_MANY_REDIRECTS (-1007 on iOS, -9 or 0 on Android)
          if (error.errorCode == -1007 ||
              error.errorCode == -9 ||
              error.errorCode == 0) {
            final failingUrl = error.url;
            if (failingUrl != null && failingUrl.isNotEmpty) {
              _controller?.loadRequest(Uri.parse(failingUrl));
              return;
            }
          }
          if (!mounted) {
            return;
          }
          setState(() => _isLoading = false);
        },
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null) {
            return NavigationDecision.prevent;
          }

          if (_shouldOpenExternally(uri)) {
            _openExternal(uri);
            return NavigationDecision.prevent;
          }

          return NavigationDecision.navigate;
        },
        onUrlChange: (_) => _refreshNavigationState(),
      ),
    );

    if (Platform.isAndroid && controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      await androidController.setMediaPlaybackRequiresUserGesture(false);
      await androidController.setOnShowFileSelector(_androidFilePicker);
      // Auto-grant protected content access and camera/mic permissions
      await androidController.setOnPlatformPermissionRequest((request) {
        debugPrint('WebView Android permission request: $request');
        request.grant();
      });
    }

    debugPrint('WEBVIEW LOAD URL: ${widget.url}');
    await controller.loadRequest(Uri.parse(widget.url));

    if (!mounted) {
      return;
    }

    setState(() {
      _controller = controller;
    });
  }

  Future<void> _refreshNavigationState() async {
    final controller = _controller;
    if (controller == null || !mounted) {
      return;
    }

    final canGoBack = await controller.canGoBack();
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _canGoBack = canGoBack;
    });
  }

  bool _shouldOpenExternally(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'http' ||
        scheme == 'https' ||
        scheme == 'about' ||
        scheme == 'javascript') {
      return false;
    }
    // Any other custom scheme should be opened externally (whatsapp, tg, mailto, tel, sms, intent, etc.)
    return true;
  }

  Future<void> _openExternal(Uri uri) async {
    final opened = await ExternalLinkLauncher.open(uri.toString());
    if (!opened) {
      debugPrint('WEBVIEW EXTERNAL URL NOT HANDLED: $uri');
    }
  }

  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    try {
      final acceptedTypeGroups = _acceptedTypeGroupsFor(params);
      debugPrint(
        'WEBVIEW FILE PICKER: mode=${params.mode.name} '
        'capture=${params.isCaptureEnabled} accept=${params.acceptTypes}',
      );

      if (params.mode == FileSelectorMode.openMultiple) {
        final files = await openFiles(acceptedTypeGroups: acceptedTypeGroups);
        return files.map((file) => _webViewFileUri(file.path)).toList();
      }

      final file = await openFile(acceptedTypeGroups: acceptedTypeGroups);
      if (file == null) {
        return const [];
      }

      return <String>[_webViewFileUri(file.path)];
    } catch (e) {
      debugPrint('File selector error: $e');
      return const [];
    }
  }

  String _webViewFileUri(String path) {
    if (path.startsWith('content://') || path.startsWith('file://')) {
      return path;
    }

    return Uri.file(path).toString();
  }

  List<XTypeGroup> _acceptedTypeGroupsFor(FileSelectorParams params) {
    final mimeTypes = params.acceptTypes
        .map((type) => type.trim())
        .where((type) => type.isNotEmpty && type != '*/*')
        .toSet()
        .toList();

    if (mimeTypes.isEmpty) {
      return const <XTypeGroup>[XTypeGroup(label: 'All files')];
    }

    return <XTypeGroup>[
      XTypeGroup(label: 'Accepted files', mimeTypes: mimeTypes),
    ];
  }

  Future<void> _handleBack() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
    }
    // If we cannot go back (i.e. on the first page), we do nothing.
    // This prevents the WebView from being closed.
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF050713),
        body: SafeArea(
          child: Stack(
            children: [
              if (controller != null) WebViewWidget(controller: controller),
              if (_isLoading || controller == null)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                ),
              if (_canGoBack)
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _handleBack,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
