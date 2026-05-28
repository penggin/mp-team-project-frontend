import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'category_mapper.dart';

class ApiService {
  static const String baseUrl = 'http://penggin.iptime.org:2543';
  static const String defaultPhoneLocale = 'ko-KR';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _accessTokenExpiresAtKey = 'access_token_expires_at';
  static const String _refreshTokenExpiresAtKey = 'refresh_token_expires_at';
  static const Duration _refreshTokenRenewalThreshold = Duration(days: 3);

  /// 토큰이 완전히 만료돼 더 이상 갱신할 수 없을 때 호출되는 콜백.
  /// main.dart에서 로그인 화면으로 이동하도록 등록해두면 됨.
  static void Function()? onAuthExpired;

  static http.Client _httpClient = http.Client();

  static Future<SharedPreferences> _freshPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  static Future<String?> getAccessToken() async {
    final prefs = await _freshPreferences();
    return prefs.getString(_accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await _freshPreferences();
    return prefs.getString(_refreshTokenKey);
  }

  static void setHttpClientForTest(http.Client client) {
    _httpClient = client;
  }

  static void resetHttpClientForTest() {
    _httpClient = http.Client();
  }

  static Uri _uriFor(String endpoint) {
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      return Uri.parse(endpoint);
    }

    final separator = endpoint.startsWith('/') ? '' : '/';
    return Uri.parse('$baseUrl$separator$endpoint');
  }

  static String _endpointWithQuery(
    String path,
    Map<String, dynamic> queryParameters,
  ) {
    final filtered = Map<String, String>.fromEntries(
      queryParameters.entries
          .where((entry) => entry.value != null)
          .map((entry) => MapEntry(entry.key, entry.value.toString())),
    );
    return Uri(
      path: path,
      queryParameters: filtered.isEmpty ? null : filtered,
    ).toString();
  }

