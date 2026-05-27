import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../background_task_handler.dart';
import '../services/api_service.dart';
import '../services/category_mapper.dart';
import '../services/experience_service.dart';
import '../services/notification_inbox_store.dart';
import '../services/payment_push_notification_service.dart';
import 'budget_alert_dialog.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class AppNotification {
  final String content;
  final String category;
  final String? storageKey;

  AppNotification({
    required this.content,
    required this.category,
    this.storageKey,
  });
}

class NotificationScreen extends StatefulWidget {
  final bool enableBackgroundProcessing;

  const NotificationScreen({super.key, this.enableBackgroundProcessing = true});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final Color themeSkyBlue = const Color(0xFFE8F6F8);
  final Color themeDarkBlue = const Color(0xFF1E105C);

  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  @override
  void initState() {
    super.initState();
    _loadFromBackend();
    if (widget.enableBackgroundProcessing) {
      _startNotificationProcessing();
      FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
      _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted) _loadFromBackend();
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    if (widget.enableBackgroundProcessing) {
      FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    }
    super.dispose();
  }

  void _onReceiveTaskData(dynamic data) {
    if (!mounted) return;
    if (data is Map && data['action'] == 'authExpired') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      return;
    }
    _refreshAfterTaskData();
  }

  Future<void> _refreshAfterTaskData() async {
    await _loadFromBackend();
    await _checkDailyBudgetAndAlert();
  }

  Future<void> _startNotificationProcessing() async {
    await _startForegroundService();
  }

  Future<void> _startForegroundService() async {
    if (await FlutterForegroundTask.isRunningService) return;
    await PaymentPushNotificationService.instance.requestPermissions();
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: '가계부 키우기',
      notificationText: '결제 내역을 자동으로 기록 중',
      callback: startCallback,
    );
  }

  // 백엔드에서 가계부 내역 불러오기 (최신순)
  Future<void> _loadFromBackend() async {
    final entries = await ApiService.getLedgerEntries();
    final visibleEntries = await NotificationInboxStore.visibleLedgerEntries(
      entries,
    );

    // 최신순 정렬: transaction_at 기준 내림차순
    final sorted = List<Map<String, dynamic>>.from(visibleEntries);
    sorted.sort((a, b) {
      final aStr = (a['transaction_at'] ?? a['created_at'] ?? '') as String;
      final bStr = (b['transaction_at'] ?? b['created_at'] ?? '') as String;
      return bStr.compareTo(aStr);
    });

    if (!mounted) return;
    setState(() {
      _notifications = sorted.map((entry) {
        final merchant = entry['merchant_name'] ?? '알 수 없음';
        final amount = entry['amount'] ?? 0;
        final amountStr = amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
        return AppNotification(
          content: '$merchant에서 $amountStr원 결제',
          category: CategoryMapper.toDisplay(entry['category']?.toString()),
          storageKey: NotificationInboxStore.keyForLedgerEntry(entry),
        );
      }).toList();
      _isLoading = false;
    });
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
      final txAtStr =
          (entry['transaction_at'] as String? ??
                  entry['created_at'] as String? ??
                  '')
              .trim();
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
    final exceeded = await ExperienceService.checkDailyBudgetExceeded(
      todaySpend,
    );
    if (!exceeded || !mounted) return;

    BudgetAlertDialog.show(
      context,
      onGoToHistory: () {
        Navigator.of(context).popUntil((route) => route.isFirst);
        MainScreen.globalKey.currentState?.changeTab(1);
      },
    );
  }


  IconData _getIconForCategory(String category) {
    switch (CategoryMapper.toDisplay(category)) {
      case '카페':
        return Icons.local_cafe;
      case '식비':
        return Icons.restaurant;
      case '쇼핑':
        return Icons.shopping_bag;
      case '교통':
        return Icons.directions_car;
      case '통신':
        return Icons.phone_android;
      case '이자':
      case '급여':
      case '용돈':
        return Icons.monetization_on;
      case '기타':
      default:
        return Icons.account_balance_wallet;
    }
  }

  Future<void> _confirmClearNotifications() async {
    if (_notifications.isEmpty) return;

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림 목록 비우기'),
        content: const Text('현재 화면에 쌓인 알림만 지웁니다.\n백엔드 가계부 데이터는 삭제되지 않습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('비우기'),
          ),
        ],
      ),
    );

    if (shouldClear != true) return;
    await _clearLocalNotifications();
  }

  Future<void> _clearLocalNotifications() async {
    final keys = _notifications.map((notification) => notification.storageKey);
    await NotificationInboxStore.hideNotificationKeys(keys);
    if (!mounted) return;

    setState(() {
      _notifications = [];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('알림 목록을 비웠습니다. 백엔드 데이터는 유지됩니다.')),
    );
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
            tooltip: '새로고침',
            icon: Icon(Icons.refresh, color: themeDarkBlue),
            onPressed: _loadFromBackend,
          ),
          IconButton(
            tooltip: '알림 비우기',
            icon: Icon(
              Icons.delete_sweep_outlined,
              color: _notifications.isEmpty
                  ? themeDarkBlue.withValues(alpha: 0.35)
                  : themeDarkBlue,
            ),
            onPressed: _notifications.isEmpty
                ? null
                : _confirmClearNotifications,
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
