import 'package:flutter/material.dart';
import 'notification_screen.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';
import '../services/api_service.dart';
import '../services/category_mapper.dart';
import 'app_drawer.dart';

// --- 통계 대시보드 화면 위젯 ---
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();

  /// 외부(main_screen 탭 전환 등)에서 통계 새로고침 트리거
  static void reload(GlobalKey<State<StatisticsScreen>> key) {
    final s = key.currentState;
    if (s is _StatisticsScreenState) s._loadStats();
  }
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  static final List<Color> _chartColors = [
    Colors.blue,
    Colors.cyanAccent.shade400,
    Colors.redAccent.shade200,
    Colors.grey.shade400,
    Colors.green.shade300,
  ];

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _trendStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final trendStartMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month - 5,
    );

    print('[통계] 🔄 _loadStats — 선택 월: ${_selectedMonth.year}-${_selectedMonth.month}');

    // 전용 stats API는 신뢰 못 함 → 알림창과 동일한 /api/v1/ledger 직접 사용
    final stats = await _computeStatsFromLedger(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    final trendStats = await _computeTrendFromLedger(
      trendStartMonth,
      _selectedMonth,
    );

    print('[통계] ✅ stats: total_income=${stats['total_income']} total_expense=${stats['total_expense']} categories=${(stats['category_totals'] as List).length}');
    print('[통계] ✅ trend months=${(trendStats['months'] as List).length}');

    if (!mounted) return;
    setState(() {
      _stats = stats;
      _trendStats = trendStats;
      _isLoading = false;
    });
  }

  /// 전용 stats API 실패 시 — `/api/v1/ledger` 응답으로 직접 집계
  Future<Map<String, dynamic>> _computeStatsFromLedger(
    int year,
    int month,
  ) async {
    // 1) year/month 필터 시도, 2) 비어있으면 전체 받아서 클라이언트단 필터
    List<Map<String, dynamic>> entries = await ApiService.getLedgerEntries(
      year: year,
      month: month,
    );
    if (entries.isEmpty) {
      final all = await ApiService.getLedgerEntries();
      entries = all.where((e) {
        final dt = DateTime.tryParse(
          (e['transaction_at'] ?? e['created_at'] ?? '') as String,
        );
        if (dt == null) return false;
        final local = dt.toLocal();
        return local.year == year && local.month == month;
      }).toList();
    }

    int totalIncome = 0;
    int totalExpense = 0;
    final Map<String, int> categoryTotals = {};

    for (final e in entries) {
      final type = e['type']?.toString();
      final amount = (e['amount'] as num?)?.toInt() ?? 0;
      if (type == 'income') {
        totalIncome += amount;
      } else if (type == 'expense') {
        totalExpense += amount;
        final cat = e['category']?.toString() ?? 'others';
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amount;
      }
    }

    return {
      'total_income': totalIncome,
      'total_expense': totalExpense,
      'category_totals': categoryTotals.entries
          .map((e) => {'category': e.key, 'amount': e.value})
          .toList(),
      'budget_progress': <Map<String, dynamic>>[],
    };
  }

  /// 6개월 추이 데이터 직접 집계
  Future<Map<String, dynamic>> _computeTrendFromLedger(
    DateTime start,
    DateTime end,
  ) async {
    // 모든 ledger를 한 번에 받아 월별로 집계
    final all = await ApiService.getLedgerEntries();
    final Map<String, int> byMonth = {};

    for (final e in all) {
      if (e['type']?.toString() != 'expense') continue;
      final dt = DateTime.tryParse(
        (e['transaction_at'] ?? e['created_at'] ?? '') as String,
      );
      if (dt == null) continue;
      final local = dt.toLocal();
      final key = '${local.year}-${local.month}';
      final amount = (e['amount'] as num?)?.toInt() ?? 0;
      byMonth[key] = (byMonth[key] ?? 0) + amount;
    }

    final months = <Map<String, dynamic>>[];
    DateTime cur = DateTime(start.year, start.month);
    final endMonth = DateTime(end.year, end.month);
    while (!cur.isAfter(endMonth)) {
      final key = '${cur.year}-${cur.month}';
      months.add({
        'year': cur.year,
        'month': cur.month,
        'total_expense': byMonth[key] ?? 0,
      });
      cur = DateTime(cur.year, cur.month + 1);
    }
    return {'months': months};
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
    _loadStats();
  }

  int _intStat(String key) {
    final value = _stats?[key];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<Map<String, dynamic>> get _categoryTotals {
    final values = _stats?['category_totals'];
    if (values is! List) return [];
    return values
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> get _budgetProgress {
    final values = _stats?['budget_progress'];
    if (values is! List) return [];
    return values
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> get _trendMonths {
    final values = _trendStats?['months'];
    if (values is! List) return [];
    final months = values
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    months.sort((a, b) {
      final leftYear = _intValue(a['year']);
      final leftMonth = _intValue(a['month']);
      final rightYear = _intValue(b['year']);
      final rightMonth = _intValue(b['month']);
      return DateTime(
        leftYear,
        leftMonth,
      ).compareTo(DateTime(rightYear, rightMonth));
    });
    return months;
  }

  List<_TrendPoint> get _trendPoints {
    return _trendMonths.map((month) {
      final year = _intValue(month['year']);
      final monthNumber = _intValue(month['month']);
      return _TrendPoint(
        label: '$monthNumber월',
        sortDate: DateTime(year, monthNumber),
        amount: _intValue(month['total_expense']).toDouble(),
      );
    }).toList();
  }

  int get _totalBudget {
    return _budgetProgress.fold<int>(
      0,
      (sum, item) => sum + _intValue(item['monthly_limit']),
    );
  }

  int get _budgetSpent {
    final spent = _budgetProgress.fold<int>(
      0,
      (sum, item) => sum + _intValue(item['spent']),
    );
    return spent == 0 ? _intStat('total_expense') : spent;
  }

  int _intValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatAmount(int amount) {
    return '${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} 원';
  }

  String _topCategoryMessage() {
    final totals = _categoryTotals;
    if (totals.isEmpty) return '이번 달 지출 카테고리 데이터가 아직 없어요';

    totals.sort((a, b) {
      final left = (a['amount'] as num?)?.toInt() ?? 0;
      final right = (b['amount'] as num?)?.toInt() ?? 0;
      return right.compareTo(left);
    });
    final top = totals.first;
    return '이번달은 ${CategoryMapper.toDisplay(top['category']?.toString())}에서 많은 돈이 사용됐어요!';
  }

  String _budgetMessage() {
    final over = _budgetProgress.where((item) => item['is_over_limit'] == true);
    if (over.isNotEmpty) {
      return '${CategoryMapper.toDisplay(over.first['category']?.toString())} 예산을 초과했어요';
    }
    if (_budgetProgress.isEmpty) return '예산을 설정하면 사용 현황을 볼 수 있어요';
    return '이번 달 예산 안에서 사용 중이에요';
  }

  String _trendMessage() {
    final points = _trendPoints.where((point) => point.amount > 0).toList();
    if (points.length < 2) {
      final totalExpense = _intStat('total_expense');
      if (totalExpense == 0) return '최근 지출 추이 데이터가 아직 없어요';
      return '이번 달 지출은 ${_formatAmount(totalExpense)}입니다';
    }

    final current = points.last.amount.toInt();
    final previous = points[points.length - 2].amount.toInt();
    final diff = current - previous;
    if (diff > 0) return '전월보다 ${_formatAmount(diff)} 더 사용했어요';
    if (diff < 0) return '전월보다 ${_formatAmount(diff.abs())} 줄었어요';
    return '전월과 같은 수준으로 사용했어요';
  }

  List<_ChartSection> _chartSections(List<Map<String, dynamic>> totals) {
    return totals
        .asMap()
        .entries
        .map((entry) {
          final amount = (entry.value['amount'] as num?)?.toDouble() ?? 0;
          return _ChartSection(
            value: amount,
            color: _chartColors[entry.key % _chartColors.length],
          );
        })
        .where((section) => section.value > 0)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().colors;

    final Color themeSkyBlue = theme.cardBackground;
    final Color themeDarkBlue = theme.primaryText;
    final categoryTotals = _categoryTotals;
    final totalIncome = _intStat('total_income');
    final totalExpense = _intStat('total_expense');
    final trendPoints = _trendPoints;
    final totalBudget = _totalBudget;
    final budgetSpent = _budgetSpent;

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
            icon: Icon(
              Icons.notifications_none,
              color: themeDarkBlue,
              size: 32,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading && _stats == null
          ? Center(child: CircularProgressIndicator(color: themeDarkBlue))
          : SingleChildScrollView(
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
                                IconButton(
                                  icon: Icon(
                                    Icons.keyboard_arrow_up,
                                    color: themeDarkBlue,
                                  ),
                                  onPressed: () => _changeMonth(-1),
                                ),
                                Text(
                                  '${_selectedMonth.month}월',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: themeDarkBlue,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.keyboard_arrow_down,
                                    color: themeDarkBlue,
                                  ),
                                  onPressed: () => _changeMonth(1),
                                ),
                              ],
                            ),
                            SizedBox(
                              width: 150,
                              height: 150,
                              child: CustomPaint(
                                painter: _DonutChartPainter(
                                  primaryColor: themeDarkBlue,
                                  sections: _chartSections(categoryTotals),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '수입',
                              style: TextStyle(
                                fontSize: 16,
                                color: themeDarkBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _formatAmount(totalIncome),
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '지출',
                              style: TextStyle(
                                fontSize: 16,
                                color: themeDarkBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _formatAmount(totalExpense),
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. 꺾은선 차트 카드 (최근 월별 지출 추이)
                  _buildCardWrapper(
                    themeSkyBlue,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '최근 6개월 지출 추이',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: themeDarkBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(color: Colors.grey.shade300),
                              bottom: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: CustomPaint(
                            painter: _LineChartPainter(
                              primaryColor: themeDarkBlue,
                              points: trendPoints,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildLegendItem(
                              trendPoints.isEmpty
                                  ? '-'
                                  : trendPoints.first.label,
                              Colors.grey.shade400,
                            ),
                            const SizedBox(width: 10),
                            _buildLegendItem(
                              trendPoints.isEmpty
                                  ? '-'
                                  : trendPoints.last.label,
                              themeDarkBlue.withValues(alpha: 0.2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Text(
                          _trendMessage(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: themeDarkBlue,
                          ),
                        ),
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
                        Text(
                          _formatAmount(totalExpense),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: themeDarkBlue,
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildStackedBar(categoryTotals),
                        const SizedBox(height: 15),
                        Text(
                          _topCategoryMessage(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: themeDarkBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. 세로 막대 차트 카드 (예산 대비 지출)
                  _buildCardWrapper(
                    themeSkyBlue,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              color: themeDarkBlue,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '예산 현황',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: themeDarkBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _budgetMessage(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: themeDarkBlue,
                          ),
                        ),
                        const SizedBox(height: 30),
                        _buildBudgetBars(
                          totalBudget: totalBudget,
                          spent: budgetSpent,
                          primaryColor: themeDarkBlue,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. 하단 요약 카드 (카테고리별 지출)
                  _buildCardWrapper(
                    themeSkyBlue,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '카테고리별 지출 비중',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: themeDarkBlue,
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildStackedBar(categoryTotals),
                        const SizedBox(height: 15),
                        Text(
                          _budgetMessage(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: themeDarkBlue,
                          ),
                        ),
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
  Widget _buildStackedBar(List<Map<String, dynamic>> categoryTotals) {
    final sections = _chartSections(categoryTotals);
    final total = sections.fold<double>(
      0,
      (sum, section) => sum + section.value,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 30,
        child: sections.isEmpty
            ? Container(color: Colors.grey.shade300)
            : Row(
                children: sections.map((section) {
                  final flex = (section.value / total * 100).round();
                  return Expanded(
                    flex: flex < 1 ? 1 : flex,
                    child: Container(color: section.color),
                  );
                }).toList(),
              ),
      ),
    );
  }

  // 세로 막대 그래프 생성기
  Widget _buildVerticalBar(String label, double height, Color color) {
    return Column(
      children: [
        Container(width: 35, height: height, color: color),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildBudgetBars({
    required int totalBudget,
    required int spent,
    required Color primaryColor,
  }) {
    final maxAmount = [totalBudget, spent, 1].reduce((a, b) => a > b ? a : b);
    const maxHeight = 120.0;
    const minHeight = 24.0;

    double scaledHeight(int amount) {
      if (amount <= 0) return minHeight;
      return (amount / maxAmount * maxHeight).clamp(minHeight, maxHeight);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildVerticalBar(
          '예산 ${_formatAmount(totalBudget)}',
          scaledHeight(totalBudget),
          Colors.grey.shade400,
        ),
        const SizedBox(width: 30),
        _buildVerticalBar(
          '지출 ${_formatAmount(spent)}',
          scaledHeight(spent),
          primaryColor,
        ),
      ],
    );
  }

  // 범례(Legend) 아이템 생성기
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 25, height: 10, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _ChartSection {
  final double value;
  final Color color;

  const _ChartSection({required this.value, required this.color});
}

class _TrendPoint {
  final String label;
  final DateTime sortDate;
  final double amount;

  const _TrendPoint({
    required this.label,
    required this.sortDate,
    required this.amount,
  });
}

// ==========================================
// 🎨 도넛 차트를 그리는 페인터 (기존 유지 + 비율 조정)
// ==========================================
class _DonutChartPainter extends CustomPainter {
  final Color primaryColor;
  final List<_ChartSection> sections;

  _DonutChartPainter({required this.primaryColor, required this.sections});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 35.0; // 시안처럼 두껍게

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    if (sections.isEmpty) {
      paint.color = primaryColor.withValues(alpha: 0.12);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - (strokeWidth / 2)),
        0,
        6.2832,
        false,
        paint,
      );
      return;
    }

    final total = sections.fold<double>(
      0,
      (sum, section) => sum + section.value,
    );

    double startAngle = -1.5708; // 12시 방향
    for (final section in sections) {
      final sweepAngle = section.value / total * 6.2832;
      paint.color = section.color;
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
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.sections != sections;
  }
}

// ==========================================
// 📈 꺾은선 차트를 그리는 페인터 (백엔드 월별 지출 추이)
// ==========================================
class _LineChartPainter extends CustomPainter {
  final Color primaryColor;
  final List<_TrendPoint> points;

  _LineChartPainter({required this.primaryColor, required this.points});
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = h * i / 4;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    final usablePoints = points.where((point) => point.amount >= 0).toList()
      ..sort((a, b) => a.sortDate.compareTo(b.sortDate));
    if (usablePoints.isEmpty) return;

    final maxAmount = usablePoints.fold<double>(
      1,
      (max, point) => point.amount > max ? point.amount : max,
    );
    final stepX = usablePoints.length == 1
        ? 0.0
        : w / (usablePoints.length - 1);

    Offset offsetFor(int index, _TrendPoint point) {
      final x = usablePoints.length == 1 ? w / 2 : stepX * index;
      final ratio = point.amount / maxAmount;
      final y = h - (ratio * h * 0.82) - (h * 0.08);
      return Offset(x, y.clamp(h * 0.08, h * 0.92));
    }

    final linePath = Path();
    final areaPath = Path();
    for (var i = 0; i < usablePoints.length; i++) {
      final point = offsetFor(i, usablePoints[i]);
      if (i == 0) {
        linePath.moveTo(point.dx, point.dy);
        areaPath.moveTo(point.dx, h);
        areaPath.lineTo(point.dx, point.dy);
      } else {
        linePath.lineTo(point.dx, point.dy);
        areaPath.lineTo(point.dx, point.dy);
      }
    }
    areaPath.lineTo(usablePoints.length == 1 ? w / 2 : w, h);
    areaPath.close();

    final areaPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dotPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(areaPath, areaPaint);
    canvas.drawPath(linePath, linePaint);
    for (var i = 0; i < usablePoints.length; i++) {
      canvas.drawCircle(offsetFor(i, usablePoints[i]), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.points != points;
  }
}
