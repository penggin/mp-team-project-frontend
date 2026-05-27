import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // ✅ 추가
import 'home_screen.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';
import 'category_payment_screen.dart';
import 'main_payment_screen.dart';
import '../app_colors.dart';

// (나중에 가계부, 마이페이지 만들면 여기 추가)

// --- 1. 전체 화면을 관리하는 껍데기 (네비게이션 바 전용) ---
class MainScreen extends StatefulWidget {
  MainScreen({Key? key}) : super(key: globalKey); // ✅ super.key로 변경
  static final GlobalKey<MainScreenState> globalKey =
      GlobalKey<MainScreenState>();

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  // 처음 앱을 켜면 '홈(고래)' 화면(인덱스 2)이 보이도록 설정
  int _selectedIndex = 2;

  void changeTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // 카테고리 탭 전환 시 데이터 동기화용 public 메서드
  void changeTabWithRefresh(int index) {
    setState(() {
      _selectedIndex = index;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  // 하단 탭을 눌렀을 때 보여줄 알맹이 화면들 리스트
  // ✅ CategoryPaymentScreen은 MainPaymentScreen의 상태를 공유하므로
  // build() 안에서 동적으로 생성시켰니다.
  static final GlobalKey<State<MainPaymentScreen>> _paymentKey =
      GlobalKey<State<MainPaymentScreen>>();

  // 탭을 누르면 실행되는 함수
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // ✅ 카테고리 탭(4) 이동 시 잠시 후 다시 setState로
      //    _paymentKey.currentState가 이미 존재하게 되면 데이터가 전달됨
    });
    if (index == 4) {
      // 스케줄러 후 한 프레임 뜜려 상태 동기화
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;
    return Scaffold(
      // 💡 IndexedStack: 화면을 이동해도 영상이 꺼지지 않고 백그라운드에서 유지되게 해주는 마법의 위젯!
      body: Builder(
        builder: (context) {
          // ✅ MainPaymentScreen 상태에서 거래 데이터를 가져와 CategoryPaymentScreen에 주입
          final transactions = MainPaymentScreen.transactionsOf(_paymentKey);
          final groupedIndexes = MainPaymentScreen.groupedIndexesOf(
            _paymentKey,
          );

          final screens = [
            const SettingsScreen(),
            MainPaymentScreen(key: _paymentKey),
            const HomeScreen(),
            const StatisticsScreen(),
            CategoryPaymentScreen(
              transactions: transactions,
              groupedIndexes: groupedIndexes,
            ),
          ];

          return IndexedStack(index: _selectedIndex, children: screens);
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.cardBackground, // ✅ 테마 적용 (하늘색 or 핑크)
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex, // 현재 선택된 탭 알려주기
          onTap: _onItemTapped, // 탭을 눌렀을 때 화면 바꾸기 함수 실행
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: colors.accent, // ✅ 테마 적용 (선택된 아이콘)
          unselectedItemColor: colors.primaryText, // ✅ 테마 적용 (미선택 아이콘)
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
