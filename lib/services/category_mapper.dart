class PaymentCategoryOption {
  final String value;
  final String label;

  const PaymentCategoryOption({required this.value, required this.label});

  @override
  bool operator ==(Object other) {
    return other is PaymentCategoryOption &&
        other.value == value &&
        other.label == label;
  }

  @override
  int get hashCode => Object.hash(value, label);
}

class BudgetCategoryLimit {
  final String category;
  final int monthlyLimit;

  const BudgetCategoryLimit({
    required this.category,
    required this.monthlyLimit,
  });

  Map<String, dynamic> toJson() {
    return {'category': category, 'monthly_limit': monthlyLimit};
  }
}

class CategoryMapper {
  static const String othersApi = 'others';
  static const String othersDisplay = '기타';
  static const String uncategorizedApi = othersApi;
  static const String uncategorizedDisplay = othersDisplay;

  static const List<PaymentCategoryOption> paymentCategoryOptions = [
    PaymentCategoryOption(value: 'cafe', label: '카페'),
    PaymentCategoryOption(value: 'food', label: '식비'),
    PaymentCategoryOption(value: 'shopping', label: '쇼핑'),
    PaymentCategoryOption(value: 'transport', label: '교통'),
    PaymentCategoryOption(value: 'telecommunications', label: '통신'),
    PaymentCategoryOption(value: othersApi, label: othersDisplay),
  ];

  static const List<String> paymentCategoryValues = [
    'cafe',
    'food',
    'shopping',
    'transport',
    'telecommunications',
    othersApi,
  ];

  static const List<BudgetCategoryLimit> defaultBudgetCategories = [
    BudgetCategoryLimit(category: 'food', monthlyLimit: 300000),
    BudgetCategoryLimit(category: 'cafe', monthlyLimit: 100000),
    BudgetCategoryLimit(category: 'shopping', monthlyLimit: 150000),
    BudgetCategoryLimit(category: 'transport', monthlyLimit: 100000),
  ];

  static const Map<String, String> _paymentApiToDisplay = {
    'cafe': '카페',
    'food': '식비',
    'shopping': '쇼핑',
    'transport': '교통',
    'telecommunications': '통신',
    othersApi: othersDisplay,
  };

  static const Map<String, String> _incomeApiToDisplay = {
    'interest': '이자',
    'salary': '급여',
    'allowance': '용돈',
  };

  static const Map<String, String> _displayToApi = {
    '카페': 'cafe',
    '식비': 'food',
    '쇼핑': 'shopping',
    '쇼핑, 여가': 'shopping',
    '교통': 'transport',
    '교통비': 'transport',
    '통신': 'telecommunications',
    othersDisplay: othersApi,
    '기타 결제': othersApi,
    '미분류': othersApi,
    '카테고리 없음': othersApi,
    '이자': 'interest',
    '급여': 'salary',
    '용돈': 'allowance',
  };

  static String toDisplay(String? value) {
    final normalized = _normalize(value);
    if (normalized == null) return othersDisplay;

    final lower = normalized.toLowerCase();
    final paymentDisplay = _paymentApiToDisplay[lower];
    if (paymentDisplay != null) return paymentDisplay;

    final incomeDisplay = _incomeApiToDisplay[lower];
    if (incomeDisplay != null) return incomeDisplay;

    final displayMappedApi = _displayToApi[normalized];
    if (displayMappedApi != null) return toDisplay(displayMappedApi);

    return othersDisplay;
  }

  static String toApi(String? value) {
    final normalized = _normalize(value);
    if (normalized == null) return othersApi;

    final lower = normalized.toLowerCase();
    if (_paymentApiToDisplay.containsKey(lower) ||
        _incomeApiToDisplay.containsKey(lower)) {
      return lower;
    }

    return _displayToApi[normalized] ?? othersApi;
  }

  static String normalizePaymentCategory(String? value) {
    final normalized = _normalize(value)?.toLowerCase();
    if (normalized == null) return othersApi;
    if (paymentCategoryValues.contains(normalized)) return normalized;
    final displayMappedApi = _displayToApi[_normalize(value)];
    if (displayMappedApi != null &&
        paymentCategoryValues.contains(displayMappedApi)) {
      return displayMappedApi;
    }
    return othersApi;
  }

  static String? _normalize(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
