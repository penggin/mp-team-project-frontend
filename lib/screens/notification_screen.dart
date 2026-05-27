import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import '../background_task_handler.dart';
import '../services/api_service.dart';
import '../services/category_mapper.dart';
import '../services/experience_service.dart';
import '../services/notification_processing.dart';
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
  static const Duration _liveRefreshInterval = Duration(seconds: 3);

  // 같은 알림을 UI와 백그라운드 서비스가 중복 처리하지 않도록 방지
  static final Set<String> _processedNotificationFingerprints = {};

  final Color themeSkyBlue = const Color(0xFFE8F6F8);
  final Color themeDarkBlue = const Color(0xFF1E105C);

  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  Timer? _liveRefreshTimer;
  StreamSubscription<ServiceNotificationEvent>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadFromBackend();
    _startLiveRefreshTimer();
    if (widget.enableBackgroundProcessing) {
      _startNotificationProcessing();
      _listenNotificationsDirect();
      FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    }
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    _notificationSubscription?.cancel();
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

  /// UI 레이어에서 직접 알림 스트림을 수신.
  /// 백그라운드 서비스가 놓친 결제 알림을 보완하는 역할.
  void _listenNotificationsDirect() {
    _notificationSubscription?.cancel();
    _notificationSubscription = NotificationListenerService.notificationsStream
        .listen(
          _handleNotificationEvent,
          onError: (e) => debugPrint('알림 스트림 에러(직접): $e'),
          onDone: () => debugPrint('알림 스트림 종료(직접)'),
        );
  }

  Future<void> _handleNotificationEvent(ServiceNotificationEvent event) async {
    final candidate = NotificationProcessing.candidateFromEvent(event);
    if (candidate == null) return;

    // 백그라운드 서비스 또는 이전 호출이 이미 처리한 알림은 건너뜀
    if (_processedNotificationFingerprints.contains(candidate.fingerprint)) {
      return;
    }
    _processedNotificationFingerprints.add(candidate.fingerprint);

    debugPrint('알림 감지(직접): ${candidate.rawText}');

    if (!await ApiService.hasValidToken()) return;

    final parsed = await ApiService.parseTransaction(candidate.rawText);
    if (parsed == null) return;

    final saved = await ApiService.createLedgerEntry(parsed);
    if (!saved || !mounted) return;

    await _loadFromBackend();
  }

  /// 백엔드에서 가계부 내역을 가져와 최신순으로 표시.
  /// _isRefreshing 가드 없이 항상 즉시 실행 — 항목이 누락되는 문제 방지.
  Future<void> _loadFromBackend() async {
    final entries = await ApiService.getLedgerEntries();

    if (!mounted) return;
    setState(() {
      final sorted = List<Map<String, dynamic>>.from(entries);
      sorted.sort((a, b) {
        final aStr = (a['transaction_at'] ?? a['created_at'] ?? '') as String;
        final bStr = (b['transaction_at'] ?? b['created_at'] ?? '') as String;
        return bStr.compareTo(aStr);
      });
      _notifications = sorted.map(_notificationFromEntry).toList();
      _isLoading = false;
    });
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

    await ExperienceService.recordTodaySpend(todaySpend);

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
    _clearLocalNotifications();
  }

  void _clearLocalNotifications() {
    setState(() {
      _notifications = [];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('알림 목록을 비웠습니다. 백엔드 데이터는 유지됩니다.')),
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
            onPressed:
                _notifications.isEmpty ? null : _confirmClearNotifications,
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
