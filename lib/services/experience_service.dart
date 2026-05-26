import 'package:shared_preferences/shared_preferences.dart';

class ExperienceService {
  static const String _keyTotalExp = 'xp_total';
  static const String _keyLastSaveMs = 'xp_last_save_ms';
  static const String _keyMonthlyBudget = 'xp_monthly_budget';
  static const String _keyPenaltyDay = 'xp_penalty_day';
  static const String _keyPenalizedAmount = 'xp_penalized_amount';

  static const int expPerMinute = 100;
  static const int xpPerLevel = 100;
  static const int penaltyPer1000Won = 5;

  // 레벨 1은 0~99 XP, 레벨 2는 100~199 XP, ...
  static int levelFromExp(int totalExp) => (totalExp ~/ xpPerLevel) + 1;
  static double expProgress(int totalExp) =>
      (totalExp % xpPerLevel) / xpPerLevel.toDouble();

  static Future<int> getTotalExp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTotalExp) ?? 0;
  }

  static Future<int> getMonthlyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyMonthlyBudget) ?? 0;
  }

  static Future<void> setMonthlyBudget(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMonthlyBudget, amount);
  }

  /// 앱 재진입 시 호출. 마지막 저장 이후 경과 시간만큼 XP 일괄 지급.
  static Future<int> addTimeBasedExp() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = prefs.getInt(_keyLastSaveMs) ?? now;

    final diffMinutes = ((now - last) / 60000).floor();
    final earned = diffMinutes * expPerMinute;

    if (earned > 0) {
      final current = prefs.getInt(_keyTotalExp) ?? 0;
      await prefs.setInt(_keyTotalExp, current + earned);
    }
    await prefs.setInt(_keyLastSaveMs, now);
    return earned;
  }

  /// 오늘 지출이 일일 예산(월 예산 / 30)을 초과하면 초과분에 패널티 적용.
  /// 같은 날 이미 패널티를 부과한 금액 이상으로 추가 초과될 때만 추가 패널티.
  /// 반환값: 이번에 깎인 XP (0이면 패널티 없음)
  static Future<int> applyDailyPenalty(int todaySpend) async {
    final prefs = await SharedPreferences.getInstance();
    final monthlyBudget = prefs.getInt(_keyMonthlyBudget) ?? 0;
    if (monthlyBudget <= 0) return 0;

    final dailyBudget = monthlyBudget ~/ 30;
    if (todaySpend <= dailyBudget) return 0;

    final today = _todayKey();
    final penaltyDay = prefs.getString(_keyPenaltyDay) ?? '';
    // 오늘 이미 패널티를 적용한 지출 기준점. 새 날이면 dailyBudget부터 시작.
    final baseline = penaltyDay == today
        ? (prefs.getInt(_keyPenalizedAmount) ?? dailyBudget)
        : dailyBudget;

    final newOverage = todaySpend - baseline;
    if (newOverage <= 0) return 0;

    final penalty = (newOverage ~/ 1000) * penaltyPer1000Won;
    if (penalty <= 0) return 0;

    final current = prefs.getInt(_keyTotalExp) ?? 0;
    await prefs.setInt(_keyTotalExp, (current - penalty).clamp(0, 999999999));
    await prefs.setString(_keyPenaltyDay, today);
    await prefs.setInt(_keyPenalizedAmount, todaySpend);

    return penalty;
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
