import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'notification_screen.dart';
import 'ledger_screen.dart';
import 'individual_payment_screen.dart';
import 'group_payment_screen.dart';
import 'main_screen.dart';
import 'app_drawer.dart';
import '../app_colors.dart';
import '../services/api_service.dart';
import '../services/category_mapper.dart';
import 'add_payment_screen.dart';

class CategorySummary {
  final String title;
  final int amountInt; // 실제 계산용 정수
  final Color color;

  const CategorySummary({
    required this.title,
    required this.amountInt,
    required this.color,
  });

  /// 화면에 표시할 금액 문자열
  String get amount {
    final formatted = amountInt.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
    );
    return '$formatted 원';
  }

  /// 막대 그래프 flex 값 (총합 대비 비율, 최소 1)
  int flexOf(int total) {
    if (total == 0) return 1;
    final v = (amountInt / total * 100).round();
    return v < 1 ? 1 : v;
  }
}

// ✅ 그룹 데이터 모델
class TransactionGroup {
  final String name;
  final List<TransactionItem> items;
  final String? bundleId; // 백엔드 bundle_id (서버 동기화용)

  TransactionGroup({
    required this.name,
    required this.items,
    this.bundleId,
  });
}

class MainPaymentScreen extends StatefulWidget {
  const MainPaymentScreen({super.key});

  @override
  State<MainPaymentScreen> createState() => _MainPaymentScreenState();

  // ✅ 외부에서 거래 데이터를 읽을 수 있도록 GlobalKey를 통해 접근
  static List<TransactionItem> transactionsOf(
      GlobalKey<State<MainPaymentScreen>> key,
      ) {
    final s = key.currentState;
    if (s is _MainPaymentScreenState) return s._transactions;
    return [];
  }

  static Set<int> groupedIndexesOf(GlobalKey<State<MainPaymentScreen>> key) {
    final s = key.currentState;
    if (s is _MainPaymentScreenState) return s._groupedIndexes;
    return {};
  }

  /// 외부(main_screen 탭 전환 등)에서 거래 내역 새로고침 트리거
  static void reload(GlobalKey<State<MainPaymentScreen>> key) {
    final s = key.currentState;
    if (s is _MainPaymentScreenState) s._loadTransactions();
  }
}

