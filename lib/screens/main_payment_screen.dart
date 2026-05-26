import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'notification_screen.dart';
import 'ledger_screen.dart';
import 'category_payment_screen.dart';
import 'individual_payment_screen.dart';
import 'group_payment_screen.dart'; // ✅ 추가
import 'main_screen.dart';
import '../app_colors.dart';
import 'add_payment_screen.dart';

class CategorySummary {
  final String title;
  final int amountInt;   // 실제 계산용 정수
  final Color color;

  const CategorySummary({
    required this.title,
    required this.amountInt,
    required this.color,
  });

  /// 화면에 표시할 금액 문자열
  String get amount {
    final formatted = amountInt
        .toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
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

  TransactionGroup({required this.name, required this.items});
}

class MainPaymentScreen extends StatefulWidget {
  const MainPaymentScreen({super.key});

  @override
  State<MainPaymentScreen> createState() => _MainPaymentScreenState();

  // ✅ 외부에서 거래 데이터를 읽을 수 있도록 GlobalKey를 통해 접근
  static List<TransactionItem> transactionsOf(GlobalKey<State<MainPaymentScreen>> key) {
    final s = key.currentState;
    if (s is _MainPaymentScreenState) return s._transactions;
    return [];
  }

  static Set<int> groupedIndexesOf(GlobalKey<State<MainPaymentScreen>> key) {
    final s = key.currentState;
    if (s is _MainPaymentScreenState) return s._groupedIndexes;
    return {};
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

  int currentMonth = 3;
  int currentYear = 2025;

  // ✅ 그룹 선택 모드
  bool _isGroupSelectMode = false;
  final Set<int> _selectedIndexes = {};

  // ✅ 그룹 목록
  final List<TransactionGroup> _groups = [];

  // ✅ 그룹에 포함된 항목 인덱스 (메인 리스트에서 숨김)
  final Set<int> _groupedIndexes = {};

  // ✅ 카테고리별 색상 매핑
  static const Map<String, Color> _categoryColors = {
    '이체':              Color(0xFF9FA8DA),
    '카테고리 없음':     Color(0xFFBDBDBD),
    '식비':              Color(0xFFFDD835),
    '쇼핑, 여가':        Color(0xFFEF9A9A),
    '여행, 숙박':        Color(0xFFA5D6A7),
    '카페':              Color(0xFFBCAAA4),
    '편의점, 마트, 잡화': Color(0xFF9E9E9E),
    '교통':              Color(0xFF80CBC4),
  };

  // ✅ 더미 거래 내역 (List로 변경 — 나중에 그룹화 시 수정 가능하도록)
  late List<TransactionItem> _transactions;

  // ✅ 활성 거래(그룹화 제외)에서 카테고리 요약을 동적으로 계산
  List<CategorySummary> get _categories {
    final Map<String, int> totals = {};
    for (int i = 0; i < _transactions.length; i++) {
      if (_groupedIndexes.contains(i)) continue;
      final tx = _transactions[i];
      if (tx.isIncome) continue;  // 지출만 집계
      final raw = tx.amount.replaceAll(RegExp(r'[^0-9]'), '');
      final val = int.tryParse(raw) ?? 0;
      totals[tx.category] = (totals[tx.category] ?? 0) + val;
    }
    // 금액 큰 순으로 정렬
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => CategorySummary(
      title: e.key,
      amountInt: e.value,
      color: _categoryColors[e.key] ?? const Color(0xFFBDBDBD),
    )).toList();
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
    final formatted = total
        .toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '${formatted}원';
  }

