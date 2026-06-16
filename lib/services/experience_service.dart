import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExperienceService {
  static const String _keyTotalExp = 'xp_total';
  static const String _keyLastSaveMs = 'xp_last_save_ms';
  static const String _keyMonthlyBudget = 'xp_monthly_budget';
  static const String _keyPenaltyDay = 'xp_penalty_day';
  static const String _keyPenalizedAmount = 'xp_penalized_amount';
  // 일일 예산 이월 관련 키
  static const String _keyCarryoverDate = 'budget_carryover_date';
  static const String _keyCarryoverAmount = 'budget_carryover_amount';
  static const String _keyTodaySpendDate = 'budget_today_spend_date';
  static const String _keyTodaySpendAmount = 'budget_today_spend_amount';
  static const String _keyDemoModeEnabled = 'demo_mode_enabled';
  static const String _keyLastLevel = 'xp_last_level';
  // 과소비 알림창 — 오늘 이미 표시했으면 다시 띄우지 않음
  static const String _keyBudgetAlertDate = 'budget_alert_shown_date';
  // 과소비 알림 기준금액 (SharedPreferences 저장, 기본값 30,000원)
  static const String _keyBudgetAlertThreshold = 'budget_alert_threshold';

  static final ValueNotifier<bool> demoModeEnabled = ValueNotifier(false);
  static final ValueNotifier<int> monthlyBudgetNotifier = ValueNotifier(0);

  static const int expPerSecond = 7;
  static const int expPerMinute = 1;
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

  static Future<int> getLastLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLastLevel) ?? 1;
  }

  static Future<void> saveLastLevel(int level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastLevel, level);
  }

  static Future<int> getMonthlyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyMonthlyBudget) ?? 0;
  }

  static Future<void> setMonthlyBudget(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMonthlyBudget, amount);
    monthlyBudgetNotifier.value = amount;
  }

  /// 하루 기본 예산 = 월 예산 / 30
  static Future<int> getDailyBaseBudget() async {
    final monthly = await getMonthlyBudget();
    if (monthly <= 0) return 0;
    return monthly ~/ 30;
  }

  /// 오늘 날짜 키 (yyyy-MM-dd)
  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 전날 미사용 금액을 이월로 저장 (자정 이후 첫 호출 시 자동 처리)
  /// 반환값: 오늘 사용 가능한 이월 금액
  static Future<int> getCarryoverAmount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayStr();
    final savedDate = prefs.getString(_keyCarryoverDate) ?? '';

    // 이미 오늘 이월 처리됨 → 그대로 반환
    if (savedDate == today) {
      return prefs.getInt(_keyCarryoverAmount) ?? 0;
    }

    // 새 날 → 전날 미사용 금액을 이월로 계산
    final yesterday = _yesterdayStr();
    final spendDate = prefs.getString(_keyTodaySpendDate) ?? '';
    final dailyBase = await getDailyBaseBudget();
    int carryover = 0;

    if (spendDate == yesterday) {
      // 전날 지출이 기록된 경우
      final yesterdaySpend = prefs.getInt(_keyTodaySpendAmount) ?? 0;
      final unused = dailyBase - yesterdaySpend;
      carryover = unused > 0 ? unused : 0;
    }
    // 전날 기록이 없으면 이월 없음 (carryover = 0)

    await prefs.setString(_keyCarryoverDate, today);
    await prefs.setInt(_keyCarryoverAmount, carryover);
    return carryover;
  }

  /// 오늘 지출 금액 기록 (결제 감지 시마다 갱신)
  static Future<void> recordTodaySpend(int totalTodaySpend) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTodaySpendDate, _todayStr());
    await prefs.setInt(_keyTodaySpendAmount, totalTodaySpend);
  }

  /// 오늘 기록된 지출 금액 읽기 (오늘 날짜가 아니면 0 반환)
  static Future<int> getTodayRecordedSpend() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayStr();
    final savedDate = prefs.getString(_keyTodaySpendDate) ?? '';
    if (savedDate != today) return 0;
    return prefs.getInt(_keyTodaySpendAmount) ?? 0;
  }

  /// 오늘 사용 가능한 총 예산 = 일 기본 예산 + 이월
  static Future<int> getTodayTotalBudget() async {
    final base = await getDailyBaseBudget();
    final carryover = await getCarryoverAmount();
    return base + carryover;
  }

  /// 과소비 알림 기준금액 조회 (0 이하면 알림 비활성화)
  static Future<int> getBudgetAlertThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    // 기본값 30,000원
    return prefs.getInt(_keyBudgetAlertThreshold) ?? 30000;
  }

  /// 과소비 알림 기준금액 저장
  static Future<void> setBudgetAlertThreshold(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBudgetAlertThreshold, amount);
  }

  /// 오늘 과소비 알림창을 이미 표시했는지 확인
  static Future<bool> isBudgetAlertShownToday() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_keyBudgetAlertDate) ?? '') == _todayStr();
  }

  /// 오늘 과소비 알림창을 표시했음으로 기록
  static Future<void> markBudgetAlertShownToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBudgetAlertDate, _todayStr());
  }

  /// 하루 예산을 초과했는지 확인
  /// 반환: 초과 여부 (true면 알림창 표시 필요)
  static Future<bool> checkDailyBudgetExceeded(int todaySpend) async {
    final totalBudget = await getTodayTotalBudget();
    if (totalBudget <= 0) return false;
    return todaySpend > totalBudget;
  }

  static String _yesterdayStr() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }

  static Future<bool> loadDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyDemoModeEnabled) ?? false;
    demoModeEnabled.value = enabled;
    return enabled;
  }

  static Future<void> setDemoModeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDemoModeEnabled, enabled);
    demoModeEnabled.value = enabled;
  }

  static Future<int> addDemoExp([int amount = xpPerLevel]) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyTotalExp) ?? 0;
    final updated = (current + amount).clamp(0, 999999999);
    await prefs.setInt(_keyTotalExp, updated);
    await prefs.setInt(_keyLastSaveMs, DateTime.now().millisecondsSinceEpoch);
    return updated;
  }

  static Future<int> resetExp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalExp, 0);
    await prefs.setInt(_keyLastSaveMs, DateTime.now().millisecondsSinceEpoch);
    return 0;
  }

  /// 지정한 XP를 즉시 지급.
  static Future<void> addExp(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyTotalExp) ?? 0;
    await prefs.setInt(_keyTotalExp, (current + amount).clamp(0, 999999999));
  }

  /// 마지막 저장 이후 경과 분만큼 XP 지급.
  /// 최대 24시간(1440분) 치만 인정하여 오랫동안 앱을 안 켰을 때 레벨이 폭등하는 현상 방지.
  static Future<int> addTimeBasedExp() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = prefs.getInt(_keyLastSaveMs);

    // 최초 실행이면 타임스탬프만 저장하고 XP는 지급하지 않음
    if (last == null) {
      await prefs.setInt(_keyLastSaveMs, now);
      return 0;
    }

    final diffMinutes = ((now - last) / 60000).floor();
    // 최대 24시간(1440분) 치만 인정
    final cappedMinutes = diffMinutes.clamp(0, 1440);
    final earned = cappedMinutes * expPerMinute;

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