class _MainPaymentScreenState extends State<MainPaymentScreen>
    with SingleTickerProviderStateMixin {
  bool _isFabExpanded = false;
  late AnimationController _fabAnimController;
  late Animation<double> _fabScaleAnim;
  late Animation<Offset> _btn1SlideAnim;
  late Animation<Offset> _btn2SlideAnim;
  late Animation<double> _overlayAnim;

  int currentMonth = DateTime.now().month;
  int currentYear = DateTime.now().year;
  bool _isLoadingTransactions = false;

  // ✅ 그룹 선택 모드
  bool _isGroupSelectMode = false;
  final Set<int> _selectedIndexes = {};

  // ✅ 그룹 목록
  final List<TransactionGroup> _groups = [];

  // ✅ 그룹에 포함된 항목 인덱스 (메인 리스트에서 숨김)
  final Set<int> _groupedIndexes = {};

  // ✅ 카테고리별 색상 매핑
  static const Map<String, Color> _categoryColors = {
    '카페': Color(0xFFBCAAA4),
    '식비': Color(0xFFFDD835),
    '쇼핑': Color(0xFFEF9A9A),
    '교통': Color(0xFF80CBC4),
    '통신': Color(0xFF9FA8DA),
    '기타': Color(0xFFB3FFB3),
  };

  final List<TransactionItem> _transactions = [];

  // ✅ 활성 거래(그룹화 제외)에서 카테고리 요약을 동적으로 계산
  List<CategorySummary> get _categories {
    final Map<String, int> totals = {};
    for (int i = 0; i < _transactions.length; i++) {
      if (_groupedIndexes.contains(i)) continue;
      final tx = _transactions[i];
      if (tx.isIncome) continue; // 지출만 집계
      final raw = tx.amount.replaceAll(RegExp(r'[^0-9]'), '');
      final val = int.tryParse(raw) ?? 0;
      totals[tx.category] = (totals[tx.category] ?? 0) + val;
    }
    // 금액 큰 순으로 정렬
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

  // ✅ 활성 거래(그룹화 제외) 지출 총합
  String get _totalAmount {
    int total = 0;
    for (int i = 0; i < _transactions.length; i++) {
      if (_groupedIndexes.contains(i)) continue;
      final tx = _transactions[i];
      if (tx.isIncome) continue;
      final raw = tx.amount.replaceAll(RegExp(r'[^0-9]'), '');
      total += int.tryParse(raw) ?? 0;
    }
    final formatted = total.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
    );
    return '$formatted원';
  }

  @override
  void initState() {
    super.initState();

    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fabScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimController, curve: Curves.easeOutBack),
    );
    _btn1SlideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
      CurvedAnimation(
        parent: _fabAnimController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );
    _btn2SlideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
      CurvedAnimation(
        parent: _fabAnimController,
        curve: const Interval(0.1, 1.0, curve: Curves.easeOut),
      ),
    );
    _overlayAnim = Tween<double>(begin: 0.0, end: 0.3).animate(
      CurvedAnimation(parent: _fabAnimController, curve: Curves.easeOut),
    );
    _loadTransactions();
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _fabAnimController.forward();
      } else {
        _fabAnimController.reverse();
      }
    });
  }

  void _closeFab() {
    if (_isFabExpanded) {
      setState(() {
        _isFabExpanded = false;
        _fabAnimController.reverse();
      });
    }
  }

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
    });
    _closeFab();
    _loadTransactions();
  }

  Future<void> _loadTransactions({bool preserveGroups = false}) async {
    setState(() => _isLoadingTransactions = true);

    // 1) year/month 필터 시도
    List<Map<String, dynamic>> entries = await ApiService.getLedgerEntries(
      year: currentYear,
      month: currentMonth,
    );
    print('[결제이력] year=$currentYear month=$currentMonth 필터 결과: ${entries.length}개');

    // 2) 비어있으면 백엔드가 필터를 무시했거나 미지원 — 전체 받아서 클라이언트 필터
    if (entries.isEmpty) {
      final all = await ApiService.getLedgerEntries();
      print('[결제이력] 필터 fallback — 전체: ${all.length}개');
      entries = all.where((e) {
        final dt = DateTime.tryParse(
          (e['transaction_at'] ?? e['created_at'] ?? '') as String,
        );
        if (dt == null) return false;
        final local = dt.toLocal();
        return local.year == currentYear && local.month == currentMonth;
      }).toList();
      print('[결제이력] 클라이언트 필터링 후: ${entries.length}개');
    }

    // 최신순 정렬 (타임존 포맷 혼재 대응)
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

    final newTransactions = entries.map(_transactionFromLedgerEntry).toList();

    // bundle_id 별로 모은 후, GET /api/v1/ledger/bundles 로 이름 매핑
    final Map<String, List<int>> byBundle = {};
    for (int i = 0; i < newTransactions.length; i++) {
      final bid = newTransactions[i].bundleId;
      if (bid != null && bid.isNotEmpty) {
        byBundle.putIfAbsent(bid, () => []).add(i);
      }
    }

    final Map<String, String> bundleNames = {};
    if (byBundle.isNotEmpty) {
      final bundles = await ApiService.getLedgerBundles();
      for (final b in bundles) {
        final id = b['id']?.toString();
        final name = b['name']?.toString();
        if (id != null && name != null) bundleNames[id] = name;
      }
    }

    final newGroups = <TransactionGroup>[];
    final newGroupedIndexes = <int>{};
    int autoCounter = 1;
    for (final entry in byBundle.entries) {
      final bundleId = entry.key;
      final indexes = entry.value;
      final items = indexes.map((i) => newTransactions[i]).toList();
      final name = bundleNames[bundleId] ?? '그룹${autoCounter++}';
      newGroups.add(
        TransactionGroup(name: name, items: items, bundleId: bundleId),
      );
      newGroupedIndexes.addAll(indexes);
    }

    setState(() {
      _transactions
        ..clear()
        ..addAll(newTransactions);
      _groups
        ..clear()
        ..addAll(newGroups);
      _groupedIndexes
        ..clear()
        ..addAll(newGroupedIndexes);
      _selectedIndexes.clear();
      _isGroupSelectMode = false;
      _isLoadingTransactions = false;
    });
  }

  Future<void> _refreshTransactions() async {
    _closeFab();
    await _loadTransactions(preserveGroups: true);
  }

  TransactionItem _transactionFromLedgerEntry(Map<String, dynamic> entry) {
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
    final bundleId = (bundleIdRaw == null || bundleIdRaw.isEmpty)
        ? null
        : bundleIdRaw;

    return TransactionItem(
      date: transactionAt == null
          ? '$currentMonth.1'
          : '${transactionAt.month}.${transactionAt.day}',
      title: merchant == null || merchant.isEmpty ? '알 수 없음' : merchant,
      amount: '${isIncome ? '+' : '-'}${_formatAmount(amount)} 원',
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
      case 'food':
        return Icons.restaurant;
      case '카페':
      case 'cafe':
        return Icons.local_cafe;
      case '교통':
      case 'transport':
        return Icons.directions_bus;
      case '쇼핑':
      case 'shopping':
        return Icons.shopping_bag;
      case '통신':
      case 'telecommunications':
        return Icons.phone_android;
      default:
        return Icons.account_balance_wallet;
    }
  }

  // ✅ 그룹 선택 모드 진입
  void _enterGroupSelectMode() {
    _closeFab();
    setState(() {
      _isGroupSelectMode = true;
      _selectedIndexes.clear();
    });
  }

  // ✅ 그룹 선택 모드 취소
  void _cancelGroupSelectMode() {
    setState(() {
      _isGroupSelectMode = false;
      _selectedIndexes.clear();
    });
  }

  // ✅ 확인 버튼 → 백엔드에 그룹 생성 후 GroupPaymentScreen으로 이동
  Future<void> _confirmGroupSelection(ThemeColors colors) async {
    if (_selectedIndexes.isEmpty) return;

    final selectedIdx = _selectedIndexes.toList();
    final selectedItems = selectedIdx.map((i) => _transactions[i]).toList();
    final entryIds = selectedItems
        .where((it) => it.id != null && it.id!.isNotEmpty)
        .map((it) => it.id!)
        .toList();

    if (entryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('선택한 항목에 백엔드 ID가 없어 그룹화할 수 없습니다'),
        ),
      );
      return;
    }

    // bundle_date: 선택한 항목의 가장 빠른 거래일을 그룹 대표 날짜로 사용
    final dates = selectedItems
        .map((it) => it.createdAt)
        .whereType<DateTime>()
        .toList();
    final bundleDate = dates.isEmpty
        ? DateTime.now()
        : dates.reduce((a, b) => a.isBefore(b) ? a : b);

    final groupName = '그룹${_groups.length + 1}';

    final bundle = await ApiService.createLedgerBundle(
      name: groupName,
      bundleDate: bundleDate,
      entryIds: entryIds,
    );

    if (!mounted) return;
    if (bundle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('그룹 생성 실패 — 서버 응답 오류')),
      );
      return;
    }

    final bundleId = bundle['id']?.toString();

    // 그룹 선택 모드 해제
    setState(() {
      _isGroupSelectMode = false;
      _selectedIndexes.clear();
    });

    // 최신 상태 다시 로드 → 그룹 자동 재구성
    await _loadTransactions();
    if (!mounted) return;

    // 방금 만든 그룹 찾아 화면 이동
    final justCreated = bundleId == null
        ? null
        : _groups
        .where((g) => g.bundleId == bundleId)
        .cast<TransactionGroup?>()
        .firstWhere((g) => true, orElse: () => null);

    if (justCreated == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupPaymentScreen(
          group: justCreated,
          allTransactions: _transactions,
          groupedIndexes: Set.from(_groupedIndexes),
          onGroupDeleted: () async {
            await _loadTransactions();
          },
          onGroupUpdated: (updatedItems, newGroupedIndexes) async {
            await _loadTransactions();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;

    return GestureDetector(
      onTap: _isGroupSelectMode ? null : _closeFab,
      child: Scaffold(
        backgroundColor: colors.background,
        drawer: _isGroupSelectMode ? null : const AppDrawer(),
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          leading: _isGroupSelectMode
              ? TextButton(
                  onPressed: _cancelGroupSelectMode,
                  child: Text(
                    '취소',
                    style: TextStyle(color: colors.primaryText, fontSize: 15),
                  ),
                )
              : Builder(
                  builder: (ctx) => IconButton(
                    icon: Icon(Icons.menu, color: colors.primaryText, size: 32),
                    onPressed: () {
                      _closeFab();
                      Scaffold.of(ctx).openDrawer();
                    },
                  ),
                ),
          title: _isGroupSelectMode
              ? Text(
            '항목 선택',
            style: TextStyle(
              color: colors.primaryText,
              fontWeight: FontWeight.bold,
            ),
          )
              : null,
          actions: [
            if (!_isGroupSelectMode)
              IconButton(
                icon: Icon(
                  Icons.notifications_none,
                  color: colors.primaryText,
                  size: 32,
                ),
                onPressed: () {
                  _closeFab();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationScreen(),
                    ),
                  );
                },
              ),
          ],
        ),
        body: Stack(
          children: [
            RefreshIndicator(
              color: colors.primaryText,
              onRefresh: _refreshTransactions,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // ✅ 그룹 선택 모드일 때 카테고리 카드 숨김
                    if (!_isGroupSelectMode) ...[
                      GestureDetector(
                        onTap: () {
                          _closeFab();
                          MainScreen.globalKey.currentState?.changeTab(4);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            color: colors.cardBackground,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                    '$currentMonth월',
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
                              const SizedBox(height: 12),
                              Text(
                                _totalAmount,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primaryText,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Builder(
                                builder: (_) {
                                  final cats = _categories;
                                  final total = cats.fold(
                                    0,
                                        (s, c) => s + c.amountInt,
                                  );
                                  return Column(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SizedBox(
                                          height: 20,
                                          child: cats.isEmpty
                                              ? Container(
                                            color: const Color(
                                              0xFFBDBDBD,
                                            ),
                                          )
                                              : Row(
                                            children: cats
                                                .map(
                                                  (cat) => Expanded(
                                                flex: cat.flexOf(
                                                  total,
                                                ),
                                                child: Container(
                                                  color: cat.color,
                                                ),
                                              ),
                                            )
                                                .toList(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
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
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 달력보기 버튼
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {
                            _closeFab();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LedgerScreenWrapper(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colors.cardBackground,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_month_outlined,
                                  color: colors.primaryText,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '달력보기',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colors.primaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ══════════════════════════════
                    // 전체 결제 이력 리스트
                    // ══════════════════════════════
                    if (_isLoadingTransactions)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: colors.primaryText,
                          ),
                        ),
                      )
                    else if (_transactions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            '이번 달 내역이 없습니다',
                            style: TextStyle(
                              color: colors.subText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._buildTransactionList(colors),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),

            // ✅ 반투명 오버레이 (FAB 열렸을 때)
            AnimatedBuilder(
              animation: _overlayAnim,
              builder: (context, child) {
                return _overlayAnim.value > 0
                    ? GestureDetector(
                  onTap: _closeFab,
                  child: Container(
                    color: Colors.black.withValues(
                      alpha: _overlayAnim.value,
                    ),
                  ),
                )
                    : const SizedBox.shrink();
              },
            ),

            // ✅ 그룹 선택 모드일 때 하단 확인 버튼
            if (_isGroupSelectMode)
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: AnimatedOpacity(
                  opacity: _selectedIndexes.isNotEmpty ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: GestureDetector(
                    onTap: () => _confirmGroupSelection(colors),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: colors.primaryText,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Text(
                          _selectedIndexes.isEmpty
                              ? '항목을 선택하세요'
                              : '확인 (${_selectedIndexes.length}개 선택)',
                          style: TextStyle(
                            color: colors.background,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ✅ FAB (그룹 선택 모드 아닐 때만)
            if (!_isGroupSelectMode)
              Positioned(
                bottom: 24,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SlideTransition(
                      position: _btn2SlideAnim,
                      child: ScaleTransition(
                        scale: _fabScaleAnim,
                        child: GestureDetector(
                          onTap: _enterGroupSelectMode, // ✅ 그룹 생성 진입
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: colors.background,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primaryText.withValues(
                                    alpha: 0.15,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              '그룹 생성',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colors.primaryText,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SlideTransition(
                      position: _btn1SlideAnim,
                      child: ScaleTransition(
                        scale: _fabScaleAnim,
                        child: GestureDetector(
                          onTap: () {
                            _closeFab();

                            Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddPaymentScreen(
                                  onAdd: (item) {
                                    setState(() {
                                      _transactions.insert(0, item);
                                    });
                                  },
                                ),
                              ),
                            ).then((saved) {
                              if (saved == true) _loadTransactions();
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: colors.background,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primaryText.withValues(
                                    alpha: 0.15,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              '입출금 추가',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colors.primaryText,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _toggleFab,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _isFabExpanded
                              ? colors.primaryText
                              : colors.background,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.cardBackground,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primaryText.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: AnimatedRotation(
                          turns: _isFabExpanded ? 0.125 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: Icon(
                            Icons.add,
                            color: _isFabExpanded
                                ? colors.background
                                : colors.accent,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTransactionList(ThemeColors colors) {
    // 그룹을 날짜 순으로 인라인 표시하기 위해 표시할 항목을 리스트로 구성
    // 각 항목은 {‘type’: ‘tx’, ‘index’: i, ‘date’: ...} 또는 {‘type’: ‘group’, ‘group’: ..., ‘date’: ...}
    final List<Map<String, dynamic>> displayItems = [];

    // 1) 그룹이 아닌 일반 거래 코드 목록
    for (int i = 0; i < _transactions.length; i++) {
      if (_groupedIndexes.contains(i)) continue;
      final tx = _transactions[i];
      displayItems.add({
        'type': 'tx',
        'index': i,
        'tx': tx,
        'sortKey': tx.createdAt ?? DateTime(0),
        'date': tx.date,
      });
    }

    // 2) 그룹: 그룹 내 가장 맨 위(=가장 여리다는 이용 날짜와 가까운) 항목의 createdAt을 sortKey로
    for (final group in _groups) {
      DateTime sortKey = DateTime(0);
      String date = '';
      for (final item in group.items) {
        if (item.createdAt != null) {
          if (item.createdAt!.isAfter(sortKey)) {
            sortKey = item.createdAt!;
            date = item.date;
          }
        }
      }
      if (date.isEmpty && group.items.isNotEmpty) {
        date = group.items.first.date;
      }
      displayItems.add({
        'type': 'group',
        'group': group,
        'sortKey': sortKey,
        'date': date,
      });
    }

    // 3) sortKey 내림차순 정렬 (최신 거래가 위로)
    displayItems.sort((a, b) {
      final aKey = a['sortKey'] as DateTime;
      final bKey = b['sortKey'] as DateTime;
      return bKey.compareTo(aKey);
    });

    final List<Widget> widgets = [];
    String? lastDate;

    for (final item in displayItems) {
      final String date = item['date'] as String;

      if (date != lastDate) {
        if (lastDate != null) widgets.add(const SizedBox(height: 4));
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
            child: Text(
              date,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
                fontSize: 14,
              ),
            ),
          ),
        );
        lastDate = date;
      }

      if (item['type'] == 'group') {
        final group = item['group'] as TransactionGroup;
        widgets.add(_buildGroupCard(group, colors));
      } else {
        final int i = item['index'] as int;
        final tx = item['tx'] as TransactionItem;
        final isSelected = _selectedIndexes.contains(i);
        widgets.add(_buildTxCard(i, tx, isSelected, colors));
      }
    }
    return widgets;
  }

  Widget _buildGroupCard(TransactionGroup group, ThemeColors colors) {
    int total = 0;
    for (final tx in group.items) {
      final raw = tx.amount.replaceAll(RegExp(r'[^0-9]'), '');
      final amount = int.tryParse(raw) ?? 0;
      total += tx.isIncome ? amount : -amount;
    }
    final absTotal = total.abs().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
    );
    final isIncome = total >= 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupPaymentScreen(
              group: group,
              allTransactions: _transactions,
              groupedIndexes: Set.from(_groupedIndexes),
              onGroupDeleted: () async {
                await _loadTransactions();
              },
              onGroupUpdated: (updatedItems, newGroupedIndexes) async {
                await _loadTransactions();
              },
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.group, color: colors.primaryText, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                group.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryText,
                ),
              ),
            ),
            Text(
              '${isIncome ? '+' : '-'}$absTotal원',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isIncome ? Colors.blue : Colors.red,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: colors.subText, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildTxCard(
      int i,
      TransactionItem tx,
      bool isSelected,
      ThemeColors colors,
      ) {
    return GestureDetector(
      onTap: () {
        if (_isGroupSelectMode) {
          setState(() {
            if (isSelected) {
              _selectedIndexes.remove(i);
            } else {
              _selectedIndexes.add(i);
            }
          });
        } else {
          _closeFab();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IndividualPaymentScreen(transaction: tx),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primaryText.withValues(alpha: 0.08)
              : colors.cardBackground,
          borderRadius: BorderRadius.circular(15),
          border: isSelected
              ? Border.all(color: colors.primaryText, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            if (_isGroupSelectMode) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? colors.primaryText : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? colors.primaryText : colors.subText,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Icon(Icons.check, size: 14, color: colors.background)
                    : null,
              ),
              const SizedBox(width: 12),
            ],
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(tx.icon, color: colors.primaryText, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                tx.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryText,
                ),
              ),
            ),
            Text(
              tx.amount,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: tx.isIncome ? Colors.blue : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}