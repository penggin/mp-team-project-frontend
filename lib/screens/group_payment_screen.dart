import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';
import 'individual_payment_screen.dart';
import 'main_payment_screen.dart';

// ══════════════════════════════════════════════════════════
// GroupPaymentScreen
// ══════════════════════════════════════════════════════════
class GroupPaymentScreen extends StatefulWidget {
  final TransactionGroup group;

  /// 메인 화면의 전체 거래 목록 (내역 추가 시 선택 풀로 사용)
  final List<TransactionItem> allTransactions;

  /// 현재 다른 그룹에 속한 인덱스 (추가 선택 시 제외)
  final Set<int> groupedIndexes;

  /// 그룹 삭제 콜백
  final VoidCallback? onGroupDeleted;

  /// 내역 추가/제거 후 메인 상태 갱신 콜백
  final void Function(
    List<TransactionItem> updated,
    Set<int> newGroupedIndexes,
  )?
  onGroupUpdated;

  const GroupPaymentScreen({
    super.key,
    required this.group,
    required this.allTransactions,
    required this.groupedIndexes,
    this.onGroupDeleted,
    this.onGroupUpdated,
  });

  @override
  State<GroupPaymentScreen> createState() => _GroupPaymentScreenState();
}

class _GroupPaymentScreenState extends State<GroupPaymentScreen>
    with TickerProviderStateMixin {
  late String _groupName;
  bool _isEditingName = false;
  final TextEditingController _nameController = TextEditingController();

  // 그룹 내 현재 항목 (제거 가능)
  late List<TransactionItem> _items;

  // ── 내역 수정 메뉴 애니메이션 ──
  bool _isMenuOpen = false;
  late AnimationController _menuAnimController;
  late Animation<double> _overlayAnim;

  // 각 버튼 슬라이드 (아래→위)
  late Animation<Offset> _btn1Slide; // 내역 추가
  late Animation<Offset> _btn2Slide; // 내역 삭제
  late Animation<Offset> _btn3Slide; // 그룹 삭제
  late Animation<double> _btn1Fade;
  late Animation<double> _btn2Fade;
  late Animation<double> _btn3Fade;

  // ── 내역 삭제 모드 ──
  bool _isRemoveMode = false;
  final Set<int> _removeSelected = {}; // items 인덱스

  // ── 내역 추가 모드 ──
  bool _isAddMode = false;
  final Set<int> _addSelected = {}; // allTransactions 인덱스 (새로 추가할 것만)
  Set<int> _preCheckedIndexes = {}; // 이미 그룹에 속한 항목 인덱스 (표시용, 비활성)

  @override
  void initState() {
    super.initState();
    _groupName = widget.group.name;
    _nameController.text = _groupName;
    _items = List.from(widget.group.items);

    _menuAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _overlayAnim = Tween<double>(begin: 0, end: 0.35).animate(
      CurvedAnimation(parent: _menuAnimController, curve: Curves.easeOut),
    );

    // 버튼 1: 가장 먼저 (빠르게)
    _btn1Slide = Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _menuAnimController,
            curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
          ),
        );
    _btn1Fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _menuAnimController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // 버튼 2: 약간 딜레이
    _btn2Slide = Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _menuAnimController,
            curve: const Interval(0.1, 0.75, curve: Curves.easeOutCubic),
          ),
        );
    _btn2Fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _menuAnimController,
        curve: const Interval(0.1, 0.6, curve: Curves.easeOut),
      ),
    );

    // 버튼 3: 더 딜레이
    _btn3Slide = Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _menuAnimController,
            curve: const Interval(0.2, 0.85, curve: Curves.easeOutCubic),
          ),
        );
    _btn3Fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _menuAnimController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _menuAnimController.dispose();
    super.dispose();
  }

  // ── 금액 계산 ──
  int get _totalExpense {
    int total = 0;
    for (final tx in _items) {
      if (!tx.isIncome) {
        final str = tx.amount.replaceAll(RegExp(r'[^0-9]'), '');
        total += int.tryParse(str) ?? 0;
      }
    }
    return total;
  }

  int get _myExpense => (_totalExpense * 0.4).toInt();

  String _fmt(int amount) => amount.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );

  // ── 메뉴 토글 ──
  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _menuAnimController.forward();
      } else {
        _menuAnimController.reverse();
        _isRemoveMode = false;
        _isAddMode = false;
        _removeSelected.clear();
        _addSelected.clear();
      }
    });
  }

  void _closeMenu() {
    if (_isMenuOpen) {
      setState(() {
        _isMenuOpen = false;
        _isRemoveMode = false;
        _isAddMode = false;
        _removeSelected.clear();
        _addSelected.clear();
      });
      _menuAnimController.reverse();
    }
  }

  // ── 내역 추가 모드 진입 ──
  void _enterAddMode() {
    _closeMenu();
    // 이미 그룹에 속한 항목들의 allTransactions 인덱스를 미리 체크
    final preChecked = <int>{};
    for (int i = 0; i < widget.allTransactions.length; i++) {
      if (_items.contains(widget.allTransactions[i])) {
        preChecked.add(i);
      }
    }
    setState(() {
      _isAddMode = true;
      _addSelected.clear();
      // preChecked는 화면 표시용으로만 사용, 확정 시에는 제외
      _preCheckedIndexes = preChecked;
    });
  }

  // ── 내역 삭제 모드 진입 ──
  void _enterRemoveMode() {
    _closeMenu();
    setState(() {
      _isRemoveMode = true;
      _removeSelected.clear();
    });
  }

  // ── 내역 추가 확정 ──
  void _confirmAdd() {
    // _addSelected: allTransactions 인덱스 중 새로 추가할 것만 담겨 있음
    if (_addSelected.isEmpty) return;
    final toAdd = _addSelected.map((i) => widget.allTransactions[i]).toList();
    final newGrouped = Set<int>.from(widget.groupedIndexes);
    for (final idx in _addSelected) {
      newGrouped.add(idx);
    }
    setState(() {
      _items.addAll(toAdd);
      _isAddMode = false;
      _addSelected.clear();
    });
    widget.group.items
      ..clear()
      ..addAll(_items);
    widget.onGroupUpdated?.call(_items, newGrouped);
  }

  // ── 내역 삭제 확정 ──
  void _confirmRemove() {
    if (_removeSelected.isEmpty) return;
    final toRemove = _removeSelected.map((i) => _items[i]).toSet();
    // 메인 groupedIndexes에서도 제거
    if (widget.onGroupUpdated != null) {
      final newGrouped = Set<int>.from(widget.groupedIndexes);
      for (final tx in toRemove) {
        final mainIdx = widget.allTransactions.indexOf(tx);
        if (mainIdx != -1) newGrouped.remove(mainIdx);
      }
      setState(() {
        _items.removeWhere((tx) => toRemove.contains(tx));
        _isRemoveMode = false;
        _removeSelected.clear();
      });
      widget.group.items
        ..clear()
        ..addAll(_items);
      widget.onGroupUpdated!(_items, newGrouped);
    } else {
      setState(() {
        _items.removeWhere((tx) => toRemove.contains(tx));
        _isRemoveMode = false;
        _removeSelected.clear();
      });
    }
  }

  // ── 그룹 삭제 ──
  void _deleteGroup() {
    _closeMenu();
    showDialog(
      context: context,
      builder: (_) {
        final colors = context.read<ThemeProvider>().colors;
        return AlertDialog(
          backgroundColor: colors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            '그룹 삭제',
            style: TextStyle(
              color: colors.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '그룹을 삭제하면 내역이 개별 항목으로 돌아갑니다.\n계속하시겠어요?',
            style: TextStyle(color: colors.subText, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('취소', style: TextStyle(color: colors.subText)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 다이얼로그 닫기
                widget.onGroupDeleted?.call();
                Navigator.pop(context); // GroupPaymentScreen 닫기
              },
              child: Text(
                '삭제',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;

    final expenses = _items.where((tx) => !tx.isIncome).toList();
    final incomes = _items.where((tx) => tx.isIncome).toList();

    return GestureDetector(
      onTap: _isMenuOpen ? _closeMenu : null,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          leading: _isAddMode || _isRemoveMode
              ? TextButton(
                  onPressed: () {
                    setState(() {
                      if (_isRemoveMode) {
                        _isRemoveMode = false;
                        _removeSelected.clear();
                      }
                      if (_isAddMode) {
                        _isAddMode = false;
                        _addSelected.clear();
                        _preCheckedIndexes = {};
                      }
                    });
                  },
                  child: Text(
                    '취소',
                    style: TextStyle(color: colors.primaryText, fontSize: 15),
                  ),
                )
              : IconButton(
                  icon: Icon(Icons.arrow_back, color: colors.primaryText),
                  onPressed: () => Navigator.pop(context),
                ),
          title: Text(
            _isAddMode
                ? '항목 선택'
                : _isRemoveMode
                ? '제외할 내역 선택'
                : '',
            style: TextStyle(
              color: colors.primaryText,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          actions: [
            if (!_isAddMode && !_isRemoveMode)
              TextButton.icon(
                onPressed: _toggleMenu,
                icon: AnimatedRotation(
                  turns: _isMenuOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    Icons.edit_outlined,
                    color: colors.primaryText,
                    size: 18,
                  ),
                ),
                label: Text(
                  '내역 수정',
                  style: TextStyle(
                    color: colors.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_isRemoveMode)
              TextButton(
                onPressed: _confirmRemove,
                child: Text(
                  '제외 (${_removeSelected.length})',
                  style: TextStyle(
                    color: _removeSelected.isEmpty
                        ? colors.subText
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            // ── 메인 스크롤 콘텐츠 ──
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 일반 보기 ──
                  if (!_isAddMode && !_isRemoveMode) ...[
                    GestureDetector(
                      onTap: () {
                        setState(() => _isEditingName = true);
                        Future.delayed(const Duration(milliseconds: 100), () {
                          _nameController
                              .selection = TextSelection.fromPosition(
                            TextPosition(offset: _nameController.text.length),
                          );
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: colors.cardBackground,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _isEditingName
                                  ? TextField(
                                      controller: _nameController,
                                      autofocus: true,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: colors.primaryText,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onSubmitted: (v) => setState(() {
                                        _groupName = v.isEmpty ? _groupName : v;
                                        _isEditingName = false;
                                      }),
                                    )
                                  : Text(
                                      _groupName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: colors.primaryText,
                                      ),
                                    ),
                            ),
                            Icon(
                              Icons.edit_outlined,
                              color: colors.subText,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '총 지출',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: colors.primaryText,
                                ),
                              ),
                              Text(
                                '${_fmt(_totalExpense)}원',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primaryText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '내 지출',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: colors.primaryText,
                                ),
                              ),
                              Text(
                                '${_fmt(_myExpense)}원',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primaryText,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      color: colors.primaryText.withValues(alpha: 0.15),
                      thickness: 1,
                    ),
                    const SizedBox(height: 16),
                    if (expenses.isNotEmpty) ...[
                      Text(
                        '지출',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colors.primaryText,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._buildDateGroupedCards(expenses, colors),
                      const SizedBox(height: 16),
                    ],
                    if (incomes.isNotEmpty) ...[
                      Text(
                        '수입',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colors.primaryText,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._buildDateGroupedCards(incomes, colors),
                    ],
                  ],

                  // ── 내역 삭제 모드 ──
                  if (_isRemoveMode) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '그룹에서 제외할 항목을 선택하세요',
                        style: TextStyle(color: colors.subText, fontSize: 13),
                      ),
                    ),
                    ..._items.asMap().entries.map((e) {
                      final idx = e.key;
                      final tx = e.value;
                      final sel = _removeSelected.contains(idx);
                      return _buildSelectableCard(
                        tx: tx,
                        isSelected: sel,
                        isDisabled: false,
                        accentColor: Colors.red,
                        colors: colors,
                        onTap: () => setState(() {
                          if (sel) {
                            _removeSelected.remove(idx);
                          } else {
                            _removeSelected.add(idx);
                          }
                        }),
                      );
                    }),
                  ],

                  // ── 내역 추가 모드: 전체 거래 목록을 날짜 구분선사와 함께 표시 ──
                  if (_isAddMode) ..._buildAddModeList(colors),

                  const SizedBox(height: 120),
                ],
              ),
            ),

            // ── 반투명 오버레이 ──
            AnimatedBuilder(
              animation: _overlayAnim,
              builder: (context, child) => _overlayAnim.value > 0
                  ? GestureDetector(
                      onTap: _closeMenu,
                      child: Container(
                        color: Colors.black.withValues(
                          alpha: _overlayAnim.value,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // ── 내역 추가 모드: 하단 확인 버튼 ──
            if (_isAddMode)
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: AnimatedOpacity(
                  opacity: _addSelected.isNotEmpty ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: GestureDetector(
                    onTap: _confirmAdd,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: colors.primaryText,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Text(
                          _addSelected.isEmpty
                              ? '추가할 항목을 선택하세요'
                              : '확인 (${_addSelected.length}개 추가)',
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

            // ── 내역 수정 플로팅 메뉴 ──
            if (!_isAddMode && !_isRemoveMode)
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _btn3Fade,
                      child: SlideTransition(
                        position: _btn3Slide,
                        child: GestureDetector(
                          onTap: _deleteGroup,
                          child: _menuButton(
                            icon: Icons.delete_outline,
                            label: '그룹 삭제',
                            color: Colors.red,
                            colors: colors,
                          ),
                        ),
                      ),
                    ),
                    FadeTransition(
                      opacity: _btn2Fade,
                      child: SlideTransition(
                        position: _btn2Slide,
                        child: GestureDetector(
                          onTap: _enterRemoveMode,
                          child: _menuButton(
                            icon: Icons.remove_circle_outline,
                            label: '내역 삭제',
                            color: colors.primaryText,
                            colors: colors,
                          ),
                        ),
                      ),
                    ),
                    FadeTransition(
                      opacity: _btn1Fade,
                      child: SlideTransition(
                        position: _btn1Slide,
                        child: GestureDetector(
                          onTap: _enterAddMode,
                          child: _menuButton(
                            icon: Icons.add_circle_outline,
                            label: '내역 추가',
                            color: colors.primaryText,
                            colors: colors,
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

  // ── 내역 추가 모드: 전체 목록을 날짜 구분선사와 함께 표시 ──
  List<Widget> _buildAddModeList(ThemeColors colors) {
    final widgets = <Widget>[];
    String? lastDate;

    for (int i = 0; i < widget.allTransactions.length; i++) {
      final tx = widget.allTransactions[i];

      // 날짜 구분선
      if (tx.date != lastDate) {
        if (lastDate != null) widgets.add(const SizedBox(height: 4));
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              tx.date,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
                fontSize: 14,
              ),
            ),
          ),
        );
        lastDate = tx.date;
      }

      // 상태 분류:
      // 1) 이미 이 그룹에 속함 → 체크된 상태 + 비활성
      // 2) 다른 그룹에 속함 → 회색 + 비활성
      // 3) 선택 가능 → 체크박스 토글
      final isPreChecked = _preCheckedIndexes.contains(i); // 이미 그룹 속한 항목
      final isOtherGroup =
          widget.groupedIndexes.contains(i) && !isPreChecked; // 다른 그룹
      final isNewSelected = _addSelected.contains(i); // 새로 선택 중

      // 표시상 선택 상태
      final bool showChecked = isPreChecked || isNewSelected;
      final bool isDisabled = isPreChecked || isOtherGroup;

      // 체크 색상: 이미 그룹 항목은 연한 색, 새 선택은 진한 색
      final Color checkColor = isPreChecked
          ? colors.primaryText.withValues(alpha: 0.35)
          : colors.primaryText;

      widgets.add(
        _buildSelectableCard(
          tx: tx,
          isSelected: showChecked,
          isDisabled: isDisabled,
          accentColor: checkColor,
          colors: colors,
          onTap: isDisabled
              ? null
              : () => setState(() {
                  if (isNewSelected) {
                    _addSelected.remove(i);
                  } else {
                    _addSelected.add(i);
                  }
                }),
        ),
      );
    }
    return widgets;
  }

  // ── 날짜 구분선을 포함해 카드 목록 생성 ──
  List<Widget> _buildDateGroupedCards(
    List<TransactionItem> items,
    ThemeColors colors,
  ) {
    final widgets = <Widget>[];
    String? lastDate;

    // createdAt 내림차순 정렬 (없으면 원래 순서 유지)
    final sorted = List<TransactionItem>.from(items)
      ..sort((a, b) {
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

    for (final tx in sorted) {
      if (tx.date != lastDate) {
        if (lastDate != null) widgets.add(const SizedBox(height: 4));
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 2),
            child: Text(
              tx.date,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.subText,
              ),
            ),
          ),
        );
        lastDate = tx.date;
      }
      widgets.add(_buildTxCard(tx, colors, mode: _TxCardMode.normal));
    }
    return widgets;
  }

  // ── 일반 카드 ──
  Widget _buildTxCard(
    TransactionItem tx,
    ThemeColors colors, {
    required _TxCardMode mode,
  }) {
    final amountStr = tx.amount.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(amountStr) ?? 0;

    return GestureDetector(
      onTap: mode == _TxCardMode.normal
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => IndividualPaymentScreen(transaction: tx),
              ),
            )
          : null,
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
              '${_fmt(amount)} 원',
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

  // ── 선택 가능한 카드 (추가/삭제 모드) ──
  Widget _buildSelectableCard({
    required TransactionItem tx,
    required bool isSelected,
    required bool isDisabled,
    required Color accentColor,
    required ThemeColors colors,
    required VoidCallback? onTap,
  }) {
    final amountStr = tx.amount.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(amountStr) ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isDisabled
              ? colors.cardBackground.withValues(alpha: 0.5)
              : isSelected
              ? accentColor.withValues(alpha: 0.08)
              : colors.cardBackground,
          borderRadius: BorderRadius.circular(15),
          border: isSelected
              ? Border.all(color: accentColor, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            // 체크 원형
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accentColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? accentColor : colors.subText,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 14, color: colors.background)
                  : null,
            ),

            const SizedBox(width: 12),

            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                tx.icon,
                color: isDisabled ? colors.subText : colors.primaryText,
                size: 22,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Text(
                tx.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDisabled ? colors.subText : colors.primaryText,
                ),
              ),
            ),

            Text(
              '${_fmt(amount)} 원',
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

Widget _menuButton({
  required IconData icon,
  required String label,
  required Color color,
  required ThemeColors colors,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      color: colors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

enum _TxCardMode { normal }
