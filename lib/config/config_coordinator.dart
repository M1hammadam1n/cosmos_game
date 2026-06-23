import 'package:flutter/foundation.dart';

import 'app_attribution_config.dart';
import 'appsflyer_service.dart';
import 'config_client.dart';
import 'config_storage.dart';
import 'firebase_service.dart';

enum ConfigLaunchTarget { webView, game, offline }

class ConfigLaunchDecision {
  const ConfigLaunchDecision._({required this.target, this.url, this.reason});

  final ConfigLaunchTarget target;
  final String? url;
  final String? reason;

  factory ConfigLaunchDecision.webView(String url, {String? reason}) {
    return ConfigLaunchDecision._(
      target: ConfigLaunchTarget.webView,
      url: url,
      reason: reason,
    );
  }

  factory ConfigLaunchDecision.game({String? reason}) {
    return ConfigLaunchDecision._(
      target: ConfigLaunchTarget.game,
      reason: reason,
    );
  }

  factory ConfigLaunchDecision.offline({String? reason}) {
    return ConfigLaunchDecision._(
      target: ConfigLaunchTarget.offline,
      reason: reason,
    );
  }
}

class ConfigCoordinator {
  ConfigCoordinator._();

  static final ConfigCoordinator instance = ConfigCoordinator._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    await ConfigStorage.instance.init();
    FirebaseService.instance.setTokenRefreshCallback(
      _refreshConfigInBackground,
    );
    await FirebaseService.instance.init();
    await AppsFlyerService.instance.init();

    _initialized = true;
  }

  Future<ConfigLaunchDecision> resolveLaunchDecision() async {
    await init();

    final storage = ConfigStorage.instance;

    if (storage.configRequestsDisabled) {
      if (storage.hasCachedUrl) {
        final cachedUrl = ConfigClient.instance.ensureRequiredDeepLinkParams(
          storage.cachedUrl!,
        )!;
        final decision = ConfigLaunchDecision.webView(
          cachedUrl,
          reason: 'config_disabled_cached_fallback',
        );
        _logLaunchDecision(decision);
        return decision;
      }

      final decision = ConfigLaunchDecision.game(
        reason: 'config_disabled_no_cache',
      );
      _logLaunchDecision(decision);
      return decision;
    }

    final cachedUrl = storage.cachedUrl;
    final response = await ConfigClient.instance.fetchConfig();
    if (response.isSuccess) {
      await storage.saveConfigUrl(
        url: response.url!,
        expires: response.expires ?? 0,
      );
      final decision = ConfigLaunchDecision.webView(
        response.url!,
        reason: 'config_api_success',
      );
      _logLaunchDecision(decision);
      return decision;
    }

    if (response.isNetworkFailure && !storage.hasCachedUrl) {
      final decision = ConfigLaunchDecision.offline(
        reason: 'config_network_failed_no_cache',
      );
      _logLaunchDecision(decision);
      return decision;
    }

    if (cachedUrl != null && cachedUrl.isNotEmpty) {
      final normalizedCachedUrl = ConfigClient.instance
          .ensureRequiredDeepLinkParams(cachedUrl)!;
      final decision = ConfigLaunchDecision.webView(
        normalizedCachedUrl,
        reason: 'config_api_failed_cached_fallback',
      );
      _logLaunchDecision(decision);
      return decision;
    }

    await storage.setConfigRequestsDisabled(true);
    await storage.saveLaunchMode(AppAttributionConfig.launchModeGame);
    final decision = ConfigLaunchDecision.game(
      reason: 'config_api_failed_no_cache',
    );
    _logLaunchDecision(decision);
    return decision;
  }

  /// Sends updated push token to config after user grants notification permission.
  Future<void> refreshConfigAfterPermission() async {
    final storage = ConfigStorage.instance;
    if (storage.configRequestsDisabled) {
      return;
    }

    await FirebaseService.instance.ensurePushTokenForConfig();

    try {
      final response = await ConfigClient.instance.fetchConfig();
      if (response.isSuccess) {
        await storage.saveConfigUrl(
          url: response.url!,
          expires: response.expires ?? 0,
        );
        debugPrint('CONFIG REFRESH AFTER PERMISSION: url saved');
      } else {
        debugPrint(
          'CONFIG REFRESH AFTER PERMISSION: failed '
          'status=${response.statusCode} ok=${response.ok}',
        );
      }
    } catch (error) {
      debugPrint('CONFIG REFRESH AFTER PERMISSION failed: $error');
    }
  }

  Future<void> _refreshConfigInBackground(String token) async {
    debugPrint('FIREBASE TOKEN REFRESH: $token');
    final storage = ConfigStorage.instance;

    if (storage.configRequestsDisabled) {
      return;
    }

    try {
      final response = await ConfigClient.instance.fetchConfig();
      if (response.isSuccess) {
        await storage.saveConfigUrl(
          url: response.url!,
          expires: response.expires ?? 0,
        );
      }
    } catch (error) {
      debugPrint('Background config refresh failed: $error');
    }
  }

  void _logLaunchDecision(ConfigLaunchDecision decision) {
    if (decision.target == ConfigLaunchTarget.webView) {
      debugPrint(
        'LAUNCH MODE: webview | reason=${decision.reason} | url=${decision.url}',
      );
    } else if (decision.target == ConfigLaunchTarget.game) {
      debugPrint('LAUNCH MODE: game | reason=${decision.reason}');
    } else {
      debugPrint('LAUNCH MODE: offline | reason=${decision.reason}');
    }
  }
}
