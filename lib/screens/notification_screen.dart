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

  final Set<String> _processedNotifications = {};

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
        final merchant = entry['merchant_name'] ?? '알 수 없음';
        final amount = entry['amount'] ?? 0;
        final amountStr = amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (m) => '${m[1]},',
        );
        return AppNotification(
          content: '$merchant에서 $amountStr원 결제',
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

      // 중복 방지 (5초 내 같은 텍스트 무시)
      if (_processedNotifications.contains(fullText)) {
        print('  ↳ 중복 알림, 무시');
        return;
      }
      _processedNotifications.add(fullText);
      // 5초 후 자동 제거 (다음에 같은 결제 다시 와도 처리되도록)
      Future.delayed(const Duration(seconds: 5), () {
        _processedNotifications.remove(fullText);
      });

      print('알림 감지: $fullText');

      if (!_isPaymentNotification(fullText)) {
        print('  ↳ 결제 알림 아님, 무시');
        return;
      }

      final parsed = await ApiService.parseTransaction(fullText);
      if (parsed == null) return;

      final saved = await ApiService.createLedgerEntry(parsed);
      if (!saved) return;

      await _loadFromBackend();
    });
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'cafe':
        return Icons.local_cafe;
      case 'food':
        return Icons.restaurant;
      case 'shopping':
        return Icons.shopping_bag;
      case 'transport':
        return Icons.directions_car;
      case 'deposit':
        return Icons.card_giftcard;
      case 'system':
        return Icons.egg_alt;
      default:
        return Icons.account_balance_wallet;
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