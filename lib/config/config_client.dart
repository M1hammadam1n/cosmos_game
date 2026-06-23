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

    var changed = false;
    for (final entry in _siteQueryParams(source).entries) {
      changed = _putIfMissingOrBlank(query, entry.key, entry.value) || changed;
    }

    if (!changed) {
      return rawUrl;
    }

    final normalized = uri.replace(query: _encodedQueryString(query));
    debugPrint('CONFIG URL NORMALIZED: $normalized');
    return normalized.toString();
  }

  Future<String?> ensureRequiredDeepLinkParamsForCurrentInstall(
    String? rawUrl,
  ) async {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return rawUrl;
    }

    final body = await _buildRequestBody();
    _lastRequestBody = Map<String, dynamic>.from(body);
    return ensureRequiredDeepLinkParams(rawUrl, body);
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

  Map<String, String> _siteQueryParams(Map<String, dynamic> source) {
    final campaign = _firstValue(source, const [
      'campaign',
      'c',
      'sub_id_1',
    ], 'None');
    final mediaSource = _firstValue(source, const [
      'media_source',
      'pid',
      'sub_id_11',
    ], 'None');
    final agency = _firstValue(source, const ['agency'], '');
    final campaignId = _firstValue(source, const [
      'campaign_id',
      'af_c_id',
    ], '');
    final afId = _firstValue(source, const ['af_id', 'sub_id_10'], '');

    return <String, String>{
      'sub_id_1': campaign,
      'sub_id_2': _firstValue(source, const [
        'siteid',
        'af_siteid',
        'sub_id_2',
      ], ''),
      'sub_id_3': _firstValue(source, const ['adset', 'sub_id_3'], ''),
      'sub_id_4': _firstValue(source, const ['af_adset', 'sub_id_4'], ''),
      'sub_id_5': _firstValue(source, const [
        'bundle_id',
        'store_id',
        'sub_id_5',
      ], AppAttributionConfig.androidPackageName),
      'sub_id_7': _firstValue(source, const ['push_token', 'sub_id_7'], ''),
      'sub_id_10': afId,
      'sub_id_11': mediaSource,
      'extra_param_2': _firstValue(source, const [
        'af_sub1',
        'extra_param_2',
      ], ''),
      'extra_param_3': _firstValue(source, const [
        'af_sub2',
        'extra_param_3',
      ], ''),
      'extra_param_4': _firstValue(source, const [
        'af_sub3',
        'extra_param_4',
      ], ''),
      'extra_param_5': _firstValue(source, const [
        'af_sub4',
        'extra_param_5',
      ], ''),
      'extra_param_6': _firstValue(source, const [
        'af_sub5',
        'extra_param_6',
      ], ''),
      'extra_param_8': _firstValue(source, const [
        'adgroup',
        'extra_param_8',
      ], 'None'),
      'extra_param_7':
          'af_id=$afId&agency=$agency&campaign=$campaign'
          '&campaign_id=$campaignId&media_source=$mediaSource',
      'deep_link_value':
          _nonEmptyString(source['deep_link_value']) ??
          AppAttributionConfig.defaultDeepLinkValue,
      'deep_link_sub1':
          _nonEmptyString(source['deep_link_sub1']) ??
          _firstNonEmptyDeepLinkSub(source) ??
          AppAttributionConfig.defaultDeepLinkSub1,
      '123': '',
    };
  }

  Future<Map<String, dynamic>> _buildRequestBody() async {
    final missingReasons = <String, String>{};

    // Conversion fields are copied unchanged from AppsFlyer payload.
    final conversionData = await AppsFlyerService.instance
        .waitForConversionData();
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

    for (final entry in _siteQueryParams(body).entries) {
      body.putIfAbsent(entry.key, () => entry.value);
    }

    _logRequiredParameterStatus(body, missingReasons);

    return body;
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

  String? _firstNonEmptyDeepLinkSub(Map<String, dynamic> source) {
    for (final entry in source.entries) {
      if (!entry.key.startsWith('deep_link_sub')) {
        continue;
      }

      final value = _nonEmptyString(entry.value);
      if (value != null) {
        return value;
      }
    }

    return null;
  }

  String _firstValue(
    Map<String, dynamic> source,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final value = _nonEmptyString(source[key]);
      if (value != null) {
        return value;
      }
    }

    return fallback;
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
}
