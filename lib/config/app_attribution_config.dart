/// Replace placeholder values with credentials provided by your manager.
class AppAttributionConfig {
  AppAttributionConfig._();

  static const String siteUrl = 'https://spacechhicken.com';
  static const String configUrl = 'https://spacechhicken.com/config.php';
  static const bool enableBackendWebView = true;

  static const String appsFlyerDevKey = 'zooKQ2tfTiuoS8f5rEtj7g';
  static const String oneLinkTemplateId = 'tYZz';
  static const String oneLinkHost = 'spacechhicken.onelink.me';
  static const String oneLinkShortUrl =
      'https://spacechhicken.onelink.me/tYZz/9u1rjpxy';
  static const String appsFlyerAttributionTestUrl =
      'https://app.appsflyer.com/com.space_chicken'
      '?pid=Test%20Source'
      '&c=testsub_testsub2_testsub_testsub_testsub_testsub_testsub_testsub1%20%23extra'
      '&siteid=syndicate_g'
      '&adset=testsub'
      '&af_adset=testsub3'
      '&af_c_id=testsub4'
      '&agency=Test%20Agency'
      '&af_sub1=testextra2'
      '&af_sub2=testextra3'
      '&af_sub3=testextra4'
      '&af_sub4=testextra5'
      '&af_sub5=testextra6'
      '&is_retargeting=true'
      '&deep_link_value=home'
      '&deep_link_sub1=space_chicken'
      '&advertising_id=';

  static const String defaultDeepLinkValue = 'deep_link_test';
  static const String defaultDeepLinkSub1 = 'deep_test_sub1';

  /// Enables documented non-organic attribution payload for debug builds when
  /// AppsFlyer does not return a non-organic conversion.
  static const bool enableDebugConfigTestAttribution = true;

  static const Map<String, Object?> debugConfigTestAttribution =
      <String, Object?>{
        'adset': 's1s3',
        'af_adset': 'mm3',
        'adgroup': 's1s3',
        'campaign_id': '6068535534218',
        'af_status': 'Non-organic',
        'agency': 'Test',
        'af_sub3': 'testextra4',
        'af_siteid': null,
        'adset_id': '6073532011618',
        'is_fb': true,
        'is_first_launch': true,
        'click_time': '2017-07-18 12:55:05',
        'iscache': false,
        'ad_id': '6074245540018',
        'af_sub1': '439223',
        'campaign': 'Comp_22_GRTRMiOS_111123212_US_iOS_GSLTS_wafb unlim access',
        'is_paid': true,
        'af_sub4': '01',
        'adgroup_id': '6073532011418',
        'is_mobile_data_terms_signed': true,
        'af_channel': 'Facebook',
        'af_sub5': 'testextra6',
        'media_source': 'Facebook Ads',
        'install_time': '2017-07-19 08:06:56.189',
        'af_sub2': 'testextra3',
      };

  static const String defaultSiteParamAfSub2 = 'testextra3';
  static const String defaultSiteParamAfSub3 = 'testextra4';
  static const String defaultSiteParamAfSub5 = 'testextra6';
  static const String defaultSiteParam123 = '123';

  /// Apple App Store numeric ID without the `id` prefix (iOS only).
  static const String iosAppStoreId = 'YOUR_APP_STORE_ID';

  /// Apple App Store ID with the `id` prefix for config `store_id`.
  static const String iosStoreId = 'idYOUR_APP_STORE_ID';

  static const String androidPackageName = 'com.space_chicken';
  static const String expectedFirebaseProjectId = 'marfa-290610-efa21';

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