  @override
  void initState() {
    super.initState();

    _transactions = [
      TransactionItem(date: '3.31', title: '메가커피 가천대점', amount: '-2,000 원', isIncome: false, category: '카페', icon: Icons.local_cafe),
      TransactionItem(date: '3.30', title: '공유빈', amount: '+50,000 원', isIncome: true, category: '이체', icon: Icons.account_balance_wallet),
      TransactionItem(date: '3.29', title: '호식당', amount: '-13,000 원', isIncome: false, category: '식비', icon: Icons.restaurant),
      TransactionItem(date: '3.28', title: '호식당', amount: '-7,800 원', isIncome: false, category: '식비', icon: Icons.restaurant),
      TransactionItem(date: '3.27', title: '메가커피 가천대점', amount: '-2,000 원', isIncome: false, category: '카페', icon: Icons.local_cafe),
      TransactionItem(date: '3.26', title: 'GS25 가천대점', amount: '-4,500 원', isIncome: false, category: '편의점, 마트, 잡화', icon: Icons.storefront),
      TransactionItem(date: '3.24', title: '알바비 입금', amount: '+300,000 원', isIncome: true, category: '이체', icon: Icons.monetization_on),
      TransactionItem(date: '3.20', title: '다이소', amount: '-5,000 원', isIncome: false, category: '쇼핑, 여가', icon: Icons.shopping_bag),
      TransactionItem(date: '3.17', title: '올리브영', amount: '-24,000 원', isIncome: false, category: '쇼핑, 여가', icon: Icons.face_retouching_natural),
      TransactionItem(date: '3.15', title: '넷플릭스 결제', amount: '-13,500 원', isIncome: false, category: '쇼핑, 여가', icon: Icons.movie),
      TransactionItem(date: '3.10', title: '엄마 용돈', amount: '+100,000 원', isIncome: true, category: '이체', icon: Icons.volunteer_activism),
      TransactionItem(date: '3.5', title: '버스 정기권', amount: '-55,000 원', isIncome: false, category: '교통', icon: Icons.directions_bus),
    ];
    // 참고: 초기 더미 데이터 기준 카테고리별 지출 합계
    // 이체(수입): 450,000 / 식비: 20,800 / 카페: 4,000 / 편의점: 4,500
    // 쇼핑,여가: 42,500 / 교통: 55,000 / 카테고리 없음: 0

    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fabScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimController, curve: Curves.easeOutBack),
    );
    _btn1SlideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fabAnimController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));
    _btn2SlideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fabAnimController,
      curve: const Interval(0.1, 1.0, curve: Curves.easeOut),
    ));
    _overlayAnim = Tween<double>(begin: 0.0, end: 0.3).animate(
      CurvedAnimation(parent: _fabAnimController, curve: Curves.easeOut),
    );
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
      if (currentMonth > 12) { currentMonth = 1; currentYear++; }
      else if (currentMonth < 1) { currentMonth = 12; currentYear--; }
    });
    _closeFab();
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

  // ✅ 확인 버튼 → GroupPaymentScreen으로 이동
  void _confirmGroupSelection(ThemeColors colors) {
    if (_selectedIndexes.isEmpty) return;

    final selectedItems = _selectedIndexes.map((i) => _transactions[i]).toList();
    final groupName = '그룹${_groups.length + 1}';
    final newGroup = TransactionGroup(name: groupName, items: selectedItems);

    setState(() {
      _groups.add(newGroup);
      _groupedIndexes.addAll(_selectedIndexes);
      _isGroupSelectMode = false;
      _selectedIndexes.clear();
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupPaymentScreen(
          group: newGroup,
          allTransactions: _transactions,
          groupedIndexes: Set.from(_groupedIndexes),
          onGroupDeleted: () {
            setState(() {
              _groups.remove(newGroup);
              for (final item in newGroup.items) {
                final idx = _transactions.indexOf(item);
                if (idx != -1) _groupedIndexes.remove(idx);
              }
            });
          },
          onGroupUpdated: (updatedItems, newGroupedIndexes) {
            setState(() {
              _groupedIndexes
                ..clear()
                ..addAll(newGroupedIndexes);
            });
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
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          leading: _isGroupSelectMode
          // ✅ 그룹 선택 모드일 때 취소 버튼
              ? TextButton(
            onPressed: _cancelGroupSelectMode,
            child: Text('취소',
                style: TextStyle(color: colors.primaryText, fontSize: 15)),
          )
              : IconButton(
            icon: Icon(Icons.menu, color: colors.primaryText, size: 32),
            onPressed: _closeFab,
          ),
          title: _isGroupSelectMode
              ? Text('항목 선택',
              style: TextStyle(
                  color: colors.primaryText, fontWeight: FontWeight.bold))
              : null,
          actions: [
            if (!_isGroupSelectMode)
              IconButton(
                icon: Icon(Icons.notifications_none, color: colors.primaryText, size: 32),
                onPressed: () {
                  _closeFab();
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const NotificationScreen()));
                },
              ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              physics: const BouncingScrollPhysics(),
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
                                  child: Icon(Icons.chevron_left, color: colors.primaryText),
                                ),
                                const SizedBox(width: 5),
                                Text('$currentMonth월',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.primaryText)),
                                const SizedBox(width: 5),
                                GestureDetector(
                                  onTap: () => _changeMonth(1),
                                  child: Icon(Icons.chevron_right, color: colors.primaryText),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(_totalAmount,
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colors.primaryText)),
                            const SizedBox(height: 20),
                            Builder(builder: (_) {
                              final cats = _categories;
                              final total = cats.fold(0, (s, c) => s + c.amountInt);
                              return Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      height: 20,
                                      child: cats.isEmpty
                                          ? Container(color: const Color(0xFFBDBDBD))
                                          : Row(
                                              children: cats.map((cat) =>
                                                Expanded(
                                                  flex: cat.flexOf(total),
                                                  child: Container(color: cat.color),
                                                )
                                              ).toList(),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 6,
                                    children: cats.map((cat) => Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 10, height: 10,
                                          decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(cat.title, style: TextStyle(fontSize: 11, color: colors.subText)),
                                      ],
                                    )).toList(),
                                  ),
                                ],
                              );
                            }),
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
                          Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const LedgerScreenWrapper()));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: colors.cardBackground,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_month_outlined, color: colors.primaryText, size: 18),
                              const SizedBox(width: 6),
                              Text('달력보기',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.primaryText)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ✅ 그룹 목록 표시
                    if (_groups.isNotEmpty) ...[
                      Text('그룹',
                          style: TextStyle(fontWeight: FontWeight.bold, color: colors.primaryText, fontSize: 14)),
                      const SizedBox(height: 8),
                      ..._groups.map((group) => GestureDetector(
                      onTap: () {
                      Navigator.push(context,
                      MaterialPageRoute(builder: (_) => GroupPaymentScreen(
                              group: group,
                              allTransactions: _transactions,
                              groupedIndexes: Set.from(_groupedIndexes),
                                onGroupDeleted: () {
                                  setState(() {
                                    _groups.remove(group);
                                    for (final item in group.items) {
                                      final idx = _transactions.indexOf(item);
                                      if (idx != -1) _groupedIndexes.remove(idx);
                                    }
                                  });
                                },
                                onGroupUpdated: (updatedItems, newGroupedIndexes) {
                                  setState(() {
                                    _groupedIndexes
                                      ..clear()
                                      ..addAll(newGroupedIndexes);
                                  });
                                },
                              )));
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
                                width: 42, height: 42,
                                decoration: BoxDecoration(color: colors.background, shape: BoxShape.circle),
                                child: Icon(Icons.group, color: colors.primaryText, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(group.name,
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.primaryText)),
                              ),
                              Builder(
                                builder: (_) {
                                  int total = 0;

                                  for (final tx in group.items) {
                                    final raw = tx.amount.replaceAll(RegExp(r'[^0-9]'), '');
                                    final amount = int.tryParse(raw) ?? 0;

                                    if (tx.isIncome) {
                                      total += amount;
                                    } else {
                                      total -= amount;
                                    }
                                  }

                                  final absTotal = total.abs()
                                      .toString()
                                      .replaceAllMapped(
                                    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                                        (m) => '${m[1]},',
                                  );

                                  final isIncome = total >= 0;

                                  return Text(
                                    '${isIncome ? '+' : '-'}$absTotal원',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isIncome ? Colors.blue : Colors.red,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right, color: colors.subText, size: 18),
                            ],
                          ),
                        ),
                      )),
                      const SizedBox(height: 8),
                    ],
                  ],

                  // ══════════════════════════════
                  // 전체 결제 이력 리스트
                  // ══════════════════════════════
                  ..._buildTransactionList(colors),

                  const SizedBox(height: 100),
                ],
              ),
            ),

            // ✅ 반투명 오버레이 (FAB 열렸을 때)
            AnimatedBuilder(
              animation: _overlayAnim,
              builder: (context, child) {
                return _overlayAnim.value > 0
                    ? GestureDetector(
                  onTap: _closeFab,
                  child: Container(color: Colors.black.withOpacity(_overlayAnim.value)),
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
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: colors.background,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [BoxShadow(color: colors.primaryText.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Text('그룹 생성',
                                style: TextStyle(fontWeight: FontWeight.bold, color: colors.primaryText, fontSize: 14)),
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

                            Navigator.push(
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
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: colors.background,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [BoxShadow(color: colors.primaryText.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Text('입출금 추가',
                                style: TextStyle(fontWeight: FontWeight.bold, color: colors.primaryText, fontSize: 14)),
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _toggleFab,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: _isFabExpanded ? colors.primaryText : colors.background,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.cardBackground, width: 2),
                          boxShadow: [BoxShadow(color: colors.primaryText.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: AnimatedRotation(
                          turns: _isFabExpanded ? 0.125 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: Icon(Icons.add,
                              color: _isFabExpanded ? colors.background : colors.accent, size: 30),
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
    final List<Widget> widgets = [];
    String? lastDate;

    for (int i = 0; i < _transactions.length; i++) {
      // ✅ 그룹화된 항목은 숨김
      if (_groupedIndexes.contains(i)) continue;

      final tx = _transactions[i];

      if (tx.date != lastDate) {
        if (lastDate != null) widgets.add(const SizedBox(height: 4));
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
            child: Text(tx.date,
                style: TextStyle(fontWeight: FontWeight.bold, color: colors.primaryText, fontSize: 14)),
          ),
        );
        lastDate = tx.date;
      }

      final isSelected = _selectedIndexes.contains(i);

      widgets.add(
        GestureDetector(
          onTap: () {
            if (_isGroupSelectMode) {
              // ✅ 그룹 선택 모드: 체크박스 토글
              setState(() {
                if (isSelected) {
                  _selectedIndexes.remove(i);
                } else {
                  _selectedIndexes.add(i);
                }
              });
            } else {
              _closeFab();
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => IndividualPaymentScreen(transaction: tx)));
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primaryText.withOpacity(0.08)
                  : colors.cardBackground,
              borderRadius: BorderRadius.circular(15),
              border: isSelected
                  ? Border.all(color: colors.primaryText, width: 1.5)
                  : null,
            ),
            child: Row(
              children: [
                // ✅ 그룹 선택 모드일 때 체크박스 표시
                if (_isGroupSelectMode) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 24, height: 24,
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
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: colors.background, shape: BoxShape.circle),
                  child: Icon(tx.icon, color: colors.primaryText, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(tx.title,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.primaryText)),
                ),
                Text(tx.amount,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                        color: tx.isIncome ? Colors.blue : Colors.red)),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }
}