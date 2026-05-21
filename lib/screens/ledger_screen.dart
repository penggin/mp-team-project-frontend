import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'notification_screen.dart';
import 'package:first/app_colors.dart';
import 'package:first/services/api_service.dart'; // ✅ ApiService import

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({Key? key}) : super(key: key);

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final Color incomeColor = Colors.blue;
  final Color expenseColor = Colors.red;

  int? selectedDay;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _dateKeys = {};

  // ✅ 더미 데이터 → 실제 데이터로 교체
  List<Map<String, dynamic>> transactions = [];
  bool isLoading = true;
  String? errorMessage;

  // ✅ 현재 표시 중인 연/월
  int currentYear = DateTime.now().year;
  int currentMonth = DateTime.now().month;

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
        final DateTime txDate = DateTime.parse(
          entry['transaction_at'] ?? entry['created_at'] ?? DateTime.now().toIso8601String(),
        );
        final bool isIncome = entry['type'] == 'income';
        final int amount = (entry['amount'] as num).toInt();
        final String formattedAmount = isIncome
            ? '+${_formatAmount(amount)} 원'
            : '-${_formatAmount(amount)} 원';

        return {
          'date': '${txDate.month}.${txDate.day}',   // ex) '3.31'
          'fullDate': txDate,                          // 정렬용 DateTime
          'title': entry['merchant_name'] ?? entry['category'] ?? '내역 없음',
          'amount': formattedAmount,
          'isIncome': isIncome,
          'icon': _iconFromCategory(entry['category']),
        };
      }).toList();

      // ✅ 날짜 내림차순 정렬
      converted.sort((a, b) =>
          (b['fullDate'] as DateTime).compareTo(a['fullDate'] as DateTime));

      // ✅ 현재 월 데이터만 필터링
      final filtered = converted.where((tx) {
        final date = tx['fullDate'] as DateTime;
        return date.year == currentYear && date.month == currentMonth;
      }).toList();

      // ✅ GlobalKey 생성
      final newKeys = <String, GlobalKey>{};
      for (var tx in filtered) {
        final dateStr = tx['date'] as String;
        if (!newKeys.containsKey(dateStr)) {
          newKeys[dateStr] = GlobalKey();
        }
      }

      setState(() {
        transactions = filtered;
        _dateKeys
          ..clear()
          ..addAll(newKeys);
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
    switch (category) {
      case '카페':
      case '음료':
        return Icons.local_cafe;
      case '식비':
      case '음식':
        return Icons.restaurant;
      case '편의점':
      case '쇼핑':
        return Icons.storefront;
      case '급여':
      case '수입':
        return Icons.monetization_on;
      case '문화':
      case '구독':
        return Icons.movie;
      case '의료':
        return Icons.local_hospital;
      case '교통':
        return Icons.directions_bus;
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
        final amountStr = (tx['amount'] as String)
            .replaceAll(RegExp(r'[^0-9]'), '');
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
    setState(() {
      selectedDay = day;
    });

    final targetKey = _dateKeys[targetDate];
    if (targetKey == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = targetKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.0,
        );
      }
    });
  }

  // ✅ 해당 월의 날짜 수 계산
  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
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
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: colors.primaryText, size: 32),
          onPressed: () {},
        ),
        actions: [
          // ✅ 새로고침 버튼
          IconButton(
            icon: Icon(Icons.refresh, color: colors.primaryText, size: 28),
            onPressed: _fetchLedgerData,
          ),
          IconButton(
            icon: Icon(Icons.notifications_none, color: colors.primaryText, size: 32),
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
          // 1. 상단 달력 영역
          // ==========================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ 월 이동 헤더
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _changeMonth(-1),
                      child: Icon(Icons.chevron_left, color: colors.primaryText),
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
                      child: Icon(Icons.chevron_right, color: colors.primaryText),
                    ),
                  ],
                ),
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
                    bool hasTransaction =
                    _dateKeys.containsKey('$currentMonth.$day');

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
                                : null,
                            child: Center(
                              child: Text(
                                '$day',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? colors.background
                                      : colors.primaryText,
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
                              style: TextStyle(fontSize: 9, color: expenseColor),
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
                                    : colors.primaryText.withOpacity(0.4),
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
              child: CircularProgressIndicator(
                color: colors.primaryText,
              ),
            )
                : errorMessage != null
            // ✅ 에러 상태
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      color: colors.subText, size: 48),
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
                  horizontal: 20.0, vertical: 15.0),
              physics: const BouncingScrollPhysics(),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                final itemKey = _dateKeys[tx['date']];
                bool isHighlighted = selectedDay != null &&
                    tx['date'] == '$currentMonth.$selectedDay';

                return Padding(
                  key: itemKey,
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx['date'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colors.primaryText,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? colors.primaryText.withOpacity(0.12)
                              : colors.cardBackground,
                          borderRadius: BorderRadius.circular(15),
                          border: isHighlighted
                              ? Border.all(
                              color: colors.primaryText,
                              width: 1.5)
                              : null,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: colors.background,
                              child: Icon(tx['icon'],
                                  color: colors.primaryText,
                                  size: 20),
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