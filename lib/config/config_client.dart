import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'app_attribution_config.dart';
import 'appsflyer_service.dart';
import 'firebase_service.dart';

class ConfigResponse {
  const ConfigResponse({
    required this.ok,
    required this.statusCode,
    this.url,
    this.expires,
    this.message,
  });

  final bool ok;
  final int statusCode;
  final String? url;
  final int? expires;
  final String? message;

  bool get isSuccess =>
      statusCode == 200 && ok && url != null && url!.isNotEmpty;

  bool get isNetworkFailure => statusCode == 0;
}

class ConfigClient {
  ConfigClient._();

  static final ConfigClient instance = ConfigClient._();

  static const List<String> _requiredAppsFlyerConversionKeys = <String>[
    'campaign',
    'campaign_id',
    'media_source',
    'agency',
    'af_status',
    'af_sub1',
    'af_sub2',
    'af_sub3',
    'af_sub4',
    'af_sub5',
    'adset',
    'adset_id',
    'adgroup',
    'adgroup_id',
    'click_time',
    'install_time',
  ];

  static const List<String> _expectedDeepLinkKeys = <String>[
    'deep_link_value',
    'deep_link_sub1',
    'is_deferred',
    'match_type',
    'timestamp',
    'click_http_referrer',
  ];

  static const Map<String, String> _clientParameterSources = <String, String>{
    'af_id': 'AppsFlyer getAppsFlyerUID()',
    'bundle_id': 'PackageInfo.packageName',
    'store_id': 'PackageInfo/App Store ID',
    'os': 'dart:io Platform',
    'locale': 'PlatformDispatcher.instance.locale',
    'push_token': 'FirebaseMessaging.getToken()',
    'firebase_project_id': 'Firebase.app().options',
    'firebase_project_number': 'Firebase.app().options.messagingSenderId',
  };

  Map<String, dynamic> _lastRequestBody = const {};

  Map<String, dynamic> get lastRequestBody =>
      Map<String, dynamic>.from(_lastRequestBody);

  Future<String?> appendRequiredSiteParams(String? rawUrl) async {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return rawUrl;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme) {
      return rawUrl;
    }

    final source = await _buildSiteParameterSource();
    final query = <String, List<String>>{};
    for (final entry in uri.queryParametersAll.entries) {
      query[entry.key] = List<String>.from(entry.value);
    }

    final params = _buildSiteParams(source);
    for (final entry in params.entries) {
      query[entry.key] = <String>[entry.value];
    }

