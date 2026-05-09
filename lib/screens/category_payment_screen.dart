import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // ✅ 추가
import 'notification_screen.dart';// 💡 알림 화면으로 넘어가기 위해 초대!
import '../app_colors.dart';

// --- 마이페이지 (가계부 내역) 화면 ---
class CategoryPaymentScreen extends StatelessWidget {
  const CategoryPaymentScreen({super.key});
  @override
  Widget build(BuildContext context) {
    // 앱 전체 공통 테마 색상
    final colors = context.watch<ThemeProvider>().colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: colors.primaryText, size: 32),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none, color: colors.primaryText, size: 32),
            onPressed: () {
              // 알림 화면 연동
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // 1. 상단 총액 및 막대그래프 카드
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: colors.background, // 하늘색 배경
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 월 선택
                  Row(
                    children: [
                      Icon(Icons.chevron_left, color: colors.primaryText  ),
                      const SizedBox(width: 5),
                      Text('3월', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.primaryText)),
                      const SizedBox(width: 5),
                      Icon(Icons.chevron_right, color: colors.primaryText),
                    ],
                  ),
                  const SizedBox(height: 15),
                  // 총액
                  Text('578,450원', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colors.primaryText)),
                  const SizedBox(height: 25),
                  // 💡 누적 막대그래프 (비율에 맞춰서 너비가 결정됩니다)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 20,
                      child: Row(
                        children: [
                          Expanded(flex: 35, child: Container(color: Colors.indigo.shade300)),
                          Expanded(flex: 15, child: Container(color: Colors.grey.shade300)),
                          Expanded(flex: 8, child: Container(color: Colors.yellow.shade600)),
                          Expanded(flex: 5, child: Container(color: Colors.red.shade400)),
                          Expanded(flex: 3, child: Container(color: Colors.green.shade300)),
                          Expanded(flex: 2, child: Container(color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // 2. 카테고리별 리스트 내역
            _buildCategoryItem('이체', '350,000 원', Colors.indigo.shade300, colors),
            _buildCategoryItem('카테고리 없음', '158,000 원', Colors.grey.shade300, colors),
            _buildCategoryItem('식비', '84,000 원', Colors.yellow.shade600, colors),
            _buildCategoryItem('쇼핑, 여가', '47,000 원', Colors.red.shade400, colors),
            _buildCategoryItem('여행, 숙박', '33,000 원', Colors.green.shade300, colors),
            _buildCategoryItem('카페', '5,000 원', Colors.brown.shade300, colors),
            _buildCategoryItem('편의점, 마트, 잡화', '2,000 원', Colors.grey.shade500, colors),

            const SizedBox(height: 80), // 떠 있는 버튼(FAB)을 가리지 않게 아래 여백 추가
          ],
        ),
      ),

      // 3. 우측 하단 추가(+) 버튼
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 내역 추가 화면 띄우기
        },
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
          side: BorderSide(color: colors.background, width: 2), // 하늘색 테두리
        ),
        elevation: 2,
        child: Icon(Icons.add, color: colors.accent, size: 30),
      ),
    );
  }

  // 반복되는 리스트 아이템을 그려주는 헬퍼 함수
  Widget _buildCategoryItem(String title, String amount, Color indicatorColor, ThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBackground, // ✅
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 12, backgroundColor: indicatorColor),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.primaryText, // ✅
              ),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.primaryText, // ✅
            ),
          ),
        ],
      ),
    );
  }
}