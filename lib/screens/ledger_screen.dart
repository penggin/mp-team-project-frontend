import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'notification_screen.dart';
import 'package:first/app_colors.dart';
import 'package:first/services/api_service.dart';
import 'package:first/services/category_mapper.dart';
import 'main_screen.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final Color incomeColor = Colors.blue;
  final Color expenseColor = Colors.red;

  int? selectedDay;
  final ScrollController _scrollController = ScrollController();

  // 날짜별 첫 번째 아이템 key (스크롤 앵커용)
  final Map<String, GlobalKey> _dateKeys = {};
  // 각 거래 아이템별 key (index → key)
  final Map<int, GlobalKey> _itemKeys = {};
  // 달력 API 응답의 days[] 데이터 (day → {income, expense, is_over_budget_risk_day})
  final Map<int, Map<String, dynamic>> _calendarDays = {};

  // 날짜 선택 시 보여줄 필터된 리스트 (null이면 전체 표시)
  List<Map<String, dynamic>> get _displayTransactions {
    if (selectedDay == null) return transactions;
    final targetDate = '$currentMonth.$selectedDay';
    return transactions.where((tx) => tx['date'] == targetDate).toList();
  }

  // ✅ 더미 데이터 → 실제 데이터로 교체
  List<Map<String, dynamic>> transactions = [];
  bool isLoading = true;
  String? errorMessage;

  // ✅ 현재 표시 중인 연/월
  int currentYear = DateTime.now().year;
  int currentMonth = DateTime.now().month;

  // 달력 API 메타 정보 (예산 초과 위험 구간 판단용)
  int? _overBudgetStartDay;
  double _dailyAvgExpense = 0;
  bool _budgetConfigured = false;
  bool _isCurrentMonth = false;

  @override
  void initState() {
    super.initState();
    _fetchLedgerData();
  }

  // ─── 달력 API + 가계부 목록 API 병렬 호출 ────────────────────────
  Future<void> _fetchLedgerData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // 달력 데이터(날짜별 합계 + 예산 초과 위험일)와
      // 가계부 목록(상세 리스트)을 병렬 호출
      final results = await Future.wait([
        ApiService.getLedgerCalendar(
          year: currentYear,
          month: currentMonth,
        ),
        ApiService.getLedgerEntries(
          year: currentYear,
          month: currentMonth,
        ),
      ]);

      final calendarData = results[0] as Map<String, dynamic>?;
      final entries = results[1] as List<Map<String, dynamic>>;

      // ── 달력 days[] → _calendarDays 맵으로 변환 ─────────────────
      final newCalendarDays = <int, Map<String, dynamic>>{};
      if (calendarData != null) {
        final daysList = calendarData['days'];
        if (daysList is List) {
          for (final d in daysList) {
            if (d is Map) {
              final day = d['day'] as int?;
              if (day != null) {
                newCalendarDays[day] = Map<String, dynamic>.from(d);
              }
            }
          }
        }
      }

      // 달력 API가 실패하거나 days[]가 비어있으면
      // 가계부 목록(entries)로부터 날짜별 지출/수입을 직접 집계하여 폴백
      if (newCalendarDays.isEmpty && entries.isNotEmpty) {
        debugPrint('[Ledger] 달력 API 응답 비었음 — 가계부 목록으로 폴백 집계');
        for (final entry in entries) {
          final txAtStr = (entry['transaction_at'] ?? entry['created_at'] ?? '') as String;
          if (txAtStr.isEmpty) continue;
          try {
            final txDate = DateTime.parse(txAtStr).toLocal();
            if (txDate.year != currentYear || txDate.month != currentMonth) continue;
            final day = txDate.day;
            final amount = (entry['amount'] as num?)?.toInt() ?? 0;
            final type   = entry['type']?.toString() ?? '';
            final cur    = newCalendarDays.putIfAbsent(day, () => {
              'day': day,
              'income': 0,
              'expense': 0,
              'transfer': 0,
              'is_over_budget_risk_day': false,
            });
            if (type == 'income') {
              cur['income'] = ((cur['income'] as int?) ?? 0) + amount;
            } else if (type == 'expense') {
              cur['expense'] = ((cur['expense'] as int?) ?? 0) + amount;
            } else if (type == 'transfer') {
              cur['transfer'] = ((cur['transfer'] as int?) ?? 0) + amount;
            }
          } catch (_) {}
        }
      }

      // ── 가계부 목록 → 화면용 데이터 변환 ───────────────────────────
      final converted = entries.map((entry) {
        final DateTime txDateRaw = DateTime.parse(
          entry['transaction_at'] ??
              entry['created_at'] ??
              DateTime.now().toIso8601String(),
        );
        final DateTime txDate = txDateRaw.toLocal();
        final bool isIncome = entry['type'] == 'income';
        final int amount = (entry['amount'] as num).toInt();
        final String formattedAmount = isIncome
            ? '+${_formatAmount(amount)} 원'
            : '-${_formatAmount(amount)} 원';
        final String category = CategoryMapper.toDisplay(
          entry['category']?.toString(),
        );

        return {
          'date': '${txDate.month}.${txDate.day}',
          'fullDate': txDate,
          'title': entry['merchant_name'] ?? category,
          'amount': formattedAmount,
          'isIncome': isIncome,
          'icon': _iconFromCategory(category),
        };
      }).toList()
        ..sort(
          (a, b) =>
              (b['fullDate'] as DateTime).compareTo(a['fullDate'] as DateTime),
        );

      // ── GlobalKey 생성 ───────────────────────────────────────────
      final newDateKeys = <String, GlobalKey>{};
      final newItemKeys = <int, GlobalKey>{};
      for (int i = 0; i < converted.length; i++) {
        final dateStr = converted[i]['date'] as String;
        newItemKeys[i] = GlobalKey();
        if (!newDateKeys.containsKey(dateStr)) {
          newDateKeys[dateStr] = newItemKeys[i]!;
        }
      }

      // ── 예상 초과일 & 메타 정보 ──────────────────────────────────
      final overBudgetStartDay = calendarData?['over_budget_start_day'] as int?;
      final budgetConfigured   = calendarData?['budget_configured'] as bool? ?? false;
      final isCurrentMonth     = calendarData?['is_current_month'] as bool? ?? false;

      // daily_average_expense: 이번 달에만 서버가 채워줌.
      // 지난 달은 0으로 내려오므로 calendarDays의 expense 합계로 직접 계산.
      double dailyAvgExpense =
          (calendarData?['daily_average_expense'] as num?)?.toDouble() ?? 0.0;
      if (dailyAvgExpense <= 0 && newCalendarDays.isNotEmpty) {
        // 지출이 있는 날만 카운트해서 평균 계산
        int totalExpense = 0;
        int daysWithExpense = 0;
        for (final d in newCalendarDays.values) {
          final exp = (d['expense'] as num?)?.toInt() ?? 0;
          if (exp > 0) {
            totalExpense += exp;
            daysWithExpense++;
          }
        }
        if (daysWithExpense > 0) {
          dailyAvgExpense = totalExpense / daysWithExpense;
        }
      }
      // 디버그 로그
      debugPrint('[Ledger] isCurrentMonth=$isCurrentMonth budgetConfigured=$budgetConfigured');
      debugPrint('[Ledger] dailyAvgExpense=$dailyAvgExpense overBudgetStartDay=$overBudgetStartDay');
      debugPrint('[Ledger] calendarDays 수: ${newCalendarDays.length}');
      if (newCalendarDays.isNotEmpty) {
        final sample = newCalendarDays.entries.first;
        debugPrint('[Ledger] 샘플 날짜[${sample.key}]: ${sample.value}');
      }

      setState(() {
        transactions = converted;
        _calendarDays
          ..clear()
          ..addAll(newCalendarDays);
        _dateKeys
          ..clear()
          ..addAll(newDateKeys);
        _itemKeys
          ..clear()
          ..addAll(newItemKeys);
        // isCurrentMonth 조건 없이 서버 값 그대로 사용
        // (지난 달은 서버가 is_over_budget_risk_day=false로 내려보내므로 안전)
        _overBudgetStartDay = budgetConfigured ? overBudgetStartDay : null;
        _dailyAvgExpense    = dailyAvgExpense;
        _budgetConfigured   = budgetConfigured;
        _isCurrentMonth     = isCurrentMonth;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = '데이터를 불러오지 못했습니다.\n$e';
        isLoading = false;
      });
    }
  }

  // ✅ 금액 포맷 (1000단위 콤마)
  String _formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  // ✅ 카테고리 → 아이콘 변환
  IconData _iconFromCategory(String? category) {
    switch (CategoryMapper.toDisplay(category)) {
      case '카페':
      case '음료':
        return Icons.local_cafe;
      case '식비':
      case '음식':
        return Icons.restaurant;
      case '쇼핑':
        return Icons.shopping_bag;
      case '통신':
        return Icons.phone_android;
      case '급여':
      case '이자':
      case '용돈':
      case '수입':
        return Icons.monetization_on;
      case '교통':
        return Icons.directions_bus;
      case '기타':
      default:
        return Icons.account_balance_wallet;
    }
  }

  // 달력 날짜 셀 스타일 판단 헬퍼 메서드

  /// 실제 결제 이력이 있는 날짜인지 (내역 리스트 기준)
  bool _hasTransaction(int day) =>
      _dateKeys.containsKey('$currentMonth.$day');

  /// 해당 날 지출에서 일 평균의 1.5배를 넘으면 과소비일로 판단
  bool _isOverspentDay(int day) {
    if (_dailyAvgExpense <= 0) return false;
    final expense = (_calendarDays[day]?['expense'] as num?)?.toDouble() ?? 0;
    return expense > _dailyAvgExpense * 1.5;
  }

  /// is_over_budget_risk_day: 서버가 표시한 예산 초과 위험 구간
  bool _isRiskDay(int day) =>
      _calendarDays[day]?['is_over_budget_risk_day'] as bool? ?? false;

  // ✅ 월 이동 함수
  void _changeMonth(int delta) {
    setState(() {
      currentMonth += delta;
      if (currentMonth > 12) {
        currentMonth = 1;
        currentYear++;
      } else if (currentMonth < 1) {
        currentMonth = 12;
        currentYear--;
      }
      selectedDay = null;
    });
    _fetchLedgerData();
  }

  void _onDaySelected(int day) {
    final targetDate = '$currentMonth.$day';
    // 이미 선택된 날짜 다시 탭하면 선택 해제 (전체 보기)
    if (selectedDay == day) {
      setState(() => selectedDay = null);
      return;
    }
    setState(() => selectedDay = day);

    // 해당 날짜 데이터 없으면 스크롤 안함
    final hasData = transactions.any((tx) => tx['date'] == targetDate);
    if (!hasData) return;

    // 필터링 후 리스트가 재바뀘을 때까지 기다렸다가 맨 위로 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // ✅ 해당 월의 날짜 수 계산
  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  // ── 달력 범례 칩 ────────────────────────────────────────────────
  Widget _buildLegend({
    required Color color,
    required String label,
    bool isBorder = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: isBorder
                ? Border.all(color: color.withValues(alpha: 0.6), width: 1.2)
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;
    final totalDays = _daysInMonth(currentYear, currentMonth);

    return Scaffold(
      backgroundColor: colors.background,
      drawer: null,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primaryText, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // ✅ 새로고침 버튼
          IconButton(
            icon: Icon(Icons.refresh, color: colors.primaryText, size: 28),
            onPressed: _fetchLedgerData,
          ),
          IconButton(
            icon: Icon(
              Icons.notifications_none,
              color: colors.primaryText,
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
      body: Column(
        children: [
          // ==========================================
          // 1. 상단 달력 영역
          // ==========================================
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ 월 이동 헤더
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _changeMonth(-1),
                      child: Icon(
                        Icons.chevron_left,
                        color: colors.primaryText,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$currentMonth월',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _changeMonth(1),
                      child: Icon(
                        Icons.chevron_right,
                        color: colors.primaryText,
                      ),
                    ),
                  ],
                ),
                if (_overBudgetStartDay != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 15,
                          color: Colors.orange.shade800,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$_overBudgetStartDay일부터 예산 초과 예상 구간입니다',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // 범례 행
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildLegend(
                      color: expenseColor,
                      label: '과소비일',
                      isBorder: true,
                    ),
                    const SizedBox(width: 10),
                    // 예산 초과 위험구간 범례는 현재달 + 예산 설정시만 표시
                    if (_budgetConfigured && _isCurrentMonth)
                      _buildLegend(
                        color: Colors.orange.shade700,
                        label: '초과예상구간',
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // 달력 그리드
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 0.60,
                  ),
                  itemCount: totalDays,
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    final isSelected   = selectedDay == day;
                    final isRisk       = _isRiskDay(day);          // 서버 예산 초과 위험구간
                    final isOverspent  = _isOverspentDay(day);     // 과소비일
                    final hasTx        = _hasTransaction(day);
                    final dayData      = _calendarDays[day];
                    final income       = (dayData?['income']  as num?)?.toInt() ?? 0;
                    final expense      = (dayData?['expense'] as num?)?.toInt() ?? 0;

                    // ── 날짜 원형 스타일 ─────────────────────────────────────
                    // 선택 중 > 과소비 > 위험구간 > 평상 순위
                    BoxDecoration circleDecoration;
                    Color numberColor;
                    FontWeight numberWeight = FontWeight.w500;

                    if (isSelected) {
                      circleDecoration = BoxDecoration(
                        color: colors.primaryText,
                        shape: BoxShape.circle,
                      );
                      numberColor = colors.background;
                      numberWeight = FontWeight.bold;
                    } else if (isOverspent) {
                      // 과소비 날 — 빨간 원 + 빨간 숫자
                      circleDecoration = BoxDecoration(
                        color: expenseColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: expenseColor.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                      );
                      numberColor  = expenseColor;
                      numberWeight = FontWeight.bold;
                    } else if (isRisk) {
                      // 예산 초과 위험구간 날 — 주황색 하이라이트
                      circleDecoration = BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      );
                      numberColor = Colors.orange.shade800;
                    } else {
                      circleDecoration = const BoxDecoration(shape: BoxShape.circle);
                      numberColor = colors.primaryText;
                    }

                    return GestureDetector(
                      onTap: () => _onDaySelected(day),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // 날짜 원형
                          Container(
                            width: 28,
                            height: 28,
                            decoration: circleDecoration,
                            child: Center(
                              child: Text(
                                '$day',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: numberWeight,
                                  color: numberColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 1),
                          // 수입 금액
                          if (income > 0)
                            Text(
                              '+${_formatAmount(income)}',
                              style: TextStyle(
                                fontSize: 8,
                                color: incomeColor,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          // 지출 금액
                          if (expense > 0)
                            Text(
                              '-${_formatAmount(expense)}',
                              style: TextStyle(
                                fontSize: 8,
                                color: isOverspent
                                    ? expenseColor
                                    : colors.subText,
                                fontWeight: isOverspent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          // 거래 점 인디케이터
                          if (hasTx && income == 0 && expense == 0)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.background
                                    : colors.primaryText
                                          .withValues(alpha: 0.35),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          Divider(color: Colors.grey.shade200, thickness: 8),

          // ==========================================
          // 2. 하단 내역 리스트 영역
          // ==========================================
          Expanded(
            child: isLoading
                // ✅ 로딩 상태
                ? Center(
                    child: CircularProgressIndicator(color: colors.primaryText),
                  )
                : errorMessage != null
                // ✅ 에러 상태
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: colors.subText,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          style: TextStyle(color: colors.subText),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchLedgerData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.cardBackground,
                            foregroundColor: colors.primaryText,
                          ),
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  )
                : transactions.isEmpty
                // ✅ 내역 없음 상태
                ? Center(
                    child: Text(
                      '이번 달 내역이 없습니다.',
                      style: TextStyle(color: colors.subText),
                    ),
                  )
                // ✅ 정상 데이터 리스트
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 15.0,
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _displayTransactions.length,
                    itemBuilder: (context, index) {
                      final tx = _displayTransactions[index];
                      // 선택된 날짜 필터 시 모두 highlighted
                      bool isHighlighted = selectedDay != null;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 전체 보기일 때만 날짜 헤더 표시
                            if (selectedDay == null ||
                                index == 0 ||
                                _displayTransactions[index - 1]['date'] !=
                                    tx['date'])
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  tx['date'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colors.primaryText,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: isHighlighted
                                    ? colors.primaryText.withValues(alpha: 0.12)
                                    : colors.cardBackground,
                                borderRadius: BorderRadius.circular(15),
                                border: isHighlighted
                                    ? Border.all(
                                        color: colors.primaryText,
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: colors.background,
                                    child: Icon(
                                      tx['icon'],
                                      color: colors.primaryText,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Text(
                                      tx['title'],
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: colors.primaryText,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    tx['amount'],
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: tx['isIncome']
                                          ? incomeColor
                                          : expenseColor,
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

class LedgerScreenWrapper extends StatelessWidget {
  const LedgerScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;

    return Scaffold(
      body: const LedgerScreen(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: colors.cardBackground),
        child: BottomNavigationBar(
          currentIndex: 1, // 달력 탭 강조
          onTap: (index) {
            Navigator.pop(context); // 뒤로가기
            MainScreen.globalKey.currentState?.changeTab(index);
          },
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
