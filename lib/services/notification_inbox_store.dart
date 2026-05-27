import 'package:shared_preferences/shared_preferences.dart';

class NotificationInboxStore {
  static const String _hiddenLedgerEntryKeys = 'hidden_notification_entry_keys';

  static Future<List<Map<String, dynamic>>> visibleLedgerEntries(
    List<Map<String, dynamic>> entries,
  ) async {
    final hiddenKeys = await _loadHiddenKeys();
    return entries.where((entry) {
      final key = keyForLedgerEntry(entry);
      return key == null || !hiddenKeys.contains(key);
    }).toList();
  }

  static Future<void> hideLedgerEntries(
    Iterable<Map<String, dynamic>> entries,
  ) {
    return hideNotificationKeys(entries.map(keyForLedgerEntry));
  }

  static Future<void> hideNotificationKeys(Iterable<String?> keys) async {
    final normalizedKeys = keys
        .whereType<String>()
        .where((key) => key.trim().isNotEmpty)
        .toSet();
    if (normalizedKeys.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final hiddenKeys =
        prefs.getStringList(_hiddenLedgerEntryKeys) ?? <String>[];
    final merged = {...hiddenKeys, ...normalizedKeys}.toList()..sort();
    await prefs.setStringList(_hiddenLedgerEntryKeys, merged);
  }

  static String? keyForLedgerEntry(Map<String, dynamic> entry) {
    final id = _normalized(entry['id']);
    if (id != null) return 'ledger:$id';

    final rawText = _normalized(entry['raw_text']);
    final transactionAt = _normalized(entry['transaction_at']);
    final amount = _normalized(entry['amount']);
    final merchantName = _normalized(entry['merchant_name']);
    final fallbackParts = [
      rawText,
      transactionAt,
      amount,
      merchantName,
    ].whereType<String>().toList();

    if (fallbackParts.isEmpty) return null;
    return 'ledger-fallback:${fallbackParts.join('|')}';
  }

  static Future<Set<String>> _loadHiddenKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_hiddenLedgerEntryKeys) ?? <String>[]).toSet();
  }

  static String? _normalized(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
