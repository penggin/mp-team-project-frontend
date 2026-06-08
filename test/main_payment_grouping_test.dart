import 'package:first/screens/individual_payment_screen.dart';
import 'package:first/screens/main_payment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TransactionItem item({
    required String id,
    String? bundleId,
    String title = '스타벅스',
  }) {
    return TransactionItem(
      id: id,
      bundleId: bundleId,
      date: '5.27',
      title: title,
      amount: '-5,000 원',
      isIncome: false,
      category: '카페',
      icon: Icons.local_cafe,
    );
  }

  test(
    'buildGroupingState restores backend bundles from ledger bundle ids',
    () {
      final transactions = [
        item(id: 'entry-1', bundleId: 'bundle-1', title: '메가커피'),
        item(id: 'entry-2', title: '편의점'),
        item(id: 'entry-3', bundleId: 'bundle-1', title: '스타벅스'),
      ];

      final state = MainPaymentScreen.buildGroupingState(transactions, [
        {'id': 'bundle-1', 'name': '카페 모음', 'bundle_date': '2026-05-27'},
      ]);

      expect(state.groupedIndexes, {0, 2});
      expect(state.groups, hasLength(1));
      expect(state.groups.single.id, 'bundle-1');
      expect(state.groups.single.name, '카페 모음');
      expect(state.groups.single.items.map((item) => item.id), [
        'entry-1',
        'entry-3',
      ]);
      expect(state.groups.single.bundleDate, DateTime(2026, 5, 27));
    },
  );

  test('buildGroupingState falls back when bundle metadata is missing', () {
    final transactions = [
      item(id: 'entry-1', bundleId: 'bundle-without-metadata'),
    ];

    final state = MainPaymentScreen.buildGroupingState(transactions, const []);

    expect(state.groupedIndexes, {0});
    expect(state.groups.single.id, 'bundle-without-metadata');
    expect(state.groups.single.name, '그룹1');
  });
}
