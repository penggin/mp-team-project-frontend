import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_colors.dart';
import 'individual_payment_screen.dart';
import 'main_payment_screen.dart';
import 'group_payment_screen.dart';

class CategoryDetailScreen extends StatelessWidget {
  final String category;
  final List<TransactionItem> transactions;

  // 기타(그룹) 카테고리용 — 일반 카테고리일 때는 빈 리스트
  final List<TransactionGroup> groups;

  const CategoryDetailScreen({
    super.key,
    required this.category,
    required this.transactions,
    this.groups = const [],
  });

  // 일반 거래 합계 + 그룹 내 지출 합계
  int get totalAmount {
    int total = 0;
    for (final tx in transactions) {
      final raw = tx.amount.replaceAll(RegExp(r'[^0-9]'), '');
      total += int.tryParse(raw) ?? 0;
    }
    for (final group in groups) {
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
      if (myExpense > 0) total += myExpense;
    }
    return total;
  }

  String get formattedTotal {
    final formatted = totalAmount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$formatted 원';
  }

  // 총 항목 수 (일반 거래 + 그룹 수)
  int get itemCount => transactions.length + groups.length;

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;

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
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        formattedTotal,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: colors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '횟수 $itemCount회',
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

          // 그룹 카드 목록 (기타 카테고리)
          if (groups.isNotEmpty) ..._buildGroupList(context, colors),

          // 일반 거래 목록
          ..._buildTransactionList(context, colors),
        ],
      ),
    );
  }

  // 그룹 카드 목록
  List<Widget> _buildGroupList(BuildContext context, ThemeColors colors) {
    final widgets = <Widget>[];

    if (groups.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '그룹',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colors.primaryText,
            ),
          ),
        ),
      );
    }

    for (final group in groups) {
      // 그룹 내 지출 - 수입 = 내 지출
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
      final absStr = myExpense.abs().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

      widgets.add(
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupPaymentScreen(
                  group: group,
                  allTransactions: group.items,
                  groupedIndexes: {},
                ),
              ),
            );
          },
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
                  child: Icon(Icons.group, color: colors.primaryText),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    group.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: colors.primaryText,
                    ),
                  ),
                ),
                Text(
                  '-$absStr원',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: colors.subText, size: 18),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  // 일반 거래 목록
  List<Widget> _buildTransactionList(BuildContext context, ThemeColors colors) {
    final widgets = <Widget>[];
    if (transactions.isEmpty) return widgets;

    String? lastDate;

    for (final tx in transactions) {
      if (tx.date != lastDate) {
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => IndividualPaymentScreen(transaction: tx),
              ),
            );
          },
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
                Text(
                  tx.amount,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
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
