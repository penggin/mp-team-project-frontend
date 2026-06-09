import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'notification_screen.dart';
import 'individual_payment_screen.dart';
import 'main_payment_screen.dart';
import 'app_drawer.dart';
import '../app_colors.dart';
import '../services/api_service.dart';
import '../services/category_mapper.dart';
import 'category_detail_screen.dart';

// --- 카테고리별 결제 화면 ---
class CategoryPaymentScreen extends StatefulWidget {
  // main_screen에서 넘겨주는 초기값 (탭 전환 직후 빠르게 표시용)
  final List<TransactionItem> transactions;
  final Set<int> groupedIndexes;
  final List<TransactionGroup> groups;
  final int currentMonth;

  const CategoryPaymentScreen({
    super.key,
    this.transactions = const [],
    this.groupedIndexes = const {},
    this.groups = const [],
    this.currentMonth = 0,
  });

  @override
  State<CategoryPaymentScreen> createState() => _CategoryPaymentScreenState();
}

class _CategoryPaymentScreenState extends State<CategoryPaymentScreen> {
  late int _currentMonth;
  late int _currentYear;
  bool _isLoading = false;

  List<TransactionItem> _transactions = [];
  Set<int> _groupedIndexes = {};
  List<TransactionGroup> _groups = [];

  static const Map<String, Color> _categoryColors = {
    '카페': Color(0xFFBCAAA4),
    '식비': Color(0xFFFDD835),
    '쇼핑': Color(0xFFEF9A9A),
    '교통': Color(0xFF80CBC4),
    '통신': Color(0xFF9FA8DA),
    '기타': Color(0xFFB3FFB3),
  };

  @override
  void initState() {
    super.initState();
    _currentYear = DateTime.now().year;
    _currentMonth =
        widget.currentMonth > 0 ? widget.currentMonth : DateTime.now().month;

    // 초기값으로 먼저 표시한 뒤 API로 갱신
    _transactions = List.from(widget.transactions);
    _groupedIndexes = Set.from(widget.groupedIndexes);
    _groups = List.from(widget.groups);

    _loadData();
  }

  // ── 월 변경 ──
  void _changeMonth(int delta) {
    setState(() {
      _currentMonth += delta;
      if (_currentMonth > 12) {
        _currentMonth = 1;
        _currentYear++;
      } else if (_currentMonth < 1) {
        _currentMonth = 12;
        _currentYear--;
      }
    });
    _loadData();
  }

