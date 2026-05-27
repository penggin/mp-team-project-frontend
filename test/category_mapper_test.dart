import 'package:flutter_test/flutter_test.dart';

import 'package:first/services/category_mapper.dart';

void main() {
  group('CategoryMapper', () {
    test('maps backend canonical categories to Korean display labels', () {
      expect(CategoryMapper.toDisplay('food'), '식비');
      expect(CategoryMapper.toDisplay('cafe'), '카페');
      expect(CategoryMapper.toDisplay('shopping'), '쇼핑');
      expect(CategoryMapper.toDisplay('transport'), '교통');
      expect(CategoryMapper.toDisplay('telecommunications'), '통신');
      expect(CategoryMapper.toDisplay('others'), '기타');
    });

    test('maps Korean display labels to backend canonical categories', () {
      expect(CategoryMapper.toApi('식비'), 'food');
      expect(CategoryMapper.toApi('카페'), 'cafe');
      expect(CategoryMapper.toApi('쇼핑'), 'shopping');
      expect(CategoryMapper.toApi('교통'), 'transport');
      expect(CategoryMapper.toApi('통신'), 'telecommunications');
      expect(CategoryMapper.toApi('기타'), 'others');
    });

    test('normalizes whitespace and unknown values to others', () {
      expect(CategoryMapper.toApi(' FOOD '), 'food');
      expect(CategoryMapper.toApi('문화생활'), 'others');
      expect(CategoryMapper.toDisplay('pet'), '기타');
      expect(CategoryMapper.toDisplay(''), '기타');
    });

    test('keeps income categories displayable for ledger history', () {
      expect(CategoryMapper.toDisplay('interest'), '이자');
      expect(CategoryMapper.toDisplay('salary'), '급여');
      expect(CategoryMapper.toDisplay('allowance'), '용돈');
      expect(CategoryMapper.toApi('급여'), 'salary');
    });

    test('exposes only backend-supported payment category options', () {
      expect(CategoryMapper.paymentCategoryOptions, [
        const PaymentCategoryOption(value: 'cafe', label: '카페'),
        const PaymentCategoryOption(value: 'food', label: '식비'),
        const PaymentCategoryOption(value: 'shopping', label: '쇼핑'),
        const PaymentCategoryOption(value: 'transport', label: '교통'),
        const PaymentCategoryOption(value: 'telecommunications', label: '통신'),
        const PaymentCategoryOption(value: 'others', label: '기타'),
      ]);
    });
  });
}
