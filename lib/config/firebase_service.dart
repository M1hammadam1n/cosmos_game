import 'dart:io';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'app_attribution_config.dart';
import 'config_storage.dart';

typedef PushTokenRefreshCallback = Future<void> Function(String token);
typedef NotificationOpenCallback = void Function(String? url);

class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  bool _initialized = false;
  bool _localNotificationsInitialized = false;
  String? _pushToken;
  bool _pendingNotificationOpen = false;
  String? _pendingNotificationUrl;
  PushTokenRefreshCallback? _onTokenRefresh;
  NotificationOpenCallback? _onNotificationOpen;

  bool get isInitialized => _initialized;

  String? get pushToken => _pushToken;

  bool get hasPendingNotificationOpen => _pendingNotificationOpen;

  String? get pendingNotificationUrl => _pendingNotificationUrl;

  /// Firebase Project ID for config API.
  String? get firebaseProjectId {
    if (!_initialized) {
      return null;
    }

    final options = Firebase.app().options;
    if (options.projectId.isNotEmpty) {
      return options.projectId;
    }

    return null;
  }

  String? get firebaseProjectNumber {
    if (!_initialized) {
      return null;
    }

    final messagingSenderId = Firebase.app().options.messagingSenderId;
    return messagingSenderId.isEmpty ? null : messagingSenderId;
  }

  String? get firebaseAppId {
    if (!_initialized) {
      return null;
    }

    final appId = Firebase.app().options.appId;
    return appId.isEmpty ? null : appId;
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
      _logFirebaseProjectValidation();
      await _initLocalNotifications();

      await _tryFetchToken(logLabel: 'init');

      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        _pushToken = token;
        debugPrint('FIREBASE TOKEN REFRESH: $token');
        final callback = _onTokenRefresh;
        if (callback != null) {
          await callback(token);
        }
      });

      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      _handleNotificationOpen(initialMessage);

      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    } catch (error) {
      debugPrint('Firebase init failed: $error');
    }
  }

  Future<String?> ensurePushTokenForConfig() async {
    if (!_initialized) {
      debugPrint('FIREBASE TOKEN (config): Firebase is not initialized');
      return null;
    }

    for (var attempt = 1; attempt <= 3; attempt += 1) {
      await _tryFetchToken(logLabel: 'config_attempt_$attempt');
      if (_pushToken != null && _pushToken!.isNotEmpty) {
        break;
      }

      if (attempt < 3) {
        await Future<void>.delayed(const Duration(milliseconds: 750));
      }
    }

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
      debugPrint(
        'NOTIFICATION PROMPT: hidden because Firebase is not initialized',
      );
      return false;
    }

    final settings = await getNotificationSettings();
    debugPrint('FCM PERMISSION STATUS: ${settings.authorizationStatus.name}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint(
        'NOTIFICATION PROMPT: hidden because notification permission is granted',
      );
      return false;
    }

    final skippedAt = ConfigStorage.instance.notificationPromptSkippedAt;
    if (skippedAt != null) {
      final elapsed = DateTime.now().difference(skippedAt);
      if (elapsed < AppAttributionConfig.notificationPromptRetryDelay) {
        debugPrint(
          'NOTIFICATION PROMPT: hidden because last denial/skip was '
          '${elapsed.inHours}h ago',
        );
        return false;
      }
      debugPrint(
        'NOTIFICATION PROMPT: visible because last denial/skip was more than '
        '${AppAttributionConfig.notificationPromptRetryDelay.inDays} days ago',
      );
      return true;
    }

    if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      debugPrint(
        'NOTIFICATION PROMPT: visible because system permission is not determined',
      );
      return true;
    }

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint(
        'NOTIFICATION PROMPT: visible because permission is denied and no '
        'local denial timestamp exists',
      );
      return true;
    }

    debugPrint(
      'NOTIFICATION PROMPT: hidden for permission status '
      '${settings.authorizationStatus.name}',
    );
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
      debugPrint(
        'FIREBASE TOKEN (after permission): ${_pushToken ?? "(null)"}',
      );
    } else {
      await recordNotificationPromptSkipped();
      debugPrint(
        'NOTIFICATION PROMPT: system permission was not granted; '
        'retry delayed for '
        '${AppAttributionConfig.notificationPromptRetryDelay.inDays} days',
      );
    }

    return settings;
  }

  Future<void> recordNotificationPromptSkipped() async {
    await ConfigStorage.instance.saveNotificationPromptSkippedAt(
      DateTime.now(),
    );
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
        debugPrint(
          'FIREBASE PROJECT NUMBER: ${firebaseProjectNumber ?? "(null)"}',
        );
        debugPrint('FIREBASE APP ID: ${firebaseAppId ?? "(null)"}');
      }
    } catch (error) {
      debugPrint('Firebase token fetch failed ($logLabel): $error');
    }
  }

  void _logFirebaseProjectValidation() {
    final actualProjectId = firebaseProjectId;
    if (actualProjectId == AppAttributionConfig.expectedFirebaseProjectId) {
      debugPrint('FIREBASE PROJECT VALID: $actualProjectId');
      return;
    }

    debugPrint(
      'FIREBASE PROJECT MISMATCH: app uses '
      '${actualProjectId ?? "(null)"}, but notification backend expects '
      '${AppAttributionConfig.expectedFirebaseProjectId}. Replace '
      'android/app/google-services.json and ios/Runner/GoogleService-Info.plist '
      'with files from ${AppAttributionConfig.expectedFirebaseProjectId}; '
      'otherwise check_push cannot send to this app token.',
      wrapWidth: 1024,
    );
  }

  Future<void> _initLocalNotifications() async {
    if (_localNotificationsInitialized || !Platform.isAndroid) {
      return;
    }

    final plugin = FlutterLocalNotificationsPlugin();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (details) {
        _handleNotificationUrlPayload(details.payload);
      },
    );

    _localNotificationsInitialized = true;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _initLocalNotifications();

      final notification = message.notification;
      final title = notification?.title ?? message.data['title'] as String?;
      final body = notification?.body ?? message.data['body'] as String?;
      final imageUrl = _notificationImageUrl(message);
      final style = await _bigPictureStyle(imageUrl, title, body);
      final payload = _notificationUrl(message.data);

      final androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High importance notifications',
        channelDescription: 'Notifications with offers and app updates',
        icon: 'ic_notification',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: style,
      );

      await FlutterLocalNotificationsPlugin().show(
        id: message.messageId?.hashCode ?? Random().nextInt(1 << 31),
        title: title ?? 'Egg Escape',
        body: body ?? '',
        notificationDetails: NotificationDetails(android: androidDetails),
        payload: payload,
      );

      debugPrint('FIREBASE FOREGROUND NOTIFICATION SHOWN');
    } catch (error) {
      debugPrint('Firebase foreground notification failed: $error');
    }
  }

  Future<StyleInformation?> _bigPictureStyle(
    String? imageUrl,
    String? title,
    String? body,
  ) async {
    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }

    final bytes = await _downloadNotificationImage(imageUrl);
    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    return BigPictureStyleInformation(
      ByteArrayAndroidBitmap(bytes),
      contentTitle: title,
      summaryText: body,
    );
  }

  Future<Uint8List?> _downloadNotificationImage(String imageUrl) async {
    try {
      final uri = Uri.tryParse(imageUrl);
      if (uri == null || !uri.hasScheme) {
        return null;
      }

      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'FIREBASE NOTIFICATION IMAGE FAILED: '
          'status=${response.statusCode} url=$imageUrl',
        );
        return null;
      }

      return response.bodyBytes;
    } catch (error) {
      debugPrint('Firebase notification image download failed: $error');
      return null;
    }
  }

  String? _notificationImageUrl(RemoteMessage message) {
    final androidImage = message.notification?.android?.imageUrl;
    if (androidImage != null && androidImage.isNotEmpty) {
      return androidImage;
    }

    const keys = ['image', 'imageUrl', 'picture', 'big_picture', 'bigPicture'];
    for (final key in keys) {
      final value = message.data[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  void _handleNotificationOpen(RemoteMessage? message) {
    if (message == null) {
      return;
    }

    _pendingNotificationOpen = true;

    final url = _notificationUrl(message.data);
    _handleNotificationUrlPayload(url);
  }

  String? _notificationUrl(Map<String, dynamic> data) {
    final url = data['url'] ?? data['link'];
    if (url is String && url.isNotEmpty) {
      return url;
    }

    return null;
  }

  void _handleNotificationUrlPayload(String? url) {
    _pendingNotificationOpen = true;

    if (url != null && url.isNotEmpty) {
      _pendingNotificationUrl = url;
      debugPrint('FIREBASE NOTIFICATION URL (one-shot): $url');
    } else {
      debugPrint('FIREBASE NOTIFICATION OPEN: no url in payload');
    }

    _onNotificationOpen?.call(_pendingNotificationUrl);
  }
}
