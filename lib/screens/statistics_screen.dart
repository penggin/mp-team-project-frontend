import 'package:flutter/material.dart';
import 'notification_screen.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';
import 'app_drawer.dart';

// --- 통계 대시보드 화면 위젯 ---
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    final theme = context.watch<ThemeProvider>().colors;

    final Color themeSkyBlue = theme.cardBackground;
    final Color themeDarkBlue = theme.primaryText;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu, color: themeDarkBlue, size: 32),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
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
      // 💡 다양한 크기의 카드들이 들어가므로 스크롤 가능하게 설정
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 도넛 차트 카드
            _buildCardWrapper(
              themeSkyBlue,
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          Icon(Icons.keyboard_arrow_up, color: themeDarkBlue),
                          Text('3월', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: themeDarkBlue)),
                          Icon(Icons.keyboard_arrow_down, color: themeDarkBlue),
                        ],
                      ),
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: CustomPaint(
                          painter: DonutChartPainter(
                            primaryColor: themeDarkBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
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
                      Text('300,300 원', style: TextStyle(fontSize: 18, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. 꺾은선 차트 카드 (지난달 비교)
            _buildCardWrapper(
              themeSkyBlue,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.chevron_left, color: themeDarkBlue),
                      Text(' 3월 ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeDarkBlue)),
                      Icon(Icons.chevron_right, color: themeDarkBlue),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 💡 꺾은선 그래프 영역
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: Colors.grey.shade300), bottom: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: CustomPaint(
                      painter: LineChartPainter(
                        primaryColor: themeDarkBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 범례
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildLegendItem('2월', Colors.grey.shade400),
                      const SizedBox(width: 10),
                      _buildLegendItem('3월', themeDarkBlue.withOpacity(0.2)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text('지난달보다 7만원 절약했어요!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeDarkBlue)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. 가로 막대 차트 카드 (이번달 요약)
            _buildCardWrapper(
              themeSkyBlue,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('578,450원', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeDarkBlue)),
                  const SizedBox(height: 15),
                  _buildStackedBar(),
                  const SizedBox(height: 15),
                  Text('이번달은 이체에서 많은 돈이 사용됐어요!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: themeDarkBlue)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. 세로 막대 차트 카드 (또래 비교)
            _buildCardWrapper(
              themeSkyBlue,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline, color: themeDarkBlue, size: 28),
                      const SizedBox(width: 8),
                      Text('또래보다', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeDarkBlue)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text('20만원 더 적게 사용했어요!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeDarkBlue)),
                  const SizedBox(height: 30),
                  // 세로 막대 그래프
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildVerticalBar('또래', 120, Colors.grey.shade400),
                      const SizedBox(width: 30),
                      _buildVerticalBar('나', 80, themeDarkBlue),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 5. 하단 요약 카드 (또래 비교 2)
            _buildCardWrapper(
              themeSkyBlue,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('내 또래는 여기에서 많은 금액을 썼어요!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeDarkBlue)),
                  const SizedBox(height: 15),
                  _buildStackedBar(),
                  const SizedBox(height: 15),
                  Text('식비에 많은 금액을 평균 30만원을 썼어요', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: themeDarkBlue)),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- 헬퍼 함수들 ---

  // 카드 모양을 만들어주는 공통 래퍼
  Widget _buildCardWrapper(Color bgColor, Widget child) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  // 가로 누적 막대 그래프 생성기
  Widget _buildStackedBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 30,
        child: Row(
          children: [
            Expanded(flex: 40, child: Container(color: const Color(0xFF1E105C))),
            Expanded(flex: 20, child: Container(color: Colors.grey.shade400)),
            Expanded(flex: 15, child: Container(color: Colors.blue.shade400)),
            Expanded(flex: 15, child: Container(color: Colors.redAccent.shade200)),
            Expanded(flex: 10, child: Container(color: Colors.green.shade300)),
          ],
        ),
      ),
    );
  }

  // 세로 막대 그래프 생성기
  Widget _buildVerticalBar(String label, double height, Color color) {
    return Column(
      children: [
        Container(
          width: 35,
          height: height,
          color: color,
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  // 범례(Legend) 아이템 생성기
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 25, height: 10, color: color),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ==========================================
// 🎨 도넛 차트를 그리는 페인터 (기존 유지 + 비율 조정)
// ==========================================
class DonutChartPainter extends CustomPainter {
  final Color primaryColor;
  DonutChartPainter({required this.primaryColor});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 35.0; // 시안처럼 두껍게

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final sections = [
      {'value': 50.0, 'color': Colors.blue}, // 50%
      {'value': 10.0, 'color': Colors.cyanAccent.shade400}, // 7%
      {'value': 15.0, 'color': Colors.red.shade100}, // 10%
      {'value': 15.0, 'color': Colors.grey.shade100}, // 20%
      {'value': 10.0, 'color': Colors.grey.shade300}, // 13%
    ];

    double startAngle = -1.5708; // 12시 방향
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

// ==========================================
// 📈 꺾은선 차트를 그리는 페인터 (2월, 3월 비교)
// ==========================================
class LineChartPainter extends CustomPainter {
  final Color primaryColor;

  LineChartPainter({required this.primaryColor});
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. 2월 데이터 (회색)
    final path1 = Path();
    path1.moveTo(0, h * 0.8);
    path1.lineTo(w * 0.3, h * 0.7);
    path1.lineTo(w * 0.6, h * 0.4);
    path1.lineTo(w, h * 0.2);
    path1.lineTo(w, h);
    path1.lineTo(0, h);
    path1.close();

    // 2. 3월 데이터 (파란색)
    final path2 = Path();
    path2.moveTo(0, h * 0.9);
    path2.lineTo(w * 0.4, h * 0.6);
    path2.lineTo(w * 0.7, h * 0.3);
    path2.lineTo(w, h * 0.05);
    path2.lineTo(w, h);
    path2.lineTo(0, h);
    path2.close();

    // 칠하기
    final paint1 = Paint()..color = Colors.grey.shade200 ..style = PaintingStyle.fill;
    final paint2 = Paint()..color = primaryColor.withOpacity(0.08) ..style = PaintingStyle.fill;

    // 테두리 선
    final strokePaint1 = Paint()..color = Colors.grey.shade400 ..style = PaintingStyle.stroke ..strokeWidth = 2;
    final strokePaint2 = Paint()..color = primaryColor ..style = PaintingStyle.stroke ..strokeWidth = 2;

    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);

    // 윗부분 선만 따로 그리기 (밑면 제외)
    final strokePath1 = Path()
      ..moveTo(0, h * 0.8)
      ..lineTo(w * 0.3, h * 0.7)
      ..lineTo(w * 0.6, h * 0.4)
      ..lineTo(w, h * 0.2);
    canvas.drawPath(strokePath1, strokePaint1);

    final strokePath2 = Path()
      ..moveTo(0, h * 0.9)
      ..lineTo(w * 0.4, h * 0.6)
      ..lineTo(w * 0.7, h * 0.3)
      ..lineTo(w, h * 0.05);
    canvas.drawPath(strokePath2, strokePaint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}