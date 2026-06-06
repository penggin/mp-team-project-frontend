import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'notification_screen.dart';
import 'package:first/app_colors.dart';
import 'package:first/services/api_service.dart';
import 'package:first/services/category_mapper.dart';
import 'package:first/services/experience_service.dart';
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

  // ✅ 소비 페이스 기반 예상 예산 초과일 (이번 달이고 데이터 충분할 때만 세팅)
  int? _projectedExceedDay;

  @override
  void initState() {
    super.initState();
    _fetchLedgerData();
  }

  // ✅ 백엔드에서 가계부 데이터 가져오기
  Future<void> _fetchLedgerData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final entries = await ApiService.getLedgerEntries();

      // ✅ API 응답 → 화면용 데이터로 변환
      final converted = entries.map((entry) {
        // toLocal()로 타임존 변환
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
      }).toList();

      // ✅ 현재 월 데이터만 필터링 (toLocal 변환 후 비교)
      final filtered = converted.where((tx) {
        final date = tx['fullDate'] as DateTime;
        return date.year == currentYear && date.month == currentMonth;
      }).toList();

      // ✅ 날짜 내림차순 정렬
      filtered.sort(
        (a, b) =>
            (b['fullDate'] as DateTime).compareTo(a['fullDate'] as DateTime),
      );

      // ✅ 날짜별 첫 번째 아이템 GlobalKey & 아이템별 GlobalKey 생성
      final newDateKeys = <String, GlobalKey>{};
      final newItemKeys = <int, GlobalKey>{};
      for (int i = 0; i < filtered.length; i++) {
        final dateStr = filtered[i]['date'] as String;
        newItemKeys[i] = GlobalKey();
        if (!newDateKeys.containsKey(dateStr)) {
          newDateKeys[dateStr] = newItemKeys[i]!;
        }
      }

      setState(() {
        transactions = filtered;
        _dateKeys
          ..clear()
          ..addAll(newDateKeys);
        _itemKeys
          ..clear()
          ..addAll(newItemKeys);
        isLoading = false;
      });

      // ✅ 소비 페이스 기반 예상 초과일 계산
      await _computeProjectedExceedDay();
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

  // ✅ 달력에서 해당 날짜의 수입/지출 합계 계산
  Map<String, int> _getDaySummary(int day) {
    final dateStr = '$currentMonth.$day';
    int income = 0;
    int expense = 0;

    for (var tx in transactions) {
      if (tx['date'] == dateStr) {
        final amountStr = (tx['amount'] as String).replaceAll(
          RegExp(r'[^0-9]'),
          '',
        );
        final amount = int.tryParse(amountStr) ?? 0;
        if (tx['isIncome'] == true) {
          income += amount;
        } else {
          expense += amount;
        }
      }
    }
    return {'income': income, 'expense': expense};
  }

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

  /// 소비 페이스 기반 예상 예산 초과일 계산.
  /// 조건: 현재 달 + 월 예산 > 0 + 누적 지출 >= 월 예산의 1/10
  /// 결과: 그 날부터 월 마지막 날까지 달력에서 빨갛게 표시. 안전하면 null.
  Future<void> _computeProjectedExceedDay() async {
    final now = DateTime.now();

    // 과거/미래 달은 페이스 표시 안 함
    if (currentYear != now.year || currentMonth != now.month) {
      if (mounted) setState(() => _projectedExceedDay = null);
      return;
    }

    final monthlyBudget = await ExperienceService.getMonthlyBudget();
    if (monthlyBudget <= 0) {
      if (mounted) setState(() => _projectedExceedDay = null);
      return;
    }

    // 오늘까지 누적 지출 계산 (미래 거래는 제외)
    int cumSpend = 0;
    for (final tx in transactions) {
      if (tx['isIncome'] == true) continue;
      final txDate = tx['fullDate'] as DateTime;
      if (txDate.day > now.day) continue;
      final amountStr = (tx['amount'] as String).replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      cumSpend += int.tryParse(amountStr) ?? 0;
    }

    // 데이터 부족 (월 예산의 1/10 미만 사용)
    if (cumSpend * 10 < monthlyBudget) {
      if (mounted) setState(() => _projectedExceedDay = null);
      return;
    }

    final totalDays = _daysInMonth(currentYear, currentMonth);
    final today = now.day;

    // 이미 초과한 경우: 오늘부터 빨강
    if (cumSpend >= monthlyBudget) {
      if (mounted) setState(() => _projectedExceedDay = today);
      return;
    }

    // 일평균 지출 기반 예상 초과일
    final dailyAverage = cumSpend / today;
    if (dailyAverage <= 0) {
      if (mounted) setState(() => _projectedExceedDay = null);
      return;
    }

    final remaining = monthlyBudget - cumSpend;
    final daysUntilExceed = (remaining / dailyAverage).floor();
    final projectedDay = today + daysUntilExceed + 1; // 초과가 발생하는 첫 날

    // 이번 달 안에 초과 안 함 → 안전
    if (projectedDay > totalDays) {
      if (mounted) setState(() => _projectedExceedDay = null);
      return;
    }

    if (mounted) setState(() => _projectedExceedDay = projectedDay);
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
                if (_projectedExceedDay != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: expenseColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '현재 소비 페이스로는 $_projectedExceedDay일경 예산을 초과할 것 같아요',
                          style: TextStyle(
                            fontSize: 12,
                            color: expenseColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),

                // ✅ 달력 그리드 (실제 날짜 수 기반)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: totalDays,
                  itemBuilder: (context, index) {
                    int day = index + 1;
                    bool isSelected = selectedDay == day;
                    bool hasTransaction = _dateKeys.containsKey(
                      '$currentMonth.$day',
                    );

                    // ✅ 소비 페이스 기반 예상 초과일 이후 빨간색 표시
                    final exceedDay = _projectedExceedDay;
                    final isOverPace =
                        exceedDay != null && day >= exceedDay;

                    // ✅ 실제 수입/지출 금액 표시
                    final summary = _getDaySummary(day);
                    final hasIncome = summary['income']! > 0;
                    final hasExpense = summary['expense']! > 0;

                    return GestureDetector(
                      onTap: () => _onDaySelected(day),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: isSelected
                                ? BoxDecoration(
                                    color: colors.primaryText,
                                    shape: BoxShape.circle,
                                  )
                                : (isOverPace
                                      ? BoxDecoration(
                                          color: expenseColor.withValues(
                                            alpha: 0.18,
                                          ),
                                          shape: BoxShape.circle,
                                        )
                                      : null),
                            child: Center(
                              child: Text(
                                '$day',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isOverPace
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? colors.background
                                      : (isOverPace
                                            ? expenseColor
                                            : colors.primaryText),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          // ✅ 실제 수입 금액 표시
                          if (hasIncome)
                            Text(
                              '+${_formatAmount(summary['income']!)}',
                              style: TextStyle(fontSize: 9, color: incomeColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          // ✅ 실제 지출 금액 표시
                          if (hasExpense)
                            Text(
                              '-${_formatAmount(summary['expense']!)}',
                              style: TextStyle(
                                fontSize: 9,
                                color: expenseColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (hasTransaction)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.background
                                    : colors.primaryText.withValues(alpha: 0.4),
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
