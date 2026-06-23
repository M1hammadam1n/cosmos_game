import 'package:shared_preferences/shared_preferences.dart';

import 'app_attribution_config.dart';

class ConfigStorage {
  ConfigStorage._();

  static final ConfigStorage instance = ConfigStorage._();

  SharedPreferences? _preferences;

  Future<void> init() async {
    _preferences ??= await SharedPreferences.getInstance();
    await _migrateLegacySkipFlag();
  }

  String? get cachedUrl =>
      _preferences?.getString(AppAttributionConfig.cachedUrlKey);

  int? get cachedExpires =>
      _preferences?.getInt(AppAttributionConfig.cachedExpiresKey);

  String? get launchMode =>
      _preferences?.getString(AppAttributionConfig.launchModeKey);

  bool get hasCachedUrl => cachedUrl != null && cachedUrl!.isNotEmpty;

  bool get isCachedUrlValid {
    final url = cachedUrl;
    final expires = cachedExpires;
    if (url == null || url.isEmpty || expires == null || expires <= 0) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now < expires;
  }

  bool get isWebViewMode =>
      launchMode == AppAttributionConfig.launchModeWebView && hasCachedUrl;

  bool get configRequestsDisabled =>
      _preferences?.getBool(AppAttributionConfig.configRequestsDisabledKey) ??
      false;

  DateTime? get notificationPromptSkippedAt {
    final millis = _preferences?.getInt(
      AppAttributionConfig.notificationPromptSkippedAtKey,
    );
    if (millis == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setConfigRequestsDisabled(bool disabled) async {
    await init();
    await _preferences!.setBool(
      AppAttributionConfig.configRequestsDisabledKey,
      disabled,
    );
  }

  Future<void> saveNotificationPromptSkippedAt(DateTime time) async {
    await init();
    await _preferences!.setInt(
      AppAttributionConfig.notificationPromptSkippedAtKey,
      time.millisecondsSinceEpoch,
    );
  }

  Future<void> saveConfigUrl({
    required String url,
    required int expires,
  }) async {
    await init();
    await _preferences!.setString(AppAttributionConfig.cachedUrlKey, url);
    await _preferences!.setInt(AppAttributionConfig.cachedExpiresKey, expires);
    await saveLaunchMode(AppAttributionConfig.launchModeWebView);
  }

  Future<void> saveLaunchMode(String mode) async {
    await init();
    await _preferences!.setString(AppAttributionConfig.launchModeKey, mode);
  }

  Future<void> clearCachedConfig() async {
    await init();
    await _preferences!.remove(AppAttributionConfig.cachedUrlKey);
    await _preferences!.remove(AppAttributionConfig.cachedExpiresKey);
    await _preferences!.remove(AppAttributionConfig.launchModeKey);
  }

  Future<void> _migrateLegacySkipFlag() async {
    final skipped = _preferences?.getBool(
      AppAttributionConfig.configPermanentlySkippedKey,
    );
    if (skipped == true) {
      await _preferences!.remove(
        AppAttributionConfig.configPermanentlySkippedKey,
      );
      await saveLaunchMode(AppAttributionConfig.launchModeGame);
    }
  }
}
