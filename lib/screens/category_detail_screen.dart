import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_colors.dart';
import 'individual_payment_screen.dart';

class CategoryDetailScreen extends StatelessWidget {
  final String category;
  final List<TransactionItem> transactions;

  const CategoryDetailScreen({
    super.key,
    required this.category,
    required this.transactions,
  });

  int get totalAmount {
    int total = 0;

    for (final tx in transactions) {
      final raw = tx.amount.replaceAll(RegExp(r'[^0-9]'), '');
      total += int.tryParse(raw) ?? 0;
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
                        '횟수 ${transactions.length}회',
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

          ..._buildTransactionList(context, colors),
        ],
      ),
    );
  }

  List<Widget> _buildTransactionList(BuildContext context, ThemeColors colors) {
    final widgets = <Widget>[];

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