    final normalized = uri.replace(query: _encodedQueryString(query));
    debugPrint('WEBVIEW URL WITH SITE PARAMS: $normalized', wrapWidth: 1024);
    return normalized.toString();
  }

  Future<ConfigResponse> fetchConfig() async {
    final body = await _buildRequestBody();
    _lastRequestBody = Map<String, dynamic>.from(body);
    debugPrint('CONFIG ENDPOINT: ${AppAttributionConfig.configUrl}');
    debugPrint(
      'CONFIG FINAL REQUEST BODY:\n${_prettyJson(body)}',
      wrapWidth: 1024,
    );

    try {
      final response = await http
          .post(
            Uri.parse(AppAttributionConfig.configUrl),
            headers: const {
              'accept': 'application/json',
              'content-type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(AppAttributionConfig.configRequestTimeout);

      debugPrint(
        'CONFIG RESPONSE: status=${response.statusCode} body=${response.body}',
      );

      Map<String, dynamic>? payload;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        } else if (decoded is Map) {
          payload = Map<String, dynamic>.from(decoded);
        }
      } on FormatException {
        payload = null;
      }

      if (payload == null) {
        return ConfigResponse(
          ok: false,
          statusCode: response.statusCode,
          message: 'Invalid response body',
        );
      }

      final expiresRaw = payload['expires'];
      int? expires;
      if (expiresRaw is int) {
        expires = expiresRaw;
      } else if (expiresRaw is String) {
        expires = int.tryParse(expiresRaw);
      }

      final url = ensureRequiredDeepLinkParams(payload['url'] as String?, body);

      return ConfigResponse(
        ok: payload['ok'] == true,
        statusCode: response.statusCode,
        url: url,
        expires: expires,
        message: payload['message'] as String?,
      );
    } catch (error) {
      debugPrint('Config request failed: $error');
      return ConfigResponse(
        ok: false,
        statusCode: 0,
        message: error.toString(),
      );
    }
  }

  String? ensureRequiredDeepLinkParams(
    String? rawUrl, [
    Map<String, dynamic> source = const {},
  ]) {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return rawUrl;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return rawUrl;
    }

    final query = <String, List<String>>{};
    for (final entry in uri.queryParametersAll.entries) {
      query[entry.key] = List<String>.from(entry.value);
    }

    final deepLinkValue =
        _nonEmptyString(source['deep_link_value']) ??
        AppAttributionConfig.defaultDeepLinkValue;
    final deepLinkSub1 =
        _nonEmptyString(source['deep_link_sub1']) ??
        AppAttributionConfig.defaultDeepLinkSub1;

    final changed =
        _putIfMissingOrBlank(query, 'deep_link_value', deepLinkValue) |
        _putIfMissingOrBlank(query, 'deep_link_sub1', deepLinkSub1);

    if (!changed) {
      return rawUrl;
    }

    final normalized = uri.replace(query: _encodedQueryString(query));
    debugPrint('CONFIG URL NORMALIZED: $normalized');
    return normalized.toString();
  }

  String _encodedQueryString(Map<String, List<String>> query) {
    return query.entries
        .expand((entry) {
          final encodedKey = Uri.encodeQueryComponent(entry.key);
          final values = entry.value.isEmpty ? const [''] : entry.value;
          return values.map(
            (value) => '$encodedKey=${Uri.encodeQueryComponent(value)}',
          );
        })
        .join('&');
  }

  Future<Map<String, dynamic>> _buildRequestBody() async {
    final missingReasons = <String, String>{};

    // Conversion fields are copied unchanged from AppsFlyer payload.
    var conversionData = await AppsFlyerService.instance
        .waitForConversionData();
    if (_shouldUseDebugTestAttribution(conversionData)) {
      debugPrint(
        'CONFIG DEBUG TEST ATTRIBUTION: using documented Non-organic payload',
      );
      conversionData = Map<String, dynamic>.from(
        AppAttributionConfig.debugConfigTestAttribution,
      );
    }
    final body = Map<String, dynamic>.from(conversionData);
    debugPrint(
      'CONFIG APPSFLYER CONVERSION DATA:\n${_prettyJson(conversionData)}',
      wrapWidth: 1024,
    );

    if (conversionData.isEmpty) {
      missingReasons['AppsFlyer conversion data'] =
          'AppsFlyer onInstallConversionData did not return conversion fields '
          'before ${AppAttributionConfig.conversionDataTimeout.inSeconds}s '
          'timeout, or AppsFlyer returned an empty payload.';
    }

    final deepLinkData = AppsFlyerService.instance.deepLinkData;
    if (deepLinkData != null) {
      debugPrint(
        'CONFIG APPSFLYER DEEP LINK DATA:\n${_prettyJson(deepLinkData)}',
        wrapWidth: 1024,
      );
      for (final entry in deepLinkData.entries) {
        body.putIfAbsent(entry.key, () => entry.value);
      }
    } else {
      debugPrint(
        'CONFIG APPSFLYER DEEP LINK DATA: not available '
        '(UDL callback has not returned data for this launch)',
      );
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final afId = await AppsFlyerService.instance.getAppsFlyerId();
    final locale = PlatformDispatcher.instance.locale;
    final localeValue =
        locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';

    debugPrint('CONFIG APPSFLYER UID: ${afId ?? "(null)"}');

    _setRequiredValue(
      body,
      missingReasons,
      key: 'af_id',
      value: afId,
      source: _clientParameterSources['af_id']!,
    );
    _setRequiredValue(
      body,
      missingReasons,
      key: 'bundle_id',
      value: packageInfo.packageName,
      source: _clientParameterSources['bundle_id']!,
    );
    _setRequiredValue(
      body,
      missingReasons,
      key: 'locale',
      value: localeValue,
      source: _clientParameterSources['locale']!,
    );
    _setRequiredValue(
      body,
      missingReasons,
      key: 'deep_link_value',
      value:
          body['deep_link_value'] ?? AppAttributionConfig.defaultDeepLinkValue,
      source: 'AppAttributionConfig.defaultDeepLinkValue',
    );
    _setRequiredValue(
      body,
      missingReasons,
      key: 'deep_link_sub1',
      value: body['deep_link_sub1'] ?? AppAttributionConfig.defaultDeepLinkSub1,
      source: 'AppAttributionConfig.defaultDeepLinkSub1',
    );

    if (Platform.isIOS) {
      _setRequiredValue(
        body,
        missingReasons,
        key: 'os',
        value: 'iOS',
        source: _clientParameterSources['os']!,
      );
      _setRequiredValue(
        body,
        missingReasons,
        key: 'store_id',
        value: AppAttributionConfig.iosStoreId,
        source: _clientParameterSources['store_id']!,
      );
    } else if (Platform.isAndroid) {
      _setRequiredValue(
        body,
        missingReasons,
        key: 'os',
        value: 'Android',
        source: _clientParameterSources['os']!,
      );
      _setRequiredValue(
        body,
        missingReasons,
        key: 'store_id',
        value: packageInfo.packageName,
        source: _clientParameterSources['store_id']!,
      );
    } else {
      missingReasons['os'] =
          'Unsupported platform for config request: ${Platform.operatingSystem}.';
      body.putIfAbsent('os', () => null);
    }

    final firebase = FirebaseService.instance;
    if (firebase.isInitialized) {
      await firebase.ensurePushTokenForConfig();
      final pushToken = firebase.pushToken;
      final projectId = firebase.firebaseProjectId;
      final projectNumber = firebase.firebaseProjectNumber;
      debugPrint('CONFIG FIREBASE TOKEN: ${pushToken ?? "(null)"}');
      debugPrint('CONFIG FIREBASE PROJECT ID: ${projectId ?? "(null)"}');
      debugPrint(
        'CONFIG FIREBASE PROJECT NUMBER: ${projectNumber ?? "(null)"}',
      );

      _setRequiredValue(
        body,
        missingReasons,
        key: 'push_token',
        value: pushToken,
        source: _clientParameterSources['push_token']!,
      );
      _setRequiredValue(
        body,
        missingReasons,
        key: 'firebase_project_id',
        value: projectId,
        source: _clientParameterSources['firebase_project_id']!,
      );
      _setRequiredValue(
        body,
        missingReasons,
        key: 'firebase_project_number',
        value: projectNumber,
        source: _clientParameterSources['firebase_project_number']!,
      );
    } else {
      debugPrint('CONFIG FIREBASE: not initialized');
      _setRequiredValue(
        body,
        missingReasons,
        key: 'push_token',
        value: null,
        source: 'FirebaseService.init() did not complete successfully',
      );
      _setRequiredValue(
        body,
        missingReasons,
        key: 'firebase_project_id',
        value: null,
        source: 'FirebaseService.init() did not complete successfully',
      );
      _setRequiredValue(
        body,
        missingReasons,
        key: 'firebase_project_number',
        value: null,
        source: 'FirebaseService.init() did not complete successfully',
      );
    }

    _ensureAppsFlyerRequiredKeys(body, missingReasons);
    _logDeepLinkAvailability(body);

    _logRequiredParameterStatus(body, missingReasons);

    return body;
  }

  Future<Map<String, dynamic>> _buildSiteParameterSource() async {
    final source = Map<String, dynamic>.from(_lastRequestBody);
    if (AppsFlyerService.instance.isInitialized &&
        !_hasMeaningfulValue(source['campaign'])) {
      var conversionData = await AppsFlyerService.instance
          .waitForConversionData();
      if (_shouldUseDebugTestAttribution(conversionData)) {
        conversionData = Map<String, dynamic>.from(
          AppAttributionConfig.debugConfigTestAttribution,
        );
      }
      for (final entry in conversionData.entries) {
        source.putIfAbsent(entry.key, () => entry.value);
      }

      final deepLinkData = AppsFlyerService.instance.deepLinkData;
      if (deepLinkData != null) {
        for (final entry in deepLinkData.entries) {
          source.putIfAbsent(entry.key, () => entry.value);
        }
      }
    }

    final packageInfo = await PackageInfo.fromPlatform();

    source['bundle_id'] =
        _nonEmptyString(source['bundle_id']) ?? packageInfo.packageName;
    source['store_id'] =
        _nonEmptyString(source['store_id']) ?? packageInfo.packageName;
    source['af_id'] =
        _nonEmptyString(source['af_id']) ??
        await AppsFlyerService.instance.getAppsFlyerId();
    source['push_token'] =
        _nonEmptyString(source['push_token']) ??
        FirebaseService.instance.pushToken;
    source['firebase_project_id'] =
        _nonEmptyString(source['firebase_project_id']) ??
        FirebaseService.instance.firebaseProjectId;
    source['deep_link_value'] =
        _nonEmptyString(source['deep_link_value']) ??
        AppAttributionConfig.defaultDeepLinkValue;
    source['deep_link_sub1'] =
        _nonEmptyString(source['deep_link_sub1']) ??
        AppAttributionConfig.defaultDeepLinkSub1;

    return source;
  }

  Map<String, String> _buildSiteParams(Map<String, dynamic> source) {
    final campaign = _nonEmptyString(source['campaign']);
    final campaignParts = _parseCampaignParts(campaign);
    final extraParam7 = _buildNestedAttributionParam(source);

    return <String, String>{
      'sub_id_1': campaignParts.wafb,
      'sub_id_2': campaignParts.number,
      'sub_id_3': _stringOrEmpty(source['af_adset']),
      'sub_id_4': _stringOrEmpty(source['campaign_id']),
      'sub_id_5': _stringOrEmpty(source['bundle_id']),
      'sub_id_7': _stringOrEmpty(source['push_token']),
      'sub_id_10': _stringOrEmpty(source['af_id']),
      'sub_id_11': _stringOrEmpty(source['media_source']),
      'extra_param_2': _stringOrEmpty(source['af_sub1']),
      'extra_param_3': _stringOrDefault(
        source['af_sub2'],
        AppAttributionConfig.defaultSiteParamAfSub2,
      ),
      'extra_param_4': _stringOrDefault(
        source['af_sub3'],
        AppAttributionConfig.defaultSiteParamAfSub3,
      ),
      'extra_param_5': _stringOrEmpty(source['af_sub4']),
      'extra_param_6': _stringOrDefault(
        source['af_sub5'],
        AppAttributionConfig.defaultSiteParamAfSub5,
      ),
      'extra_param_7': extraParam7,
      'extra_param_8': campaign ?? '',
      'deep_link_value': _stringOrEmpty(source['deep_link_value']),
      'deep_link_sub1': _stringOrEmpty(source['deep_link_sub1']),
      '123': AppAttributionConfig.defaultSiteParam123,
    };
  }

  ({String wafb, String number}) _parseCampaignParts(String? campaign) {
    if (campaign == null || campaign.isEmpty) {
      return (wafb: '', number: '');
    }

    final parts = campaign.split('_');
    final number = parts.length > 1 ? parts[1] : '';
    final wafbMatch = RegExp(
      r'wafb',
      caseSensitive: false,
    ).firstMatch(campaign);
    return (wafb: wafbMatch?.group(0) ?? '', number: number);
  }

  String _buildNestedAttributionParam(Map<String, dynamic> source) {
    final params = <String, String>{
      'af_id': _stringOrEmpty(source['af_id']),
      'agency': _stringOrEmpty(source['agency']),
      'campaign': _stringOrEmpty(source['campaign']),
      'campaign_id': _stringOrEmpty(source['campaign_id']),
      'media_source': _stringOrEmpty(source['media_source']),
    };

    return params.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}='
              '${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
  }

  bool _shouldUseDebugTestAttribution(Map<String, dynamic> conversionData) {
    if (!kDebugMode || !AppAttributionConfig.enableDebugConfigTestAttribution) {
      return false;
    }

    return _nonEmptyString(conversionData['af_status']) != 'Non-organic';
  }

  bool _putIfMissingOrBlank(
    Map<String, List<String>> query,
    String key,
    String value,
  ) {
    final values = query[key];
    if (values != null &&
        values.isNotEmpty &&
        values.any((item) => item.trim().isNotEmpty)) {
      return false;
    }

    query[key] = <String>[value];
    return true;
  }

  void _ensureAppsFlyerRequiredKeys(
    Map<String, dynamic> body,
    Map<String, String> missingReasons,
  ) {
    for (final key in _requiredAppsFlyerConversionKeys) {
      if (!body.containsKey(key)) {
        body[key] = null;
        missingReasons[key] =
            'Missing from AppsFlyer conversion data. Expected source: '
            'onInstallConversionData payload field "$key".';
        continue;
      }

      if (!_hasMeaningfulValue(body[key])) {
        missingReasons.putIfAbsent(
          key,
          () =>
              'AppsFlyer conversion data included "$key", but its value is '
              '${body[key] == null ? "null" : "empty"}.',
        );
      }
    }
  }

  void _setRequiredValue(
    Map<String, dynamic> target,
    Map<String, String> missingReasons, {
    required String key,
    required Object? value,
    required String source,
  }) {
    final stringValue = _nonEmptyString(value);
    if (stringValue != null) {
      target[key] = stringValue;
      return;
    }

    if (_hasMeaningfulValue(target[key])) {
      return;
    }

    target[key] = null;
    missingReasons[key] = 'Missing or empty. Expected source: $source.';
  }

  void _logDeepLinkAvailability(Map<String, dynamic> body) {
    for (final key in _expectedDeepLinkKeys) {
      if (body.containsKey(key)) {
        debugPrint('CONFIG UDL PARAM: $key=${body[key]}');
      } else {
        debugPrint(
          'CONFIG UDL PARAM MISSING: $key '
          '(source: AppsFlyer Unified Deep Linking callback)',
        );
      }
    }
  }

  void _logRequiredParameterStatus(
    Map<String, dynamic> body,
    Map<String, String> missingReasons,
  ) {
    final requiredKeys = <String>{
      ..._requiredAppsFlyerConversionKeys,
      ..._clientParameterSources.keys,
    };

    var allAvailable = true;
    for (final key in requiredKeys) {
      if (_hasMeaningfulValue(body[key])) {
        debugPrint('CONFIG REQUIRED PARAM OK: $key=${body[key]}');
        continue;
      }

      allAvailable = false;
      debugPrint(
        'CONFIG REQUIRED PARAM MISSING: $key | '
        '${missingReasons[key] ?? "Expected source is not available."}',
      );
    }

    if (allAvailable) {
      debugPrint('CONFIG REQUIRED PARAMS: all required parameters are present');
    }
  }

  bool _hasMeaningfulValue(Object? value) {
    if (value == null) {
      return false;
    }

    if (value is String) {
      return value.trim().isNotEmpty;
    }

    return true;
  }

  String _prettyJson(Object? value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  String? _nonEmptyString(Object? value) {
    if (value == null) {
      return null;
    }

    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }

  String _stringOrEmpty(Object? value) => _nonEmptyString(value) ?? '';

  String _stringOrDefault(Object? value, String fallback) =>
      _nonEmptyString(value) ?? fallback;
}