  static Future<Map<String, String>> _headers({
    required bool requiresAuth,
  }) async {
    final token = requiresAuth ? await getAccessToken() : null;
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> _sendRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    required bool requiresAuth,
  }) async {
    final uri = _uriFor(endpoint);
    final headers = await _headers(requiresAuth: requiresAuth);
    final encodedBody = body == null ? null : jsonEncode(body);

    switch (method.toUpperCase()) {
      case 'GET':
        return _httpClient.get(uri, headers: headers);
      case 'POST':
        return _httpClient.post(uri, headers: headers, body: encodedBody);
      case 'PUT':
        return _httpClient.put(uri, headers: headers, body: encodedBody);
      case 'PATCH':
        return _httpClient.patch(uri, headers: headers, body: encodedBody);
      case 'DELETE':
        return _httpClient.delete(uri, headers: headers, body: encodedBody);
      default:
        throw ArgumentError('지원하지 않는 HTTP 메서드입니다: $method');
    }
  }

  static Map<String, dynamic>? _decodeResponse(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    if (body.isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true};
      }
      return null;
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);

    return {
      'success': response.statusCode >= 200 && response.statusCode < 300,
      'data': decoded,
    };
  }

  static Future<bool> _saveTokensFromResponse(
    Map<String, dynamic>? response, {
    String? fallbackRefreshToken,
  }) async {
    final data = response?['data'];
    if (data is! Map) return false;

    final accessToken = _stringValue(data['access_token']);
    final refreshToken =
        _stringValue(data['refresh_token']) ?? fallbackRefreshToken;
    if (accessToken is! String || accessToken.isEmpty) return false;
    if (refreshToken is! String || refreshToken.isEmpty) return false;

    await saveTokens(
      accessToken,
      refreshToken,
      accessTokenExpiresAt: _stringValue(data['access_token_expires_at']),
      refreshTokenExpiresAt: _stringValue(data['refresh_token_expires_at']),
    );
    return true;
  }

  static bool _isSuccessfulResponse(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['success'] == true) return true;
    return data['success'] == null && data.containsKey('data');
  }

  static String? _stringValue(Object? value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static DateTime? _parseExpiry(String? isoDateTime) {
    if (isoDateTime == null || isoDateTime.isEmpty) return null;

    final expiresAt = DateTime.tryParse(isoDateTime);
    if (expiresAt == null) return null;

    return expiresAt.toUtc();
  }

  static bool _isExpired(String? isoDateTime) {
    final expiresAt = _parseExpiry(isoDateTime);
    if (expiresAt == null) return false;

    return !DateTime.now().toUtc().isBefore(expiresAt);
  }

  static bool _expiresWithin(String? isoDateTime, Duration duration) {
    final expiresAt = _parseExpiry(isoDateTime);
    if (expiresAt == null) return false;

    final renewalWindowEnd = DateTime.now().toUtc().add(duration);
    return !expiresAt.isAfter(renewalWindowEnd);
  }

  static Future<bool> _ensureTokenLifecycle() async {
    final prefs = await _freshPreferences();
    final accessToken = prefs.getString(_accessTokenKey);
    final refreshToken = prefs.getString(_refreshTokenKey);
    final accessTokenExpiresAt = prefs.getString(_accessTokenExpiresAtKey);
    final refreshTokenExpiresAt = prefs.getString(_refreshTokenExpiresAtKey);
    final hasAccessToken = accessToken != null && accessToken.isNotEmpty;
    final hasRefreshToken = refreshToken != null && refreshToken.isNotEmpty;

    if (hasRefreshToken && _isExpired(refreshTokenExpiresAt)) {
      await clearTokens();
      return false;
    }

    if (!hasAccessToken) {
      if (!hasRefreshToken) return false;
      return refreshAccessToken();
    }

    if (_isExpired(accessTokenExpiresAt)) {
      if (!hasRefreshToken) {
        await clearTokens();
        return false;
      }
      return refreshAccessToken();
    }

    if (hasRefreshToken &&
        _expiresWithin(refreshTokenExpiresAt, _refreshTokenRenewalThreshold)) {
      return refreshAccessToken();
    }

    return true;
  }

  static bool _isTransientNetworkError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('connection reset') ||
        msg.contains('connection refused') ||
        msg.contains('socketexception') ||
        msg.contains('clientexception') ||
        msg.contains('network') ||
        msg.contains('broken pipe');
  }

  static Future<Map<String, dynamic>?> request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    bool retryOnUnauthorized = true,
    bool retryOnNetworkError = true,
  }) async {
    try {
      if (requiresAuth && !await _ensureTokenLifecycle()) {
        onAuthExpired?.call();
        return null;
      }

      final response = await _sendRequest(
        method,
        endpoint,
        body: body,
        requiresAuth: requiresAuth,
      );

      if (response.statusCode == 401 && requiresAuth && retryOnUnauthorized) {
        final refreshed = await refreshAccessToken();
        if (!refreshed) {
          onAuthExpired?.call();
          return null;
        }

        return request(
          method,
          endpoint,
          body: body,
          requiresAuth: requiresAuth,
          retryOnUnauthorized: false,
        );
      }

      return _decodeResponse(response);
    } catch (e) {
      print('API 요청 에러: $e');
      // 일시적 네트워크 오류는 3초 후 1회 재시도
      if (retryOnNetworkError && _isTransientNetworkError(e)) {
        print('네트워크 오류 감지 — 3초 후 재시도: $method $endpoint');
        await Future.delayed(const Duration(seconds: 3));
        return request(
          method,
          endpoint,
          body: body,
          requiresAuth: requiresAuth,
          retryOnUnauthorized: retryOnUnauthorized,
          retryOnNetworkError: false,
        );
      }
      return null;
    }
  }

  static String _formatDateTime(DateTime dateTime) {
    if (dateTime.isUtc) return dateTime.toIso8601String();

    final offset = dateTime.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absoluteOffset = offset.abs();
    final hours = absoluteOffset.inHours.toString().padLeft(2, '0');
    final minutes = (absoluteOffset.inMinutes % 60).toString().padLeft(2, '0');

    return '${dateTime.toIso8601String()}$sign$hours:$minutes';
  }

  static Map<String, dynamic> _withoutNullValues(Map<String, dynamic> values) {
    return Map<String, dynamic>.fromEntries(
      values.entries.where((entry) => entry.value != null),
    );
  }

  // 알림/SMS 텍스트 파싱
  static Future<Map<String, dynamic>?> parseTransaction(
    String text, {
    String source = 'notification',
    DateTime? receivedAt,
    String? phoneLocale = defaultPhoneLocale,
    double? x,
    double? y,
  }) async {
    try {
      final data = await request(
        'POST',
        '/api/v1/parser/transaction',
        body: _withoutNullValues({
          'text': text,
          'source': source,
          'received_at': _formatDateTime(receivedAt ?? DateTime.now()),
          'phone_locale': phoneLocale,
          'x': x,
          'y': y,
        }),
      );
      print('파싱 응답: $data');
      if (_isSuccessfulResponse(data)) return data?['data'];
    } catch (e) {
      print('파싱 에러: $e');
    }
    return null;
  }

  static Map<String, dynamic>? _normalizedTransaction(
    Map<String, dynamic> parsed,
  ) {
    final tx = parsed['normalized_transaction'];
    if (tx is Map<String, dynamic>) return tx;
    if (tx is Map) return Map<String, dynamic>.from(tx);
    return null;
  }

  static int? _positiveAmount(Object? value) {
    final amount = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (amount == null || amount <= 0) return null;
    return amount;
  }

  static String? _ledgerEntryType(Object? value) {
    final type = value?.toString();
    if (type == 'expense' || type == 'income' || type == 'transfer') {
      return type;
    }
    return null;
  }

  static String? _nonEmptyString(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static num? _coordinate(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }

  // 가계부 저장
  static Future<bool> createLedgerEntry(
    Map<String, dynamic> parsed, {
    String source = 'notification',
  }) async {
    try {
      final tx = _normalizedTransaction(parsed);
      if (tx == null || tx['is_canceled'] == true) return false;

      final amount = _positiveAmount(tx['amount']);
      final type = _ledgerEntryType(tx['transaction_type']);
      if (amount == null || type == null) return false;

      final payload = _withoutNullValues({
        'amount': amount,
        'type': type,
        'category': CategoryMapper.toApi(
          _nonEmptyString(tx['merchant_category']),
        ),
        'merchant_name': _nonEmptyString(tx['merchant_name']),
        'transaction_at':
            _nonEmptyString(tx['approved_at']) ??
            _formatDateTime(DateTime.now()),
        'source': source,
        'raw_text': _nonEmptyString(tx['raw_text']),
        'x': _coordinate(tx['x']),
        'y': _coordinate(tx['y']),
      });

      final data = await request('POST', '/api/v1/ledger', body: payload);
      print('가계부 저장 응답: $data');
      return _isSuccessfulResponse(data);
    } catch (e) {
      print('가계부 저장 에러: $e');
      return false;
    }
  }

  // 가계부 목록 조회
  static Future<List<Map<String, dynamic>>> getLedgerEntries({
    int? year,
    int? month,
    String? category,
    String? type,
    String? bundleId,
  }) async {
    try {
      final data = await request(
        'GET',
        _endpointWithQuery('/api/v1/ledger', {
          'year': year,
          'month': month,
          'category': category == null ? null : CategoryMapper.toApi(category),
          'type': type,
          'bundle_id': bundleId,
        }),
      );
      print('가계부 조회 응답: $data');
      if (_isSuccessfulResponse(data)) {
        final items = data?['data']?['items'];
        if (items is List) {
          return items
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }
    } catch (e) {
      print('가계부 조회 에러: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getMonthlyLedgerStats({
    int? year,
    int? month,
  }) async {
    try {
      final data = await request(
        'GET',
        _endpointWithQuery('/api/v1/ledger/stats/monthly', {
          'year': year,
          'month': month,
        }),
      );
      print('월별 통계 응답: $data');
      if (_isSuccessfulResponse(data)) {
        final stats = data?['data'];
        if (stats is Map<String, dynamic>) return stats;
        if (stats is Map) return Map<String, dynamic>.from(stats);
      }
    } catch (e) {
      print('월별 통계 조회 에러: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getMonthlyCategoryChartStats({
    int? startYear,
    int? startMonth,
    int? endYear,
    int? endMonth,
  }) async {
    try {
      final data = await request(
        'GET',
        _endpointWithQuery('/api/v1/ledger/stats/categories/monthly/chart', {
          'start_year': startYear,
          'start_month': startMonth,
          'end_year': endYear,
          'end_month': endMonth,
        }),
      );
      print('월별 카테고리 차트 통계 응답: $data');
      if (_isSuccessfulResponse(data)) {
        final stats = data?['data'];
        if (stats is Map<String, dynamic>) return stats;
        if (stats is Map) return Map<String, dynamic>.from(stats);
      }
    } catch (e) {
      print('월별 카테고리 차트 통계 조회 에러: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final data = await request('GET', '/api/v1/users/me');
      print('내 정보 조회 응답: $data');
      if (_isSuccessfulResponse(data)) {
        final user = data?['data'];
        if (user is Map<String, dynamic>) return user;
        if (user is Map) return Map<String, dynamic>.from(user);
      }
    } catch (e) {
      print('내 정보 조회 에러: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getPetState() async {
    try {
      final data = await request('GET', '/api/v1/pet');
      print('펫 상태 조회 응답: $data');
      if (_isSuccessfulResponse(data)) {
        final pet = data?['data'];
        if (pet is Map<String, dynamic>) return pet;
        if (pet is Map) return Map<String, dynamic>.from(pet);
      }
    } catch (e) {
      print('펫 상태 조회 에러: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> updatePetInfo({
    String? name,
    String? species,
  }) async {
    try {
      final payload = _withoutNullValues({
        'name': _nonEmptyString(name),
        'species': _nonEmptyString(species),
      });
      if (payload.isEmpty) return getPetState();

      final data = await request('PATCH', '/api/v1/pet', body: payload);
      print('펫 정보 수정 응답: $data');
      if (_isSuccessfulResponse(data)) {
        final pet = data?['data'];
        if (pet is Map<String, dynamic>) return pet;
        if (pet is Map) return Map<String, dynamic>.from(pet);
      }
    } catch (e) {
      print('펫 정보 수정 에러: $e');
    }
    return null;
  }

  static Future<bool> createManualLedgerEntry({
    required int amount,
    required String type,
    required String category,
    required DateTime transactionAt,
    String? merchantName,
    String? memo,
  }) async {
    final data = await request(
      'POST',
      '/api/v1/ledger',
      body: _withoutNullValues({
        'amount': amount,
        'type': type,
        'category': CategoryMapper.toApi(category),
        'merchant_name': _nonEmptyString(merchantName),
        'memo': _nonEmptyString(memo),
        'transaction_at': _formatDateTime(transactionAt),
        'source': 'manual',
      }),
    );
    print('수동 가계부 저장 응답: $data');
    return _isSuccessfulResponse(data);
  }

  // 토큰 저장
  static Future<void> saveTokens(
    String accessToken,
    String refreshToken, {
    String? accessTokenExpiresAt,
    String? refreshTokenExpiresAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    if (accessTokenExpiresAt != null) {
      await prefs.setString(_accessTokenExpiresAtKey, accessTokenExpiresAt);
    } else {
      await prefs.remove(_accessTokenExpiresAtKey);
    }
    if (refreshTokenExpiresAt != null) {
      await prefs.setString(_refreshTokenExpiresAtKey, refreshTokenExpiresAt);
    } else {
      await prefs.remove(_refreshTokenExpiresAtKey);
    }
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_accessTokenExpiresAtKey);
    await prefs.remove(_refreshTokenExpiresAtKey);
  }

  // 회원가입
  static Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String nickname,
  }) async {
    try {
      final data = await request(
        'POST',
        '/api/v1/auth/signup',
        body: {'email': email, 'password': password, 'nickname': nickname},
        requiresAuth: false,
        retryOnUnauthorized: false,
      );
      print('회원가입 응답: $data');
      if (_isSuccessfulResponse(data)) {
        if (await _saveTokensFromResponse(data)) {
          return {'success': true};
        }
        return {'success': false, 'message': '인증 토큰을 받지 못했습니다'};
      }
      return {'success': false, 'message': data?['message'] ?? '회원가입 실패'};
    } catch (e) {
      return {'success': false, 'message': '서버 연결 실패: $e'};
    }
  }

  // 로그인
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final data = await request(
        'POST',
        '/api/v1/auth/login',
        body: {'email': email, 'password': password},
        requiresAuth: false,
        retryOnUnauthorized: false,
      );
      print('로그인 응답: $data');
      if (_isSuccessfulResponse(data)) {
        if (await _saveTokensFromResponse(data)) {
          return {'success': true};
        }
        return {'success': false, 'message': '인증 토큰을 받지 못했습니다'};
      }
      return {'success': false, 'message': data?['message'] ?? '로그인 실패'};
    } catch (e) {
      return {'success': false, 'message': '서버 연결 실패: $e'};
    }
  }

  // 저장된 토큰이 있는지 확인 (자동 로그인용)
  static Future<bool> hasValidToken() async {
    return _ensureTokenLifecycle();
  }

  // 로그아웃 - 서버 refresh token 폐기 후 저장된 토큰 삭제
  static Future<void> logout() async {
    final refreshToken = await getRefreshToken();
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await request(
          'POST',
          '/api/v1/auth/logout',
          body: {'refresh_token': refreshToken},
          requiresAuth: false,
          retryOnUnauthorized: false,
        );
      }
    } finally {
      await clearTokens();
    }
  }

  // 토큰 갱신
  static Future<bool> refreshAccessToken() async {
    try {
      final prefs = await _freshPreferences();
      final refreshToken = prefs.getString(_refreshTokenKey);
      if (refreshToken == null || refreshToken.isEmpty) {
        await clearTokens();
        return false;
      }
      if (_isExpired(prefs.getString(_refreshTokenExpiresAtKey))) {
        await clearTokens();
        return false;
      }

      final data = await request(
        'POST',
        '/api/v1/auth/refresh',
        body: {'refresh_token': refreshToken},
        requiresAuth: false,
        retryOnUnauthorized: false,
      );

      if (_isSuccessfulResponse(data) &&
          await _saveTokensFromResponse(
            data,
            fallbackRefreshToken: refreshToken,
          )) {
        return true;
      }

      await clearTokens();
      return false;
    } catch (e) {
      print('토큰 갱신 에러: $e');
      await clearTokens();
      return false;
    }
  }
}
