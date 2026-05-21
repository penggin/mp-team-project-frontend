import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // ✅ 추가
import 'home_screen.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';
import 'category_payment_screen.dart';
import 'ledger_screen.dart';
import '../app_colors.dart';

// (나중에 가계부, 마이페이지 만들면 여기 추가)

// --- 1. 전체 화면을 관리하는 껍데기 (네비게이션 바 전용) ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key}); // ✅ super.key로 변경

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 처음 앱을 켜면 '홈(고래)' 화면(인덱스 2)이 보이도록 설정
  int _selectedIndex = 2;

  // 하단 탭을 눌렀을 때 보여줄 알맹이 화면들 리스트
  final List<Widget> _screens = [
    const SettingsScreen(),                     // 💡 0: 이제 임시 텍스트 대신 진짜 설정 화면이 나옵니다!
    const LedgerScreen(),       // 1: 가계부
    const HomeScreen(),                         // 2: 홈 (기존 고래 화면)
    const StatisticsScreen(),                   // 3: 통계
    const CategoryPaymentScreen(),     // 4: 마이페이지
  ];

  // 탭을 누르면 실행되는 함수
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;
    return Scaffold(
      // 💡 IndexedStack: 화면을 이동해도 영상이 꺼지지 않고 백그라운드에서 유지되게 해주는 마법의 위젯!
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.cardBackground, // ✅ 테마 적용 (하늘색 or 핑크)
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex, // 현재 선택된 탭 알려주기
          onTap: _onItemTapped,         // 탭을 눌렀을 때 화면 바꾸기 함수 실행
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: colors.accent,      // ✅ 테마 적용 (선택된 아이콘)
          unselectedItemColor: colors.primaryText, // ✅ 테마 적용 (미선택 아이콘)
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined, size: 30), label: '설정'),
            BottomNavigationBarItem(icon: Icon(Icons.list_outlined, size: 30), label: '가계부'),
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined, size: 30), label: '홈'),
            BottomNavigationBarItem(icon: Icon(Icons.pie_chart_outline, size: 30), label: '통계'),
            BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined, size: 30), label: '마이페이지'),
          ],
        ),
      ),
    );
  }
}