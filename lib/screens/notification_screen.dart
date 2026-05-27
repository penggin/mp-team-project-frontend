import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import '../background_task_handler.dart';
import '../services/api_service.dart';
import '../services/notification_processing.dart';

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
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadFromBackend();
    _startForegroundServiceIfNeeded();
    _listenNotificationsDirect();
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    // 3초마다 폴링 (백그라운드 IPC 불안정 대비)
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _loadFromBackend();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _onReceiveTaskData(dynamic data) {
    if (!mounted) return;
    _loadFromBackend();
  }

  Future<void> _startForegroundServiceIfNeeded() async {
    if (await FlutterForegroundTask.isRunningService) return;
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
    print('[알림창] 조회된 항목 수: ${entries.length}');

    if (!mounted) return;
    setState(() {
      // 최신순 정렬: transaction_at 기준 내림차순
      final sorted = List<Map<String, dynamic>>.from(entries);
      sorted.sort((a, b) {
        final aStr = (a['transaction_at'] ?? a['created_at'] ?? '') as String;
        final bStr = (b['transaction_at'] ?? b['created_at'] ?? '') as String;
        return bStr.compareTo(aStr);
      });

      _notifications = sorted.map((entry) {
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

  // 실시간 알림 수신 → 백그라운드 서비스가 놓친 경우 보완용
  void _listenNotificationsDirect() {
    _notificationSubscription?.cancel();
    _notificationSubscription = NotificationListenerService.notificationsStream
        .listen(
          (event) => _handleNotificationEvent(event),
          onError: (error) => print('알림 스트림 에러: $error'),
        );
  }

  Future<void> _handleNotificationEvent(ServiceNotificationEvent event) async {
    final candidate = NotificationProcessing.candidateFromEvent(event);
    if (candidate == null) return;

    if (_processedNotificationFingerprints.contains(candidate.fingerprint)) return;
    _processedNotificationFingerprints.add(candidate.fingerprint);

    print('알림 감지(stream): ${candidate.rawText}');

    final parsed = await ApiService.parseTransaction(candidate.rawText);
    if (parsed == null) return;

    final saved = await ApiService.createLedgerEntry(parsed);
    if (!saved || !mounted) return;

    await _loadFromBackend();
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
