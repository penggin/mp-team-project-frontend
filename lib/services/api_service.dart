import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://penggin.iptime.org:2543';

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

// lib/services/api_service.dart

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getAccessToken();
    // 로그를 추가하여 토큰이 실제로 존재하는지 확인합니다.
    print('DEBUG: 현재 사용 중인 Access Token: ${token ?? "없음"}');

    return {
      'Content-Type': 'application/json',
      // Swagger 명세에 따라 'Bearer ' 문자열을 앞에 붙여야 합니다.
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // 알림 텍스트 파싱
  static Future<Map<String, dynamic>?> parseTransaction(String text) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/parser/transaction'),
        headers: headers,
        body: jsonEncode({
          'text': text,
          'source': 'notification',
          'received_at': DateTime.now().toIso8601String(),
          'phone_locale': 'ko-KR',
        }),
      );
      print('파싱 응답: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return data['data'];
      }
    } catch (e) {
      print('파싱 에러: $e');
    }
    return null;
  }

  // 가계부 저장
  static Future<bool> createLedgerEntry(Map<String, dynamic> parsed) async {
    try {
      final headers = await _authHeaders();
      final tx = parsed['normalized_transaction'];
      if (tx == null || tx['amount'] == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/ledger'),
        headers: headers,
        body: jsonEncode({
          'amount': tx['amount'],
          'type': tx['transaction_type'] == 'income' ? 'income' : 'expense',
          'category': tx['merchant_category'] ?? '미분류',
          'merchant_name': tx['merchant_name'],
          'transaction_at': tx['approved_at'] ?? DateTime.now().toIso8601String(),
          'source': 'notification',
          'raw_text': tx['raw_text'],
        }),
      );
      print('가계부 저장 응답: ${response.statusCode} ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('가계부 저장 에러: $e');
      return false;
    }
  }

  // 가계부 목록 조회 (추가)
  // lib/services/api_service.dart

  static Future<List<Map<String, dynamic>>> getLedgerEntries() async {
    try {
      final headers = await _authHeaders();
      var response = await http.get(
        Uri.parse('$baseUrl/api/v1/ledger'),
        headers: headers,
      );

      print('가계부 조회 응답 코드: ${response.statusCode}');

      // 401 에러가 발생한 경우
      if (response.statusCode == 401) {
        print('토큰 만료 감지, 토큰 갱신 시도 중...');
        bool isRefreshed = await refreshAccessToken(); // 기존에 구현된 메서드 활용

        if (isRefreshed) {
          print('토큰 갱신 성공, 재요청 시도');
          final newHeaders = await _authHeaders();
          response = await http.get(
            Uri.parse('$baseUrl/api/v1/ledger'),
            headers: newHeaders,
          );
        } else {
          print('토큰 갱신 실패, 로그아웃 처리');
          await logout(); // 토큰 삭제
          return [];
        }
      }

      if (response.statusCode == 200) {
        // 한글 깨짐 방지를 위해 utf8.decode 사용
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          final items = data['data']['items'] as List;
          return items.cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      print('가계부 조회 에러: $e');
    }
    return [];
  }
  // 토큰 저장
  static Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  // 회원가입
  static Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String nickname,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'nickname': nickname,
        }),
      );
      print('회원가입 응답: ${response.statusCode} ${response.body}');
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data['success'] == true) {
        await saveTokens(
          data['data']['access_token'],
          data['data']['refresh_token'],
        );
        return {'success': true};
      }
      return {'success': false, 'message': data['message'] ?? '회원가입 실패'};
    } catch (e) {
      return {'success': false, 'message': '서버 연결 실패: $e'};
    }
  }

  // 로그인
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      print('로그인 응답: ${response.statusCode} ${response.body}');
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data['success'] == true) {
        await saveTokens(
          data['data']['access_token'],
          data['data']['refresh_token'],
        );
        return {'success': true};
      }
      return {'success': false, 'message': data['message'] ?? '로그인 실패'};
    } catch (e) {
      return {'success': false, 'message': '서버 연결 실패: $e'};
    }
  }
  // 저장된 토큰이 있는지 확인 (자동 로그인용)
  static Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

// 로그아웃 - 저장된 토큰 모두 삭제
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

// (선택) 토큰 갱신 - 백엔드에 /api/v1/auth/refresh 엔드포인트가 있을 때만 동작
  static Future<bool> refreshAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          await saveTokens(
            data['data']['access_token'],
            data['data']['refresh_token'],
          );
          return true;
        }
      }
      return false;
    } catch (e) {
      print('토큰 갱신 에러: $e');
      return false;
    }
  }
}