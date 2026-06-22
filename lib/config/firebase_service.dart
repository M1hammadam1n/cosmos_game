import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'app_attribution_config.dart';
import 'config_storage.dart';

typedef PushTokenRefreshCallback = Future<void> Function(String token);
typedef NotificationOpenCallback = void Function(String? url);

class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  bool _initialized = false;
  String? _pushToken;
  bool _pendingNotificationOpen = false;
  String? _pendingNotificationUrl;
  PushTokenRefreshCallback? _onTokenRefresh;
  NotificationOpenCallback? _onNotificationOpen;

  bool get isInitialized => _initialized;

  String? get pushToken => _pushToken;

  bool get hasPendingNotificationOpen => _pendingNotificationOpen;

  String? get pendingNotificationUrl => _pendingNotificationUrl;

  /// Project number (messagingSenderId) or project ID for config API.
  String? get firebaseProjectId {
    if (!_initialized) {
      return null;
    }

    final options = Firebase.app().options;
    if (options.messagingSenderId.isNotEmpty) {
      return options.messagingSenderId;
    }

    if (options.projectId.isNotEmpty) {
      return options.projectId;
    }

    return null;
  }

  void setTokenRefreshCallback(PushTokenRefreshCallback callback) {
    _onTokenRefresh = callback;
  }

  void setNotificationOpenCallback(NotificationOpenCallback? callback) {
    _onNotificationOpen = callback;
  }

  /// Clears the pending notification-open flag after the bonus screen is shown.
  void consumePendingNotificationOpen() {
    _pendingNotificationOpen = false;
  }

  /// Returns notification URL once (not persisted). Used after bonus screen actions.
  String? consumePendingNotificationUrl() {
    final url = _pendingNotificationUrl;
    _pendingNotificationUrl = null;
    return url;
  }

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    try {
      await Firebase.initializeApp();
      _initialized = true;

      await _tryFetchToken(logLabel: 'init');

      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        _pushToken = token;
        debugPrint('FIREBASE TOKEN REFRESH: $token');
        final callback = _onTokenRefresh;
        if (callback != null) {
          await callback(token);
        }
      });

      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      _handleNotificationOpen(initialMessage);

      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);
    } catch (error) {
      debugPrint('Firebase init failed: $error');
    }
  }

  Future<String?> ensurePushTokenForConfig() async {
    if (!_initialized) {
      return null;
    }

    await _tryFetchToken(logLabel: 'config');
    debugPrint('FIREBASE TOKEN (config): ${_pushToken ?? "(null)"}');
    return _pushToken;
  }

  Future<void> refreshToken() async {
    await ensurePushTokenForConfig();
  }

  Future<NotificationSettings> getNotificationSettings() {
    return FirebaseMessaging.instance.getNotificationSettings();
  }

  Future<bool> shouldShowNotificationPrompt() async {
    if (!_initialized) {
      return false;
    }

    final settings = await getNotificationSettings();
    debugPrint(
      'FCM PERMISSION STATUS: ${settings.authorizationStatus.name}',
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      return false;
    }

    final skippedAt = ConfigStorage.instance.notificationPromptSkippedAt;
    if (skippedAt != null) {
      final elapsed = DateTime.now().difference(skippedAt);
      if (elapsed < AppAttributionConfig.notificationPromptRetryDelay) {
        return false;
      }
      return true;
    }

    if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      return true;
    }

    return false;
  }

  Future<NotificationSettings?> requestNotificationPermission() async {
    if (!_initialized) {
      return null;
    }

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      'FCM PERMISSION REQUEST: auth=${settings.authorizationStatus.name} '
      'alert=${settings.alert.name}',
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _tryFetchToken(logLabel: 'after_permission');
      debugPrint('FIREBASE TOKEN (after permission): ${_pushToken ?? "(null)"}');
    }

    return settings;
  }

  Future<void> recordNotificationPromptSkipped() async {
    await ConfigStorage.instance.saveNotificationPromptSkippedAt(DateTime.now());
    debugPrint('NOTIFICATION PROMPT: custom skip recorded');
  }

  Future<void> _tryFetchToken({required String logLabel}) async {
    try {
      if (Platform.isIOS) {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('FIREBASE APNS ($logLabel): not available yet');
        }
      }

      _pushToken = await FirebaseMessaging.instance.getToken();
      if (logLabel == 'init') {
        debugPrint('FIREBASE TOKEN: ${_pushToken ?? "(null)"}');
        debugPrint('FIREBASE PROJECT ID: ${firebaseProjectId ?? "(null)"}');
      }
    } catch (error) {
      debugPrint('Firebase token fetch failed ($logLabel): $error');
    }
  }

  void _handleNotificationOpen(RemoteMessage? message) {
    if (message == null) {
      return;
    }

    _pendingNotificationOpen = true;

    final url = message.data['url'] ?? message.data['link'];
    if (url is String && url.isNotEmpty) {
      _pendingNotificationUrl = url;
      debugPrint('FIREBASE NOTIFICATION URL (one-shot): $url');
    } else {
      debugPrint('FIREBASE NOTIFICATION OPEN: no url in payload');
    }

    _onNotificationOpen?.call(_pendingNotificationUrl);
  }
}
