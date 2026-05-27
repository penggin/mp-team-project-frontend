import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import '../background_task_handler.dart';
import '../services/api_service.dart';
import '../services/notification_processing.dart';
import '../services/experience_service.dart';
import 'budget_alert_dialog.dart';
import 'main_screen.dart';

class AppNotification {
  final String content;
  final String category;

  AppNotification({required this.content, required this.category});
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static final Set<String> _processedNotificationFingerprints = {};

  final Color themeSkyBlue = const Color(0xFFE8F6F8);
  final Color themeDarkBlue = const Color(0xFF1E105C);

  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  StreamSubscription<ServiceNotificationEvent>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadFromBackend();
    _startNotificationProcessing();
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _onReceiveTaskData(dynamic data) {
    if (!mounted) return;
    _loadFromBackend();
  }

  Future<void> _startNotificationProcessing() async {
    await _startForegroundService();
    if (!mounted) return;
    _listenNotificationsDirect();
    await _loadActiveNotifications();
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

  Future<void> _loadActiveNotifications() async {
    try {
      final granted = await NotificationListenerService.isPermissionGranted();
      if (!granted) {
        print('알림 접근 권한 없음: 현재 알림을 읽지 않음');
        return;
      }

      final events = await NotificationListenerService.getActiveNotifications();
      for (final event in events) {
        await _handleNotificationEvent(event, source: 'active');
      }
    } catch (e) {
      print('현재 알림 조회 에러: $e');
    }
  }

  // 알림 직접 수신 + 백엔드 연동
  void _listenNotificationsDirect() {
    _notificationSubscription?.cancel();
    _notificationSubscription = NotificationListenerService.notificationsStream
        .listen(
          (event) => _handleNotificationEvent(event, source: 'stream'),
      onError: (error) => print('알림 스트림 에러: $error'),
    );
  }

  Future<void> _handleNotificationEvent(
      ServiceNotificationEvent event, {
        required String source,
      }) async {
    final candidate = NotificationProcessing.candidateFromEvent(event);
    if (candidate == null) return;
    if (!mounted) return;

    if (_processedNotificationFingerprints.contains(candidate.fingerprint)) {
      print('  ↳ 중복 알림, 무시');
      return;
    }
    _processedNotificationFingerprints.add(candidate.fingerprint);

    print('알림 감지($source): ${candidate.rawText}');

    final parsed = await ApiService.parseTransaction(candidate.rawText);
    if (parsed == null) return;

    final saved = await ApiService.createLedgerEntry(parsed);
    if (!saved) return;
    if (!mounted) return;

    await _loadFromBackend();

    // ── 하루 예산 초과 체크 ──
    await _checkDailyBudgetAndAlert();
  }

  /// 결제 감지 후 하루 지출 재계산 후 예산 초과면 알림창
  Future<void> _checkDailyBudgetAndAlert() async {
    // 오늘 지출 합계 계산
    final entries = await ApiService.getLedgerEntries();
    final now = DateTime.now();
    int todaySpend = 0;
    for (final entry in entries) {
      if ((entry['type'] as String? ?? '') != 'expense') continue;
      final amount = (entry['amount'] as num?)?.toInt() ?? 0;
      final txAtStr = (entry['transaction_at'] as String? ??
              entry['created_at'] as String? ?? '').trim();
      if (txAtStr.isEmpty) continue;
      try {
        final txAt = DateTime.parse(txAtStr).toLocal();
        if (txAt.year == now.year &&
            txAt.month == now.month &&
            txAt.day == now.day) {
          todaySpend += amount;
        }
      } catch (_) {}
    }

    // 오늘 지출 기록 갱신
    await ExperienceService.recordTodaySpend(todaySpend);

    // 초과 여부 확인
    final exceeded = await ExperienceService.checkDailyBudgetExceeded(todaySpend);
    if (!exceeded || !mounted) return;

    BudgetAlertDialog.show(
      context,
      onGoToHistory: () {
        MainScreen.globalKey.currentState?.changeTab(1);
      },
    );
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
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: themeDarkBlue),
                  const SizedBox(height: 16),
                  Text(
                    '알림 읽어오는 중...',
                    style: TextStyle(color: themeDarkBlue, fontSize: 14),
                  ),
                ],
              ),
            )
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
