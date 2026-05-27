import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:first/services/api_service.dart';
import 'package:first/services/payment_ingestion_workflow.dart';

http.Response jsonResponse(Map<String, dynamic> body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    ApiService.resetHttpClientForTest();
  });

  test('ignores non-payment text before calling the parser', () async {
    SharedPreferences.setMockInitialValues({'access_token': 'access-token'});
    ApiService.setHttpClientForTest(
      MockClient((request) async {
        fail('Unexpected backend call: ${request.method} ${request.url}');
      }),
    );

    final result = await PaymentIngestionWorkflow.processText(
      '이번 주 카드 혜택 안내 쿠폰이 도착했어요',
      source: PaymentIngestionSource.notification,
    );

    expect(result.status, PaymentIngestionStatus.ignoredByPreflight);
  });

  test('parses a payment notification and saves the ledger payload', () async {
    SharedPreferences.setMockInitialValues({'access_token': 'access-token'});

    final requestedPaths = <String>[];
    Map<String, dynamic>? ledgerPayload;
    final receivedAt = DateTime(2026, 5, 27, 9, 30);

    ApiService.setHttpClientForTest(
      MockClient((request) async {
        requestedPaths.add(request.url.path);

        if (request.url.path == '/api/v1/parser/transaction') {
          final parserPayload = jsonDecode(request.body);
          expect(parserPayload, {
            'text': 'KB국민카드 스타벅스 5,600원 승인',
            'source': 'notification',
            'received_at': '2026-05-27T09:30:00.000+09:00',
            'phone_locale': 'ko-KR',
          });
          return jsonResponse({
            'success': true,
            'data': {
              'normalized_transaction': {
                'transaction_type': 'expense',
                'is_canceled': false,
                'amount': 5600,
                'merchant_name': '스타벅스',
                'merchant_category': 'cafe',
                'payment_method': 'card',
                'card_company': 'KB국민카드',
                'approved_at': '2026-05-27T09:29:00+09:00',
                'source': 'notification',
                'raw_text': 'KB국민카드 스타벅스 5,600원 승인',
                'x': 126.978,
                'y': 37.5665,
              },
              'confidence': 0.98,
              'requires_user_confirmation': false,
              'missing_fields': [],
              'parse_strategy': 'rule_based',
              'warnings': [],
            },
          }, 200);
        }

        if (request.url.path == '/api/v1/ledger') {
          ledgerPayload = jsonDecode(request.body) as Map<String, dynamic>;
          return jsonResponse({
            'success': true,
            'data': {'id': 'entry-1'},
          }, 200);
        }

        fail('Unexpected backend call: ${request.method} ${request.url}');
      }),
    );

    final result = await PaymentIngestionWorkflow.processText(
      'KB국민카드 스타벅스 5,600원 승인',
      source: PaymentIngestionSource.notification,
      receivedAt: receivedAt,
    );

    expect(result.status, PaymentIngestionStatus.saved);
    expect(requestedPaths, ['/api/v1/parser/transaction', '/api/v1/ledger']);
    expect(ledgerPayload, {
      'amount': 5600,
      'type': 'expense',
      'category': 'cafe',
      'merchant_name': '스타벅스',
      'transaction_at': '2026-05-27T09:29:00+09:00',
      'source': 'notification',
      'raw_text': 'KB국민카드 스타벅스 5,600원 승인',
      'x': 126.978,
      'y': 37.5665,
    });
  });

  test('does not save canceled parsed transactions', () async {
    SharedPreferences.setMockInitialValues({'access_token': 'access-token'});

    final requestedPaths = <String>[];

    ApiService.setHttpClientForTest(
      MockClient((request) async {
        requestedPaths.add(request.url.path);

        if (request.url.path == '/api/v1/parser/transaction') {
          return jsonResponse({
            'success': true,
            'data': {
              'normalized_transaction': {
                'transaction_type': 'expense',
                'is_canceled': true,
                'amount': 5600,
                'merchant_name': '스타벅스',
                'merchant_category': 'cafe',
                'payment_method': 'card',
                'card_company': 'KB국민카드',
                'approved_at': '2026-05-27T09:29:00+09:00',
                'source': 'notification',
                'raw_text': 'KB국민카드 스타벅스 5,600원 취소',
              },
              'confidence': 0.98,
              'requires_user_confirmation': false,
              'missing_fields': [],
              'parse_strategy': 'rule_based',
              'warnings': [],
            },
          }, 200);
        }

        fail('Unexpected backend call: ${request.method} ${request.url}');
      }),
    );

    final result = await PaymentIngestionWorkflow.processText(
      'KB국민카드 스타벅스 5,600원 취소',
      source: PaymentIngestionSource.notification,
    );

    expect(result.status, PaymentIngestionStatus.skippedCancellation);
    expect(requestedPaths, ['/api/v1/parser/transaction']);
  });
}
