import 'package:flutter/material.dart';
import 'notification_screen.dart'; // 알림 화면 연동

// --- 가계부(달력 및 내역) 화면 ---
class LedgerScreen extends StatelessWidget {
  const LedgerScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 앱 전체 공통 테마 색상
    final Color themeSkyBlue = const Color(0xFFE8F6F8);
    final Color themeDarkBlue = const Color(0xFF1E105C);
    final Color incomeColor = Colors.blue;          // 수입 색상 (파란색)
    final Color expenseColor = Colors.red.shade400; // 지출 색상 (빨간색)

    // 💡 더미 데이터: 하단 스크롤 리스트에 들어갈 10개의 내역
    final List<Map<String, dynamic>> transactions = [
      {'date': '3.31', 'title': '메가커피 가천대점', 'amount': '-2,000 원', 'isIncome': false, 'icon': Icons.local_cafe},
      {'date': '3.30', 'title': '공유빈', 'amount': '+50,000 원', 'isIncome': true, 'icon': Icons.account_balance_wallet},
      {'date': '3.29', 'title': '호식당', 'amount': '-13,000 원', 'isIncome': false, 'icon': Icons.restaurant},
      {'date': '3.28', 'title': '호식당', 'amount': '-7,800 원', 'isIncome': false, 'icon': Icons.restaurant},
      {'date': '3.25', 'title': 'GS25 가천대점', 'amount': '-4,500 원', 'isIncome': false, 'icon': Icons.storefront},
      {'date': '3.24', 'title': '알바비 입금', 'amount': '+300,000 원', 'isIncome': true, 'icon': Icons.monetization_on},
      {'date': '3.20', 'title': '다이소', 'amount': '-5,000 원', 'isIncome': false, 'icon': Icons.shopping_bag},
      {'date': '3.17', 'title': '올리브영', 'amount': '-24,000 원', 'isIncome': false, 'icon': Icons.face_retouching_natural},
      {'date': '3.15', 'title': '넷플릭스 결제', 'amount': '-13,500 원', 'isIncome': false, 'icon': Icons.movie},
      {'date': '3.10', 'title': '엄마 용돈', 'amount': '+100,000 원', 'isIncome': true, 'icon': Icons.volunteer_activism},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: themeDarkBlue, size: 32),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none, color: themeDarkBlue, size: 32),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ==========================================
          // 1. 상단 달력 영역 (고정됨)
          // ==========================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 월 선택 헤더
                Row(
                  children: [
                    Icon(Icons.chevron_left, color: themeDarkBlue),
                    const SizedBox(width: 10),
                    Text('3월', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: themeDarkBlue)),
                    const SizedBox(width: 10),
                    Icon(Icons.chevron_right, color: themeDarkBlue),
                  ],
                ),
                const SizedBox(height: 20),

                // 달력 그리드 (7열)
                GridView.builder(
                  shrinkWrap: true, // 크기를 내용물에 맞춤
                  physics: const NeverScrollableScrollPhysics(), // 달력 자체는 스크롤 안 되게 고정
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7, // 일주일에 7일
                    childAspectRatio: 0.65, // 칸의 비율 (세로로 약간 길게)
                  ),
                  itemCount: 31, // 31일까지
                  itemBuilder: (context, index) {
                    int day = index + 1;
                    // 예시용 수입/지출 데이터 로직 (시안 느낌 내기)
                    bool hasIncome = day % 7 == 3 || day == 30; // 임의의 날짜에 수입 추가
                    bool hasExpense = day % 3 == 0 || day == 2 || day == 16; // 임의의 지출 추가

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text('$day', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: themeDarkBlue)),
                        const SizedBox(height: 4),
                        if (hasIncome)
                          Text('+2,000', style: TextStyle(fontSize: 9, color: incomeColor)),
                        if (hasExpense)
                          Text('-7,800', style: TextStyle(fontSize: 9, color: expenseColor)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          Divider(color: Colors.grey.shade200, thickness: 8), // 달력과 리스트 구분선

          // ==========================================
          // 2. 하단 내역 리스트 영역 (스크롤됨)
          // ==========================================
          Expanded( // 💡 남은 공간을 꽉 채우고 스크롤 가능하게 만듦
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
              physics: const BouncingScrollPhysics(),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 날짜
                      Text(tx['date'], style: TextStyle(fontWeight: FontWeight.bold, color: themeDarkBlue, fontSize: 14)),
                      const SizedBox(height: 8),
                      // 내역 카드
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: themeSkyBlue, // 하늘색 테마
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            // 아이콘
                            CircleAvatar(
                              backgroundColor: Colors.white,
                              child: Icon(tx['icon'], color: themeDarkBlue, size: 20),
                            ),
                            const SizedBox(width: 15),
                            // 제목
                            Expanded(
                              child: Text(tx['title'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeDarkBlue)),
                            ),
                            // 금액
                            Text(
                              tx['amount'],
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: tx['isIncome'] ? incomeColor : expenseColor
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}