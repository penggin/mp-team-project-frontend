import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../background_task_handler.dart';
import '../services/api_service.dart';
import '../services/category_mapper.dart';
import '../services/experience_service.dart';
import '../services/payment_push_notification_service.dart';
import 'budget_alert_dialog.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class AppNotification {
  final String key;
  final String content;
  final String category;

  AppNotification({
    required this.key,
    required this.content,
    required this.category,
  });
}

class NotificationScreen extends StatefulWidget {
  final bool enableBackgroundProcessing;
  final PaymentPushNotificationService? pushNotificationService;

  const NotificationScreen({
    super.key,
    this.enableBackgroundProcessing = true,
    this.pushNotificationService,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const Duration _liveRefreshInterval = Duration(seconds: 5);

  final Color themeSkyBlue = const Color(0xFFE8F6F8);
  final Color themeDarkBlue = const Color(0xFF1E105C);

  List<AppNotification> _notifications = [];
  final Set<String> _clearedNotificationKeys = {};
  bool _isLoading = true;
  bool _isRefreshing = false;
  Timer? _liveRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadFromBackend();
    _startLiveRefreshTimer();
    if (widget.enableBackgroundProcessing) {
      _startNotificationProcessing();
      FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    }
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    if (widget.enableBackgroundProcessing) {
      FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    }
    super.dispose();
  }

  void _startLiveRefreshTimer() {
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = Timer.periodic(
      _liveRefreshInterval,
      (_) => _loadFromBackend(),
    );
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
    await (widget.pushNotificationService ??
            PaymentPushNotificationService.instance)
        .requestPermissions();
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: '가계부 키우기',
        notificationText: '결제 내역을 자동으로 기록 중',
        callback: startCallback,
      );
      await FlutterForegroundTask.restartService();
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: '가계부 키우기',
      notificationText: '결제 내역을 자동으로 기록 중',
      callback: startCallback,
    );
  }

  // 백엔드에서 가계부 내역 불러오기 (최신순)
  Future<void> _loadFromBackend() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final entries = await ApiService.getLedgerEntries();

      if (!mounted) return;
      setState(() {
        _notifications = entries
            .map(_notificationFromEntry)
            .where(
              (notification) =>
                  !_clearedNotificationKeys.contains(notification.key),
            )
            .toList();
        _isLoading = false;
      });
    } finally {
      _isRefreshing = false;
    }
  }

  AppNotification _notificationFromEntry(Map<String, dynamic> entry) {
    return AppNotification(
      key: _notificationKeyForEntry(entry),
      content: _notificationContentForEntry(entry),
      category: CategoryMapper.toDisplay(entry['category']?.toString()),
    );
  }

  String _notificationKeyForEntry(Map<String, dynamic> entry) {
    final id = _nonEmptyString(entry['id']);
    if (id != null) return id;

    return [
      entry['type'],
      entry['amount'],
      entry['category'],
      entry['merchant_name'],
      entry['transaction_at'],
      entry['created_at'],
      entry['raw_text'],
    ].map((value) => value?.toString().trim() ?? '').join('|');
  }

  String _notificationContentForEntry(Map<String, dynamic> entry) {
    final merchant =
        _nonEmptyString(entry['merchant_name']) ??
        CategoryMapper.toDisplay(entry['category']?.toString());
    final amount = _amountValue(entry['amount']);
    final amountStr = _formatAmount(amount);
    final type = entry['type']?.toString();

    if (type == 'income') return '$merchant $amountStr원 입금';
    if (type == 'transfer') return '$merchant $amountStr원 이체';
    return '$merchant에서 $amountStr원 결제';
  }

  String? _nonEmptyString(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  int _amountValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
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
    setState(() {
      _clearedNotificationKeys.addAll(
        _notifications.map((notification) => notification.key),
      );
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
