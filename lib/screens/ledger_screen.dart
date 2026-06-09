import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'notification_screen.dart';
import 'package:first/app_colors.dart';
import 'package:first/services/api_service.dart';
import 'package:first/services/category_mapper.dart';
import 'main_screen.dart';
import 'main_payment_screen.dart';
import 'group_payment_screen.dart';
import 'individual_payment_screen.dart';

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

  final Map<String, GlobalKey> _dateKeys = {};
  final Map<int, GlobalKey> _itemKeys = {};
  final Map<int, Map<String, dynamic>> _calendarDays = {};

  List<Map<String, dynamic>> transactions = [];
  bool isLoading = true;
  String? errorMessage;

  int currentYear = DateTime.now().year;
  int currentMonth = DateTime.now().month;

  int? _overBudgetStartDay;
  double _dailyAvgExpense = 0;
  bool _budgetConfigured = false;
  bool _isCurrentMonth = false;

  // 그룹 데이터
  List<TransactionGroup> _groups = [];
  List<TransactionItem> _allTransactions = [];
  Set<int> _groupedIndexes = {};

  // 날짜 선택 시 해당 날의 일반 거래 필터
  List<Map<String, dynamic>> get _displayTransactions {
    if (selectedDay == null) return transactions;
    final targetDate = '$currentMonth.$selectedDay';
    return transactions.where((tx) => tx['date'] == targetDate).toList();
  }

  // 날짜 선택 시 해당 날의 그룹 필터 (bundle_date 기준)
  List<TransactionGroup> get _displayGroups {
    if (selectedDay == null) return _groups;
    return _groups.where((g) {
      if (g.bundleDate == null) return false;
      final local = g.bundleDate!.toLocal();
      return local.year == currentYear &&
          local.month == currentMonth &&
          local.day == selectedDay;
    }).toList();
  }

  // 날짜 탭 시 그룹이 있는지 체크 (달력 점 인디케이터용)
  bool _hasGroupOnDay(int day) {
    return _groups.any((g) {
      if (g.bundleDate == null) return false;
      final local = g.bundleDate!.toLocal();
      return local.year == currentYear &&
          local.month == currentMonth &&
          local.day == day;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchLedgerData();
  }

  Future<void> _fetchLedgerData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getLedgerCalendar(year: currentYear, month: currentMonth),
        ApiService.getLedgerEntries(year: currentYear, month: currentMonth),
      ]);

      final calendarData = results[0] as Map<String, dynamic>?;
      final entries = results[1] as List<Map<String, dynamic>>;

      // ── 달력 days[] 변환 ─────────────────────────────────────────
      final newCalendarDays = <int, Map<String, dynamic>>{};
      if (calendarData != null) {
        final daysList = calendarData['days'];
        if (daysList is List) {
          for (final d in daysList) {
            if (d is Map) {
              final day = d['day'] as int?;
              if (day != null) newCalendarDays[day] = Map<String, dynamic>.from(d);
            }
          }
        }
      }

      // 폴백: 달력 API 비었으면 entries로 직접 집계
      if (newCalendarDays.isEmpty && entries.isNotEmpty) {
        for (final entry in entries) {
          final txAtStr = (entry['transaction_at'] ?? entry['created_at'] ?? '') as String;
          if (txAtStr.isEmpty) continue;
          try {
            final txDate = DateTime.parse(txAtStr).toLocal();
            if (txDate.year != currentYear || txDate.month != currentMonth) continue;
            final day = txDate.day;
            final amount = (entry['amount'] as num?)?.toInt() ?? 0;
            final type = entry['type']?.toString() ?? '';
            final cur = newCalendarDays.putIfAbsent(day, () => {
              'day': day, 'income': 0, 'expense': 0,
              'transfer': 0, 'is_over_budget_risk_day': false,
            });
            if (type == 'income') cur['income'] = ((cur['income'] as int?) ?? 0) + amount;
            else if (type == 'expense') cur['expense'] = ((cur['expense'] as int?) ?? 0) + amount;
            else if (type == 'transfer') cur['transfer'] = ((cur['transfer'] as int?) ?? 0) + amount;
          } catch (_) {}
        }
      }

      // ── TransactionItem 변환 (그룹화용) ─────────────────────────
      final allTransactions = entries.map((entry) {
        final type = entry['type']?.toString();
        final isIncome = type == 'income';
        final amount = (entry['amount'] as num?)?.toInt() ?? 0;
        final merchant = entry['merchant_name']?.toString().trim();
        final category = CategoryMapper.toDisplay(entry['category']?.toString());
        final transactionAt = DateTime.tryParse(
          entry['transaction_at']?.toString() ?? '',
        )?.toLocal();
        final id = entry['id']?.toString();
        final bundleIdRaw = entry['bundle_id']?.toString();
        final bundleId = (bundleIdRaw == null || bundleIdRaw.isEmpty) ? null : bundleIdRaw;
        return TransactionItem(
          date: transactionAt == null
              ? '$currentMonth.1'
              : '${transactionAt.month}.${transactionAt.day}',
          title: merchant == null || merchant.isEmpty ? '알 수 없음' : merchant,
          amount: '${isIncome ? '+' : '-'}${_formatAmount(amount)} 원',
          isIncome: isIncome,
          category: category,
          icon: _iconFromCategory(category),
          createdAt: transactionAt,
          id: id,
          bundleId: bundleId,
        );
      }).toList();

      // ── 번들 로드 및 그룹화 ──────────────────────────────────────
      final hasBundles = allTransactions.any(
        (t) => t.bundleId != null && t.bundleId!.isNotEmpty,
      );
      final bundles = hasBundles
          ? await ApiService.getLedgerBundles()
          : <Map<String, dynamic>>[];
      final groupingState = MainPaymentScreen.buildGroupingState(
        allTransactions, bundles,
      );

      // ── 화면용 거래 목록 변환 (그룹화된 항목 제외) ─────────────
      final converted = <Map<String, dynamic>>[];
      for (int i = 0; i < allTransactions.length; i++) {
        if (groupingState.groupedIndexes.contains(i)) continue;
        final tx = allTransactions[i];
        final txDate = tx.createdAt;
        converted.add({
          'date': tx.date,
          'fullDate': txDate ?? DateTime(currentYear, currentMonth, 1),
          'title': tx.title,
          'amount': tx.amount,
          'isIncome': tx.isIncome,
          'icon': tx.icon,
        });
      }
      converted.sort(
        (a, b) => (b['fullDate'] as DateTime).compareTo(a['fullDate'] as DateTime),
      );

      // ── GlobalKey 생성 ────────────────────────────────────────────
      final newDateKeys = <String, GlobalKey>{};
      final newItemKeys = <int, GlobalKey>{};
      for (int i = 0; i < converted.length; i++) {
        final dateStr = converted[i]['date'] as String;
        newItemKeys[i] = GlobalKey();
        if (!newDateKeys.containsKey(dateStr)) newDateKeys[dateStr] = newItemKeys[i]!;
      }

      // ── 메타 정보 ─────────────────────────────────────────────────
      final overBudgetStartDay = calendarData?['over_budget_start_day'] as int?;
      final budgetConfigured = calendarData?['budget_configured'] as bool? ?? false;
      final isCurrentMonth = calendarData?['is_current_month'] as bool? ?? false;

      double dailyAvgExpense =
          (calendarData?['daily_average_expense'] as num?)?.toDouble() ?? 0.0;
      if (dailyAvgExpense <= 0 && newCalendarDays.isNotEmpty) {
        int totalExpense = 0;
        int daysWithExpense = 0;
        for (final d in newCalendarDays.values) {
          final exp = (d['expense'] as num?)?.toInt() ?? 0;
          if (exp > 0) { totalExpense += exp; daysWithExpense++; }
        }
        if (daysWithExpense > 0) dailyAvgExpense = totalExpense / daysWithExpense;
      }

      setState(() {
        transactions = converted;
        _allTransactions = allTransactions;
        _groups = groupingState.groups;
        _groupedIndexes = groupingState.groupedIndexes;
        _calendarDays..clear()..addAll(newCalendarDays);
        _dateKeys..clear()..addAll(newDateKeys);
        _itemKeys..clear()..addAll(newItemKeys);
        _overBudgetStartDay = budgetConfigured ? overBudgetStartDay : null;
        _dailyAvgExpense = dailyAvgExpense;
        _budgetConfigured = budgetConfigured;
        _isCurrentMonth = isCurrentMonth;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = '데이터를 불러오지 못했습니다.\n$e';
        isLoading = false;
      });
    }
  }

  String _formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

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
      default:
        return Icons.account_balance_wallet;
    }
  }

  bool _hasTransaction(int day) =>
      _dateKeys.containsKey('$currentMonth.$day') || _hasGroupOnDay(day);

  bool _isOverspentDay(int day) {
    if (_dailyAvgExpense <= 0) return false;
    final expense = (_calendarDays[day]?['expense'] as num?)?.toDouble() ?? 0;
    return expense > _dailyAvgExpense * 1.5;
  }

  bool _isRiskDay(int day) =>
      _calendarDays[day]?['is_over_budget_risk_day'] as bool? ?? false;

  void _changeMonth(int delta) {
    setState(() {
      currentMonth += delta;
      if (currentMonth > 12) { currentMonth = 1; currentYear++; }
      else if (currentMonth < 1) { currentMonth = 12; currentYear--; }
      selectedDay = null;
    });
    _fetchLedgerData();
  }

  void _onDaySelected(int day) {
    if (selectedDay == day) {
      setState(() => selectedDay = null);
      return;
    }
    setState(() => selectedDay = day);
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

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  Widget _buildLegend({required Color color, required String label, bool isBorder = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: isBorder ? Border.all(color: color.withValues(alpha: 0.6), width: 1.2) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // 그룹카드 위젯
  Widget _buildGroupCard(TransactionGroup group, ThemeColors colors) {
    int groupExpense = 0;
    int groupIncome = 0;
    for (final tx in group.items) {
      final raw = tx.amount.replaceAll(RegExp(r'[^0-9]'), '');
      final val = int.tryParse(raw) ?? 0;
      if (tx.isIncome) groupIncome += val; else groupExpense += val;
    }
    final total = groupExpense - groupIncome;
    final absStr = total.abs().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},',
    );

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupPaymentScreen(
            group: group,
            allTransactions: _allTransactions,
            groupedIndexes: Set.from(_groupedIndexes),
            onGroupDeleted: () async { await _fetchLedgerData(); },
            onGroupUpdated: (_, __) async { await _fetchLedgerData(); },
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selectedDay != null
              ? colors.primaryText.withValues(alpha: 0.12)
              : colors.cardBackground,
          borderRadius: BorderRadius.circular(15),
          border: selectedDay != null
              ? Border.all(color: colors.primaryText, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: colors.background, shape: BoxShape.circle),
              child: Icon(Icons.group, color: colors.primaryText, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                group.name,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.primaryText),
              ),
            ),
            Text(
              '-$absStr원',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: colors.subText, size: 18),
          ],
        ),
      ),
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

    // 전체 보기일 때 날짜 헤더 포함 리스트 구성
    // (그룹 + 일반 거래를 날짜별로 합쳐서 보여줌)
    final displayTx = _displayTransactions;
    final displayGroups = _displayGroups;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primaryText, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: colors.primaryText, size: 28),
            onPressed: _fetchLedgerData,
          ),
          IconButton(
            icon: Icon(Icons.notifications_none, color: colors.primaryText, size: 32),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 달력 영역 ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _changeMonth(-1),
                      child: Icon(Icons.chevron_left, color: colors.primaryText),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$currentMonth월',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colors.primaryText),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _changeMonth(1),
                      child: Icon(Icons.chevron_right, color: colors.primaryText),
                    ),
                  ],
                ),
                if (_overBudgetStartDay != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 15, color: Colors.orange.shade800),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$_overBudgetStartDay일부터 예산 초과 예상 구간입니다',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildLegend(color: expenseColor, label: '과소비일', isBorder: true),
                    const SizedBox(width: 10),
                    if (_budgetConfigured && _isCurrentMonth)
                      _buildLegend(color: Colors.orange.shade700, label: '초과예상구간'),
                  ],
                ),
                const SizedBox(height: 20),
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
                    final isSelected  = selectedDay == day;
                    final isRisk      = _isRiskDay(day);
                    final isOverspent = _isOverspentDay(day);
                    final hasTx       = _hasTransaction(day);
                    final hasGroup    = _hasGroupOnDay(day);
                    final dayData     = _calendarDays[day];
                    final income      = (dayData?['income']  as num?)?.toInt() ?? 0;
                    final expense     = (dayData?['expense'] as num?)?.toInt() ?? 0;

                    BoxDecoration circleDecoration;
                    Color numberColor;
                    FontWeight numberWeight = FontWeight.w500;

                    if (isSelected) {
                      circleDecoration = BoxDecoration(color: colors.primaryText, shape: BoxShape.circle);
                      numberColor = colors.background;
                      numberWeight = FontWeight.bold;
                    } else if (isOverspent) {
                      circleDecoration = BoxDecoration(
                        color: expenseColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: expenseColor.withValues(alpha: 0.6), width: 1.2),
                      );
                      numberColor = expenseColor;
                      numberWeight = FontWeight.bold;
                    } else if (isRisk) {
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
                          Container(
                            width: 28, height: 28,
                            decoration: circleDecoration,
                            child: Center(
                              child: Text(
                                '$day',
                                style: TextStyle(fontSize: 13, fontWeight: numberWeight, color: numberColor),
                              ),
                            ),
                          ),
                          const SizedBox(height: 1),
                          if (income > 0)
                            Text(
                              '+${_formatAmount(income)}',
                              style: TextStyle(fontSize: 8, color: incomeColor, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis, maxLines: 1,
                            ),
                          if (expense > 0)
                            Text(
                              '-${_formatAmount(expense)}',
                              style: TextStyle(
                                fontSize: 8,
                                color: isOverspent ? expenseColor : colors.subText,
                                fontWeight: isOverspent ? FontWeight.bold : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis, maxLines: 1,
                            ),
                          // 그룹 있는 날에 그룹 아이콘 점 표시
                          if (hasGroup && income == 0 && expense == 0)
                            Container(
                              width: 4, height: 4,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.background
                                    : colors.primaryText.withValues(alpha: 0.35),
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (hasGroup && (income > 0 || expense > 0))
                            Icon(
                              Icons.group,
                              size: 7,
                              color: isSelected ? colors.background : colors.subText,
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

          // ── 하단 내역 리스트 ─────────────────────────────────────
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: colors.primaryText))
                : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: colors.subText, size: 48),
                        const SizedBox(height: 12),
                        Text(errorMessage!, style: TextStyle(color: colors.subText), textAlign: TextAlign.center),
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
                : (displayTx.isEmpty && displayGroups.isEmpty)
                ? Center(
                    child: Text('이번 달 내역이 없습니다.', style: TextStyle(color: colors.subText)),
                  )
                : _buildList(displayTx, displayGroups, colors),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    List<Map<String, dynamic>> txList,
    List<TransactionGroup> groupList,
    ThemeColors colors,
  ) {
    // 날짜별로 그룹과 일반 거래를 합쳐서 정렬
    final List<Map<String, dynamic>> items = [];

    for (final tx in txList) {
      items.add({'type': 'tx', 'data': tx, 'sortKey': tx['fullDate'] as DateTime, 'date': tx['date']});
    }
    for (final group in groupList) {
      final date = group.bundleDate != null
          ? '${group.bundleDate!.toLocal().month}.${group.bundleDate!.toLocal().day}'
          : '';
      final sortKey = group.bundleDate?.toLocal() ?? DateTime(currentYear, currentMonth, 1);
      items.add({'type': 'group', 'data': group, 'sortKey': sortKey, 'date': date});
    }

    items.sort((a, b) => (b['sortKey'] as DateTime).compareTo(a['sortKey'] as DateTime));

    String? lastDate;
    final widgets = <Widget>[];

    for (final item in items) {
      final date = item['date'] as String;
      if (date != lastDate) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Text(
              date,
              style: TextStyle(fontWeight: FontWeight.bold, color: colors.primaryText, fontSize: 14),
            ),
          ),
        );
        lastDate = date;
      }

      if (item['type'] == 'group') {
        widgets.add(_buildGroupCard(item['data'] as TransactionGroup, colors));
      } else {
        final tx = item['data'] as Map<String, dynamic>;
        final isHighlighted = selectedDay != null;
        widgets.add(
          GestureDetector(
            onTap: () {
              // 개별 거래 탭 시 상세화면 (allTransactions에서 찾기)
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isHighlighted
                    ? colors.primaryText.withValues(alpha: 0.12)
                    : colors.cardBackground,
                borderRadius: BorderRadius.circular(15),
                border: isHighlighted ? Border.all(color: colors.primaryText, width: 1.5) : null,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colors.background,
                    child: Icon(tx['icon'] as IconData, color: colors.primaryText, size: 20),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      tx['title'] as String,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.primaryText),
                    ),
                  ),
                  Text(
                    tx['amount'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: (tx['isIncome'] as bool) ? incomeColor : expenseColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
      physics: const BouncingScrollPhysics(),
      children: widgets,
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
          currentIndex: 1,
          onTap: (index) {
            Navigator.pop(context);
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
