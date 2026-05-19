import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import '../background_task_handler.dart';
import '../services/api_service.dart';

class AppNotification {
  final String content;
  final String category;

  AppNotification({
    required this.content,
    required this.category,
  });
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final Color themeSkyBlue = const Color(0xFFE8F6F8);
  final Color themeDarkBlue = const Color(0xFF1E105C);

  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startForegroundService();
    _loadFromBackend();
    _listenNotificationsDirect();
  }

  Future<void> _startForegroundService() async {
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: '가계부 키우기',
      notificationText: '결제 내역을 자동으로 기록 중',
      callback: startCallback,
    );
  }

  // 백엔드에서 가계부 내역 불러오기
  Future<void> _loadFromBackend() async {
    final entries = await ApiService.getLedgerEntries();

    if (!mounted) return;
    setState(() {
      _notifications = entries.map((entry) {
        return AppNotification(
          content: entry['raw_text'] ??
              '${entry['merchant_name'] ?? '미상'} ${entry['amount']}원',
          category: entry['category'] ?? '미분류',
        );
      }).toList();
      _isLoading = false;
    });
  }

  // 결제 알림 키워드 필터링
  bool _isPaymentNotification(String content) {
    const keywords = [
      '승인', '결제', '출금', '입금', '이체', '취소', '카드',
    ];
    return keywords.any((keyword) => content.contains(keyword));
  }

  // 알림 직접 수신 + 백엔드 연동
  void _listenNotificationsDirect() {
    NotificationListenerService.notificationsStream.listen((event) async {
      final title = event.title ?? '';
      final body = event.content ?? '';
      final fullText = '$title $body'.trim();

      if (fullText.isEmpty) return;

      print('알림 감지: $fullText');

      if (!_isPaymentNotification(fullText)) {
        print('  ↳ 결제 알림 아님, 무시');
        return;
      }

      // 1. 서버에 파싱 요청
      final parsed = await ApiService.parseTransaction(fullText);
      if (parsed == null) return;

      // 2. 가계부 저장
      final saved = await ApiService.createLedgerEntry(parsed);
      if (!saved) return;

      // 3. 백엔드에서 다시 불러와서 화면 갱신
      await _loadFromBackend();
    });
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'CAFE':
      case 'cafe':
      case 'FOOD':
      case 'food':
      case 'SHOPPING':
        return Icons.account_balance_wallet;
      case 'DEPOSIT':
        return Icons.card_giftcard;
      case 'SYSTEM':
        return Icons.egg_alt;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeDarkBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '알림',
          style: TextStyle(color: themeDarkBlue, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: themeDarkBlue),
            onPressed: _loadFromBackend,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: themeDarkBlue))
          : _notifications.isEmpty
          ? Center(
        child: Text(
          '감지된 결제 내역이 없습니다',
          style: TextStyle(color: themeDarkBlue, fontSize: 16),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(20.0),
        physics: const BouncingScrollPhysics(),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final item = _notifications[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: themeSkyBlue, width: 2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: themeSkyBlue,
                  child: Icon(
                    _getIconForCategory(item.category),
                    color: themeDarkBlue,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    item.content,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}