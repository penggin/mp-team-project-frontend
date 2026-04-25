import 'package:flutter/material.dart';
import 'notification_screen.dart'; // 알림 화면 연동

// --- 통계 화면 위젯 ---
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color themeSkyBlue = const Color(0xFFE8F6F8);
    final Color themeDarkBlue = const Color(0xFF1E105C);

    // 💡 10개의 통계용 더미 데이터
    final List<Map<String, dynamic>> recentTransactions = [
      {'title': '메가커피 가천대점', 'amount': '-2,000 원', 'color': Colors.red.shade400, 'icon': Icons.local_cafe},
      {'title': '공유빈', 'amount': '+50,000 원', 'color': Colors.blue, 'icon': Icons.account_balance_wallet},
      {'title': '호식당', 'amount': '-13,000 원', 'color': Colors.red.shade400, 'icon': Icons.restaurant},
      {'title': '김현수', 'amount': '-24,000 원', 'color': Colors.red.shade400, 'icon': Icons.shopping_bag},
      {'title': '스타벅스', 'amount': '-6,500 원', 'color': Colors.red.shade400, 'icon': Icons.local_cafe},
      {'title': '쿠팡 결제', 'amount': '-32,000 원', 'color': Colors.red.shade400, 'icon': Icons.shopping_cart},
      {'title': '편의점 입금', 'amount': '+5,000 원', 'color': Colors.blue, 'icon': Icons.account_balance_wallet},
      {'title': '교보문고', 'amount': '-15,000 원', 'color': Colors.red.shade400, 'icon': Icons.menu_book},
      {'title': '버스/지하철', 'amount': '-1,250 원', 'color': Colors.red.shade400, 'icon': Icons.directions_bus},
      {'title': '용돈 입금', 'amount': '+100,000 원', 'color': Colors.blue, 'icon': Icons.savings},
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
          // 1. 상단 고정 영역 (차트 및 요약)
          // ==========================================
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: themeSkyBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            children: [
                              Icon(Icons.keyboard_arrow_up, color: Colors.black54),
                              Text('3월', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E105C))),
                              Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                            ],
                          ),
                          SizedBox(
                            width: 130,
                            height: 130,
                            child: CustomPaint(
                              painter: DonutChartPainter(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('수입', style: TextStyle(fontSize: 16, color: themeDarkBlue, fontWeight: FontWeight.bold)),
                          const Text('630,000 원', style: TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('지출', style: TextStyle(fontSize: 16, color: themeDarkBlue, fontWeight: FontWeight.bold)),
                          Text('300,300 원', style: TextStyle(fontSize: 18, color: Colors.red.shade400, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                // 최근 내역 헤더
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('최근내역', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeDarkBlue)),
                    Row(
                      children: [
                        _buildTextButton(Icons.calendar_today, '달력 보기', themeSkyBlue, themeDarkBlue),
                        const SizedBox(width: 10),
                        _buildTextButton(Icons.list_alt, '전체 보기', themeSkyBlue, themeDarkBlue),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ==========================================
          // 2. 하단 스크롤 영역 (최근 내역 리스트)
          // ==========================================
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              physics: const BouncingScrollPhysics(), // 부드러운 스크롤 효과
              itemCount: recentTransactions.length,
              itemBuilder: (context, index) {
                final tx = recentTransactions[index];
                return _buildTransactionItem(
                    tx['icon'],
                    tx['title'],
                    tx['amount'],
                    tx['color'],
                    themeSkyBlue,
                    themeDarkBlue
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextButton(IconData icon, String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(IconData icon, String title, String amount, Color amountColor, Color bgColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, color: textColor, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor))),
          Text(amount, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: amountColor)),
        ],
      ),
    );
  }
}

// --- 도넛 차트 페인터 (동일) ---
class DonutChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 25.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final sections = [
      {'value': 50.0, 'color': const Color(0xFF1E105C)},
      {'value': 15.0, 'color': Colors.blue.shade300},
      {'value': 20.0, 'color': Colors.blue.shade100},
      {'value': 15.0, 'color': Colors.grey.shade300},
    ];

    double startAngle = -1.5708;
    for (var section in sections) {
      final sweepAngle = (section['value'] as double) / 100 * 6.2832;
      paint.color = section['color'] as Color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - (strokeWidth / 2)),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}