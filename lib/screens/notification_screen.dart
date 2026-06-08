import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import '../services/api_service.dart';
import '../services/category_mapper.dart';
import '../services/experience_service.dart';
import '../services/location_service.dart';
import '../services/notification_processing.dart';
import 'budget_alert_dialog.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class AppNotification {
  final String key;
  final String content;
  final String category;
  final bool isIncome;

  AppNotification({
    required this.key,
    required this.content,
    required this.category,
    required this.isIncome,
  });
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // 백그라운드 서비스와 UI가 같은 알림을 중복 처리하지 않도록 방지
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
    _listenNotificationsDirect();
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    super.dispose();
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

    // GPS 좌표 조회 (카테고라이징 정밀도 향상용, 실패 시 null로 진행)
    final coords = await LocationService.currentCoordinates();

    final parsed = await ApiService.parseTransaction(
      candidate.rawText,
      x: coords.x,
      y: coords.y,
    );
    if (parsed == null) return;

    final saved = await ApiService.createLedgerEntry(parsed);
    if (!saved || !mounted) return;

    // 실제 결제 감지 후에만 다시 로드 (스피너 없이 조용히)
    await _loadFromBackend(silent: true);
  }

  // 3초 타이머 제거: 실제 결제 감지 시에만 로드함
  // void _startLiveRefreshTimer() { ... }

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

  /// 백엔드에서 가계부 내역을 가져와 최신순으로 표시.
  /// [silent] = true이면 로딩 스피너 없이 백그라운드 갱신.
  Future<void> _loadFromBackend({bool silent = false}) async {
    print('[알림창] 📡 _loadFromBackend 시작 (silent=$silent)');
    if (!silent) setState(() => _isLoading = true);
    final entries = await ApiService.getLedgerEntries();
    print('[알림창] ✅ API 응답 — 항목 수: ${entries.length}');
    if (entries.isNotEmpty) {
      final first = entries.first;
      print('[알림창] 최신 항목: ${first['merchant_name']} / ${first['amount']} / ${first['transaction_at'] ?? first['created_at']}');
    }

    if (!mounted) {
      print('[알림창] ⚠️ mounted == false, setState 스킵');
      return;
    }
    setState(() {
      final sorted = List<Map<String, dynamic>>.from(entries);
      sorted.sort((a, b) {
        // 타임존 포맷이 섞여있어도(`Z` vs `+09:00`) DateTime으로 파싱하면
        // 절대 시간 기준으로 정확히 비교됨
        final aDate = DateTime.tryParse(
          (a['transaction_at'] ?? a['created_at'] ?? '') as String,
        );
        final bDate = DateTime.tryParse(
          (b['transaction_at'] ?? b['created_at'] ?? '') as String,
        );
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1; // null은 뒤로
        if (bDate == null) return -1;
        return bDate.compareTo(aDate); // 최신순 (내림차순)
      });
      _notifications = sorted.map(_notificationFromEntry).toList();
      _isLoading = false;
      print('[알림창] 🎨 setState 완료 — 화면에 ${_notifications.length}개 표시');
    });
  }

  AppNotification _notificationFromEntry(Map<String, dynamic> entry) {
    return AppNotification(
      key: _notificationKeyForEntry(entry),
      content: _notificationContentForEntry(entry),
      category: CategoryMapper.toDisplay(entry['category']?.toString()),
      isIncome: entry['type']?.toString() == 'income',
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
                // 입금이면 파란색 계열, 결제/지출이면 기본 색상
                final borderColor = item.isIncome
                    ? Colors.blue.shade100
                    : themeSkyBlue;
                final avatarBg = item.isIncome
                    ? Colors.blue.shade50
                    : themeSkyBlue;
                final iconColor = item.isIncome
                    ? Colors.blue.shade700
                    : themeDarkBlue;
                final textColor = item.isIncome
                    ? Colors.blue.shade700
                    : Colors.black87;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: borderColor, width: 2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: avatarBg,
                        child: Icon(
                          _getIconForCategory(item.category),
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          item.content,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
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
