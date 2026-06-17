import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_colors.dart';
import 'individual_payment_screen.dart';
import 'main_payment_screen.dart';

class CategoryDetailScreen extends StatelessWidget {
  final String category;
  final List<TransactionItem> transactions;
  // 그룹에서 비율 계산된 항목들: {'tx': TransactionItem, 'myAmount': int}
  final List<Map<String, dynamic>> groupExpandedItems;

  const CategoryDetailScreen({
    super.key,
    required this.category,
    required this.transactions,
    this.groupExpandedItems = const [],
  });

  String _fmt(int amount) => amount.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  int get _totalAmount {
    int total = 0;
    for (final tx in transactions) {
      final raw = tx.amount.replaceAll(RegExp(r'[^0-9]'), '');
      total += int.tryParse(raw) ?? 0;
    }
    for (final item in groupExpandedItems) {
      total += item['myAmount'] as int;
    }
    return total;
  }

  int get _itemCount => transactions.length + groupExpandedItems.length;

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;

    // 일반 항목 + 그룹 비율 항목을 합쳐서 최신순 정렬
    final allItems = <Map<String, dynamic>>[];
    for (final tx in transactions) {
      allItems.add({
        'type': 'normal',
        'tx': tx,
        'sortKey': tx.createdAt ?? DateTime(0),
      });
    }
    for (final item in groupExpandedItems) {
      final tx = item['tx'] as TransactionItem;
      allItems.add({
        'type': 'group',
        'tx': tx,
        'myAmount': item['myAmount'],
        'sortKey': tx.createdAt ?? DateTime(0),
      });
    }
    allItems.sort(
      (a, b) => (b['sortKey'] as DateTime).compareTo(a['sortKey'] as DateTime),
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '상세내역',
          style: TextStyle(
            color: colors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 8),

          // 상단 요약 카드
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_fmt(_totalAmount)} 원',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: colors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '횟수 $_itemCount회',
                        style: TextStyle(fontSize: 14, color: colors.subText),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.accent.withValues(alpha: 0.25),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 날짜별 항목 목록 (일반 + 그룹 비율 항목 통합)
          ..._buildList(context, colors, allItems),
        ],
      ),
    );
  }

  List<Widget> _buildList(
    BuildContext context,
    ThemeColors colors,
    List<Map<String, dynamic>> items,
  ) {
    final widgets = <Widget>[];
    String? lastDate;

    for (final item in items) {
      final tx = item['tx'] as TransactionItem;
      final isGroupItem = item['type'] == 'group';
      final myAmount = isGroupItem ? item['myAmount'] as int : null;

      // 날짜 헤더
      if (tx.date != lastDate) {
        if (lastDate != null) widgets.add(const SizedBox(height: 4));
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Text(
              tx.date,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
              ),
            ),
          ),
        );
        lastDate = tx.date;
      }

      widgets.add(
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IndividualPaymentScreen(transaction: tx),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.background,
                  ),
                  child: Icon(tx.icon, color: colors.primaryText),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    tx.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: colors.primaryText,
                    ),
                  ),
                ),
                // 그룹 항목: 비율 계산된 내 몫 / 일반 항목: 원래 금액
                Text(
                  isGroupItem
                      ? '-${_fmt(myAmount!)} 원'
                      : tx.amount,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.red,
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
