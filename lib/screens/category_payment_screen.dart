import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'notification_screen.dart';
import 'individual_payment_screen.dart';
import 'main_payment_screen.dart';
import '../app_colors.dart';

// --- 카테고리별 결제 화면 ---
class CategoryPaymentScreen extends StatelessWidget {
  /// main_payment_screen 에서 넘갨주는 활성 거래 목록
  final List<TransactionItem> transactions;
  /// 그룹화된 인덱스 세트 (=스크린에 노출되지 않는 항목)
  final Set<int> groupedIndexes;

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

  const CategoryPaymentScreen({
    super.key,
    required this.transactions,
    required this.groupedIndexes,
  });

  /// 활성 거래에서 카테고리 요약 계산
  List<CategorySummary> _calcCategories() {
    final Map<String, int> totals = {};
    for (int i = 0; i < transactions.length; i++) {
      if (groupedIndexes.contains(i)) continue;
      final tx = transactions[i];
      if (tx.isIncome) continue;
      final raw = tx.amount.replaceAll(RegExp(r'[^0-9]'), '');
      final val = int.tryParse(raw) ?? 0;
      totals[tx.category] = (totals[tx.category] ?? 0) + val;
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => CategorySummary(
      title: e.key,
      amountInt: e.value,
      color: _categoryColors[e.key] ?? const Color(0xFFBDBDBD),
    )).toList();
  }

  String _totalAmount(List<CategorySummary> cats) {
    final total = cats.fold(0, (s, c) => s + c.amountInt);
    final formatted = total
        .toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '${formatted}원';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;
    final cats = _calcCategories();
    final total = cats.fold(0, (s, c) => s + c.amountInt);

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // 1. 상단 총액 및 막대그래프 카드
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.chevron_left, color: colors.primaryText),
                      const SizedBox(width: 5),
                      Text('3월', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.primaryText)),
                      const SizedBox(width: 5),
                      Icon(Icons.chevron_right, color: colors.primaryText),
                    ],
                  ),
                  const SizedBox(height: 15),
                  // 동적 지출 총액
                  Text(_totalAmount(cats), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colors.primaryText)),
                  const SizedBox(height: 25),
                  // 동적 막대 그래프
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
                ],
              ),
            ),
            const SizedBox(height: 25),

            // 2. 카테고리별 리스트 내역
            if (cats.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text('지출 내역이 없습니다.',
                    style: TextStyle(color: colors.subText, fontSize: 15)),
              )
            else
              ...cats.map((cat) => _buildCategoryItem(cat.title, cat.amount, cat.color, colors)),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(String title, String amount, Color indicatorColor, ThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 12, backgroundColor: indicatorColor),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
              ),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}