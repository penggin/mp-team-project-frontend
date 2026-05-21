import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'notification_screen.dart';
import 'ledger_screen.dart';
import 'category_payment_screen.dart';
import 'individual_payment_screen.dart';
import 'main_screen.dart';
import '../app_colors.dart';

// ✅ CategorySummary 클래스 (이 파일에만 존재)
class CategorySummary {
  final String title;
  final String amount;
  final Color color;
  final int flex;

  const CategorySummary({
    required this.title,
    required this.amount,
    required this.color,
    required this.flex,
  });
}

class MainPaymentScreen extends StatefulWidget {
  const MainPaymentScreen({super.key});

  @override
  State<MainPaymentScreen> createState() => _MainPaymentScreenState();
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

  // ✅ TransactionItem은 individual_payment_screen.dart에서 import해서 사용
  final List<TransactionItem> _transactions = const [
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

  final List<CategorySummary> _categories = const [
    CategorySummary(title: '이체', amount: '350,000 원', color: Color(0xFF9FA8DA), flex: 35),
    CategorySummary(title: '카테고리 없음', amount: '158,000 원', color: Color(0xFFBDBDBD), flex: 15),
    CategorySummary(title: '식비', amount: '84,000 원', color: Color(0xFFFDD835), flex: 8),
    CategorySummary(title: '쇼핑, 여가', amount: '47,000 원', color: Color(0xFFEF9A9A), flex: 5),
    CategorySummary(title: '여행, 숙박', amount: '33,000 원', color: Color(0xFFA5D6A7), flex: 3),
    CategorySummary(title: '카페', amount: '5,000 원', color: Color(0xFFBCAAA4), flex: 1),
    CategorySummary(title: '편의점, 마트, 잡화', amount: '2,000 원', color: Color(0xFF9E9E9E), flex: 2),
  ];

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

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;

    return GestureDetector(
      onTap: _closeFab,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.menu, color: colors.primaryText, size: 32),
            onPressed: _closeFab,
          ),
          actions: [
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

                  // ══════════════════════════════
                  // 1. 카테고리별 요약 카드
                  // ══════════════════════════════
                  GestureDetector(
                    onTap: () {
                      _closeFab();
                      MainScreen.globalKey.currentState?.changeTab(4); // 4번 = CategoryPaymentScreen
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
                                child: Icon(Icons.chevron_right, color: colors.primaryText),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '578,450원',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: colors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              height: 20,
                              child: Row(
                                children: _categories.map((cat) {
                                  return Expanded(
                                    flex: cat.flex,
                                    child: Container(color: cat.color),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            children: _categories.map((cat) {
                              return Row(
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
                                    style: TextStyle(fontSize: 11, color: colors.subText),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ══════════════════════════════
                  // 2. 달력보기 버튼
                  // ══════════════════════════════
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.cardBackground,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_month_outlined,
                                color: colors.primaryText, size: 18),
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

                  // ══════════════════════════════
                  // 3. 전체 결제 이력 리스트
                  // ══════════════════════════════
                  ..._buildTransactionList(colors),

                  const SizedBox(height: 100),
                ],
              ),
            ),

            // ✅ 반투명 오버레이
            AnimatedBuilder(
              animation: _overlayAnim,
              builder: (context, child) {
                return _overlayAnim.value > 0
                    ? GestureDetector(
                  onTap: _closeFab,
                  child: Container(
                    color: Colors.black.withOpacity(_overlayAnim.value),
                  ),
                )
                    : const SizedBox.shrink();
              },
            ),

            // ✅ FAB + 슬라이드 버튼
            Positioned(
              bottom: 24,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 그룹 생성 버튼
                  SlideTransition(
                    position: _btn2SlideAnim,
                    child: ScaleTransition(
                      scale: _fabScaleAnim,
                      child: GestureDetector(
                        onTap: () {
                          _closeFab();
                          // TODO: 그룹 생성 화면 이동
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: colors.background,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primaryText.withOpacity(0.15),
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

                  // 입출금 추가 버튼
                  SlideTransition(
                    position: _btn1SlideAnim,
                    child: ScaleTransition(
                      scale: _fabScaleAnim,
                      child: GestureDetector(
                        onTap: () {
                          _closeFab();
                          // TODO: 입출금 추가 화면 이동
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: colors.background,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primaryText.withOpacity(0.15),
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

                  // 메인 FAB 버튼
                  GestureDetector(
                    onTap: _toggleFab,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _isFabExpanded ? colors.primaryText : colors.background,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.cardBackground, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primaryText.withOpacity(0.2),
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
                          color: _isFabExpanded ? colors.background : colors.accent,
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
    final List<Widget> widgets = [];
    String? lastDate;

    for (final tx in _transactions) {
      if (tx.date != lastDate) {
        if (lastDate != null) widgets.add(const SizedBox(height: 4));
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
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

      widgets.add(
        GestureDetector(
          onTap: () {
            _closeFab();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => IndividualPaymentScreen(transaction: tx),
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
        ),
      );
    }
    return widgets;
  }
}