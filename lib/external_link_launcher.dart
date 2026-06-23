import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalLinkLauncher {
  ExternalLinkLauncher._();

  static const MethodChannel _androidChannel = MethodChannel(
    'space_chicken/links',
  );

  static Future<bool> open(String url) async {
    final uri = Uri.parse(url);

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final opened = await _androidChannel.invokeMethod<bool>('openUrl', {
          'url': url,
        });
        if (opened == true) {
          return true;
        }
      } on PlatformException {
        // Fall through to url_launcher.
      }
    }

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (error) {
      debugPrint('External link open failed: $url ($error)');
      return false;
    }
  }

  static Future<String?> getDefaultUserAgent() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        return await _androidChannel.invokeMethod<String>(
          'getDefaultUserAgent',
        );
      } catch (e) {
        debugPrint('Failed to get default user agent: $e');
        return null;
      }
    }
    return null;
  }
}