  // ── API에서 데이터 로드 (main_payment_screen과 동일한 로직) ──
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 1) year/month 필터 시도
    List<Map<String, dynamic>> entries = await ApiService.getLedgerEntries(
      year: _currentYear,
      month: _currentMonth,
    );

    // 2) 비어있으면 전체 받아서 클라이언트 필터
    if (entries.isEmpty) {
      final all = await ApiService.getLedgerEntries();
      entries = all.where((e) {
        final dt = DateTime.tryParse(
          (e['transaction_at'] ?? e['created_at'] ?? '') as String,
        );
        if (dt == null) return false;
        final local = dt.toLocal();
        return local.year == _currentYear && local.month == _currentMonth;
      }).toList();
    }

    // 최신순 정렬
    entries.sort((a, b) {
      final aDate = DateTime.tryParse(
        (a['transaction_at'] ?? a['created_at'] ?? '') as String,
      );
      final bDate = DateTime.tryParse(
        (b['transaction_at'] ?? b['created_at'] ?? '') as String,
      );
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    if (!mounted) return;

    final newTransactions = entries.map(_transactionFromEntry).toList();

    final bundles =
        newTransactions.any(
          (t) => t.bundleId != null && t.bundleId!.isNotEmpty,
        )
        ? await ApiService.getLedgerBundles()
        : <Map<String, dynamic>>[];

    final groupingState = MainPaymentScreen.buildGroupingState(
      newTransactions,
      bundles,
    );

    if (!mounted) return;
    setState(() {
      _transactions = newTransactions;
      _groupedIndexes = groupingState.groupedIndexes;
      _groups = groupingState.groups;
      _isLoading = false;
    });
  }

  TransactionItem _transactionFromEntry(Map<String, dynamic> entry) {
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
    final bundleId =
        (bundleIdRaw == null || bundleIdRaw.isEmpty) ? null : bundleIdRaw;

    return TransactionItem(
      date: transactionAt == null
          ? '$_currentMonth.1'
          : '${transactionAt.month}.${transactionAt.day}',
      title: merchant == null || merchant.isEmpty ? '알 수 없음' : merchant,
      amount:
          '${isIncome ? '+' : '-'}${_formatAmount(amount)} 원',
      isIncome: isIncome,
      category: category,
      icon: _iconForCategory(category, isIncome: isIncome),
      createdAt: transactionAt,
      id: id,
      bundleId: bundleId,
    );
  }

  String _formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  IconData _iconForCategory(String? category, {required bool isIncome}) {
    if (isIncome) return Icons.account_balance_wallet;
    switch (category) {
      case '식비':
        return Icons.restaurant;
      case '카페':
        return Icons.local_cafe;
      case '교통':
        return Icons.directions_bus;
      case '쇼핑':
        return Icons.shopping_bag;
      case '통신':
        return Icons.phone_android;
      default:
        return Icons.account_balance_wallet;
    }
  }

  // ── 카테고리 요약 계산 ──
  List<CategorySummary> get _categories {
    final Map<String, int> totals = {};

    // 1) 그룹화되지 않은 일반 지출
    for (int i = 0; i < _transactions.length; i++) {
      if (_groupedIndexes.contains(i)) continue;
      final tx = _transactions[i];
      if (tx.isIncome) continue;
      final raw = tx.amount.replaceAll(RegExp(r'[^0-9]'), '');
      final val = int.tryParse(raw) ?? 0;
      totals[tx.category] = (totals[tx.category] ?? 0) + val;
    }

    // 2) 각 그룹의 내 지출(총지출 - 수입)을 기타로 합산
    for (final group in _groups) {
      int groupExpense = 0;
      int groupIncome = 0;
      for (final tx in group.items) {
        final raw = tx.amount.replaceAll(RegExp(r'[^0-9]'), '');
        final val = int.tryParse(raw) ?? 0;
        if (tx.isIncome) {
          groupIncome += val;
        } else {
          groupExpense += val;
        }
      }
      final myExpense = groupExpense - groupIncome;
      if (myExpense > 0) {
        totals['기타'] = (totals['기타'] ?? 0) + myExpense;
      }
    }

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map(
          (e) => CategorySummary(
            title: e.key,
            amountInt: e.value,
            color: _categoryColors[e.key] ?? const Color(0xFFBDBDBD),
          ),
        )
        .toList();
  }

  String _totalAmountStr(List<CategorySummary> cats) {
    final total = cats.fold(0, (s, c) => s + c.amountInt);
    final formatted = total.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$formatted원';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;
    final cats = _categories;
    final total = cats.fold(0, (s, c) => s + c.amountInt);

    return Scaffold(
      backgroundColor: colors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu, color: colors.primaryText, size: 32),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_none,
              color: colors.primaryText,
              size: 32,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationScreen(),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: colors.primaryText,
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // 상단 총액 및 막대그래프 카드
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 월 선택
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _changeMonth(-1),
                          child: Icon(
                            Icons.chevron_left,
                            color: colors.primaryText,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$_currentMonth월',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colors.primaryText,
                          ),
                        ),
                        const SizedBox(width: 5),
                        GestureDetector(
                          onTap: () => _changeMonth(1),
                          child: Icon(
                            Icons.chevron_right,
                            color: colors.primaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // 지출 총액
                    _isLoading
                        ? SizedBox(
                            height: 32,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: colors.primaryText,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : Text(
                            _totalAmountStr(cats),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: colors.primaryText,
                            ),
                          ),
                    const SizedBox(height: 25),

                    // 막대 그래프
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 20,
                        child: cats.isEmpty
                            ? Container(color: const Color(0xFFBDBDBD))
                            : Row(
                                children: cats
                                    .map(
                                      (cat) => Expanded(
                                        flex: cat.flexOf(total),
                                        child: Container(color: cat.color),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 범례
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: cats
                          .map(
                            (cat) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: cat.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  cat.title,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.subText,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // 카테고리별 리스트
              if (_isLoading)
                const SizedBox.shrink()
              else if (cats.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(
                    '지출 내역이 없습니다.',
                    style: TextStyle(color: colors.subText, fontSize: 15),
                  ),
                )
              else
                ...cats.map(
                  (cat) => _buildCategoryItem(cat, colors),
                ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(CategorySummary cat, ThemeColors colors) {
    return GestureDetector(
      onTap: () {
        if (cat.title == '기타') {
          // 기타 = 그룹 내 지출 목록 표시
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoryDetailScreen(
                category: '기타 (그룹)',
                transactions: const [],
                groups: _groups,
              ),
            ),
          );
          return;
        }

        final filtered = _transactions.where((tx) {
          return !_groupedIndexes.contains(_transactions.indexOf(tx)) &&
              tx.category == cat.title &&
              !tx.isIncome;
        }).toList();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryDetailScreen(
              category: cat.title,
              transactions: filtered,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 12, backgroundColor: cat.color),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                cat.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryText,
                ),
              ),
            ),
            Text(
              cat.amount,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
