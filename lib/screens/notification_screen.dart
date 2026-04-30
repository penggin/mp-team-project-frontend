import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:sqflite/sqflite.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import '../background_task_handler.dart';

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

  @override
  void initState() {
    super.initState();
    _startForegroundService();
    _loadFromLocalDB();
    _listenFromBackground();
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

  void _listenFromBackground() {
    FlutterForegroundTask.addTaskDataCallback((data) {
      if (data is Map<String, dynamic>) {
        setState(() {
          _notifications.insert(
            0,
            AppNotification(
              content: (data['content'] ?? '') as String,
              category: (data['category'] ?? '미분류') as String,
            ),
          );
        });
      }
    });
  }

  // 알림을 직접 수신 (백그라운드 서비스 거치지 않음)
  void _listenNotificationsDirect() {
    NotificationListenerService.notificationsStream.listen((event) {
      final content = event.content ?? '';
      if (content.isEmpty) return;

      setState(() {
        _notifications.insert(
          0,
          AppNotification(
            content: content,
            category: '미분류',
          ),
        );
      });
    });
  }

  Future<void> _loadFromLocalDB() async {
    try {
      final db = await openDatabase(
        'payments.db',
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS payments (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              content TEXT,
              category TEXT,
              timestamp INTEGER
            )
          ''');
        },
      );
      final rows = await db.query('payments', orderBy: 'timestamp DESC');
      await db.close();

      setState(() {
        _notifications = rows.map((row) => AppNotification(
          content: (row['content'] ?? '') as String,
          category: (row['category'] ?? '미분류') as String,
        )).toList();
      });
    } catch (e) {
      print('DB 로드 에러: $e');
    }
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'CAFE':
      case 'FOOD':
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
      ),
      body: _notifications.isEmpty
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