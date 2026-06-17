import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'home_screen.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';
import 'category_payment_screen.dart';
import 'main_payment_screen.dart';
import '../app_colors.dart';
import '../background_task_handler.dart';
import '../services/experience_service.dart';
import '../services/location_service.dart';
import '../services/payment_push_notification_service.dart';

class MainScreen extends StatefulWidget {
  MainScreen({Key? key}) : super(key: globalKey);
  static final GlobalKey<MainScreenState> globalKey =
      GlobalKey<MainScreenState>();
  // HomeScreen 에 결제 신호를 직접 전달하기 위한 키
  static final GlobalKey<HomeScreenState> homeKey =
      GlobalKey<HomeScreenState>();

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 2;

  // GlobalKey를 상수로 선언 — build()마다 재생성 방지
  static final GlobalKey<State<MainPaymentScreen>> _paymentKey =
      GlobalKey<State<MainPaymentScreen>>();
  static final GlobalKey<State<StatisticsScreen>> _statisticsKey =
      GlobalKey<State<StatisticsScreen>>();

  // IndexedStack에 넘길 화면 목록. 한 번만 생성해서 재사용.
  // CategoryPaymentScreen만 _paymentKey 상태를 참조하므로 탭 전환 시 build()를 타야 하는데,
  // IndexedStack 특성상 자식 위젯은 유지되므로 별도 새로고침 없이 최신 데이터를 공유한다.
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const SettingsScreen(),
      MainPaymentScreen(key: _paymentKey),
      HomeScreen(key: MainScreen.homeKey),
      StatisticsScreen(key: _statisticsKey),
      CategoryPaymentScreen(
        transactions: MainPaymentScreen.transactionsOf(_paymentKey),
        groupedIndexes: MainPaymentScreen.groupedIndexesOf(_paymentKey),
        groups: MainPaymentScreen.groupsOf(_paymentKey),
        currentMonth: MainPaymentScreen.currentMonthOf(_paymentKey),
      ),
    ];
    _startForegroundService();
    // 백그라운드 결제 신호 수신 등록
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    super.dispose();
  }

  /// 백그라운드에서 결제 건이 저장될 때 호출됨.
  /// 금액이 기준값 이상이면 HomeScreen 에 팝업 표시를 요청한다.
  void _onTaskData(Object data) {
    if (data is! Map) {
      debugPrint('[BudgetAlert] _onTaskData: Map이 아님 — $data');
      return;
    }
    if (data['action'] != 'refresh') {
      debugPrint("[BudgetAlert] _onTaskData: action=${data['action']} — 무시");
      return;
    }
    final rawAmount = data['amount'];
    final amount = rawAmount is int ? rawAmount : int.tryParse('$rawAmount') ?? 0;
    debugPrint('[BudgetAlert] _onTaskData 수신: amount=$amount, homeKey=${MainScreen.homeKey.currentState != null}');
    MainScreen.homeKey.currentState?.onPaymentReceived(amount);
  }

  Future<void> _startForegroundService() async {
    await PaymentPushNotificationService.instance.requestPermissions();
    await LocationService.ensurePermission();
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: '가계부 키우기',
      notificationText: '결제 내역을 자동으로 기록 중',
      callback: startCallback,
    );
  }

  void changeTab(int index) {
    setState(() => _selectedIndex = index);
  }

  void changeTabWithRefresh(int index) {
    setState(() => _selectedIndex = index);
    // CategoryPaymentScreen의 경우 _paymentKey 상태를 재읽어야 하므로
    // 탭 전환 후 한 프레임 뒤에 setState를 한 번 더 호출한다.
    if (index == 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (index == 1) {
        MainPaymentScreen.reload(_paymentKey);
      } else if (index == 3) {
        StatisticsScreen.reload(_statisticsKey);
      } else if (index == 4) {
        // CategoryPaymentScreen이 최신 데이터를 반영하도록 setState 한 번 더
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;

    // CategoryPaymentScreen(index 4)은 _paymentKey 상태 변화 시 최신 데이터 주입 필요.
    // 탭 전환마다 해당 항목만 교체한다 (나머지 화면은 캐시 유지).
    final screens = List<Widget>.from(_screens);
    if (_selectedIndex == 4) {
      screens[4] = CategoryPaymentScreen(
        transactions: MainPaymentScreen.transactionsOf(_paymentKey),
        groupedIndexes: MainPaymentScreen.groupedIndexesOf(_paymentKey),
        groups: MainPaymentScreen.groupsOf(_paymentKey),
        currentMonth: MainPaymentScreen.currentMonthOf(_paymentKey),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: colors.cardBackground),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: colors.accent,
          unselectedItemColor: colors.primaryText,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined, size: 30),
              label: '설정',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_outlined, size: 30),
              label: '가계부',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 30),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart_outline, size: 30),
              label: '통계',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined, size: 30),
              label: '마이페이지',
            ),
          ],
        ),
      ),
    );
  }
}
