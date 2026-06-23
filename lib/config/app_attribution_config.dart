/// Replace placeholder values with credentials provided by your manager.
class AppAttributionConfig {
  AppAttributionConfig._();

  static const String configUrl = 'https://spacechhicken.com/config.php';

  /// AppsFlyer dev key from the dashboard (App Settings → Dev Key).
  static const String appsFlyerDevKey = 'zooKQ2tfTiuoS8f5rEtj7g';
  static const String oneLinkTemplateId = 'tYZz';
  static const String oneLinkHost = 'spacechhicken.onelink.me';
  static const String oneLinkShortUrl =
      'https://spacechhicken.onelink.me/tYZz/09zoimcc';
  static const String oneLinkRetargetingTestUrl =
      'https://spacechhicken.onelink.me/tYZz?af_xp=custom'
      '&pid=my_media_source'
      '&is_retargeting=true'
      '&af_reengagement_window=30d'
      '&deep_link_value=home'
      '&deep_link_sub1=space_chicken';

  /// Apple App Store numeric ID without the `id` prefix (iOS only).
  static const String iosAppStoreId = 'YOUR_APP_STORE_ID';

  /// Apple App Store ID with the `id` prefix for config `store_id`.
  static const String iosStoreId = 'idYOUR_APP_STORE_ID';

  static const String androidPackageName = 'com.space_chicken';

  static const Duration conversionDataTimeout = Duration(seconds: 15);
  static const Duration configRequestTimeout = Duration(seconds: 20);

  static const String cachedUrlKey = 'config_cached_url';
  static const String cachedExpiresKey = 'config_cached_expires';
  static const String launchModeKey = 'config_launch_mode';
  static const String appsFlyerCustomerUserIdKey = 'appsflyer_customer_user_id';

  /// Legacy key – cleared on init so failed launches can retry config.
  static const String configPermanentlySkippedKey =
      'config_permanently_skipped';

  static const String configRequestsDisabledKey = 'config_requests_disabled';

  static const String notificationPromptSkippedAtKey =
      'notification_prompt_skipped_at';

  static const Duration notificationPromptRetryDelay = Duration(days: 3);

  static const String launchModeWebView = 'webview';
  static const String launchModeGame = 'game';

  static bool get isAppsFlyerDevKeyConfigured =>
      appsFlyerDevKey.isNotEmpty && appsFlyerDevKey != 'YOUR_APPSFLYER_DEV_KEY';

  static bool get isIosAppStoreIdConfigured =>
      iosAppStoreId.isNotEmpty && iosAppStoreId != 'YOUR_APP_STORE_ID';
}
