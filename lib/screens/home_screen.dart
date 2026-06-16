import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'notification_screen.dart';
import 'evolution_screen.dart';
import 'app_drawer.dart';
import 'package:first/app_colors.dart';
import '../services/experience_service.dart';
import '../services/api_service.dart';
import 'budget_alert_dialog.dart';
import 'character_dialogs.dart';
import 'main_screen.dart';

// 레벨 + species (+ angry) → 캐릭터 에셋 매핑
String characterAsset(int level, {String? species, bool angry = false}) {
  final suffix = angry ? '_rage' : '';
  switch (species) {
    case 'horse':
      if (level >= 10) return 'assets/unicon$suffix.mp4';
      if (level >= 5)  return 'assets/horse$suffix.mp4';
      return 'assets/pony$suffix.mp4';
    case 'parrot':
      if (level >= 10) return 'assets/final_parrot$suffix.mp4';
      if (level >= 5)  return 'assets/parrot$suffix.mp4';
      return 'assets/green_parrot$suffix.mp4';
    case 'dolphin':
    default:
      if (level >= 10) return 'assets/killerwhale$suffix.mp4';
      if (level >= 5)  return 'assets/bluewhale$suffix.mp4';
      return 'assets/dolphin$suffix.mp4';
  }
}

bool _crossedEvolution(int prev, int curr) =>
    (prev < 5 && curr >= 5) || (prev < 10 && curr >= 10);

// ─── 숫자 포맷 정규식 — 파일 최상단에 한 번만 컴파일 ───────────────
final _amountRegex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  // ── 펫 상태 ──────────────────────────────────────────────────────
  int?    _level;
  double  _expProgress  = 0.0;
  int     _totalExp     = 0;
  String? _petName;
  String? _petSpecies;
  String  _petMood      = 'normal';
  String? _petLoadError;
  bool    _isLoadingPetState = true;
  bool    _evolutionPending  = false;
  bool    _isInteractingPet  = false;
  bool    _isDemoModeEnabled = false;

  // ── 예산 / 지출 ──────────────────────────────────────────────────
  int _todaySpend     = 0;
  int _monthlyBudget  = 0;
  int _monthlySpend   = 0;
  int _dailyBaseBudget = 0;
  int _carryover      = 0;

  // ── 통계 기반 멘트용 캐시 ────────────────────────────────────────
  String? _topCategory;
  int     _topCategoryAmount = 0;
  int     _prevMonthSpend    = 0;
  // 전월 데이터는 월이 바뀌기 전까지 재사용
  int?    _cachedPrevMonthKey;   // 캐시한 시점의 month 값 (이번 달 month)
  int     _cachedPrevMonthSpend = 0;

  // ── UI 상태 ──────────────────────────────────────────────────────
  String  _currentComment = '탭하면 말할게~';
  VideoPlayerController? _videoController;
  String? _currentAsset;

  // ── 분노 리액션 ──────────────────────────────────────────────────
  Timer? _angryTimer;
  bool   _showAngryAnim = false;
  static const Duration _angryReactionDuration = Duration(seconds: 5);

  // ── 중복 로딩 방지 (진행 중인 Future 저장) ───────────────────────
  Future<void>? _loadingFuture;

  final _dialogs = CharacterDialogs();

  // ── 미리 계산해 두는 파생 값 (build에서 재계산 방지) ───────────────
  String? _cachedCharacterLabel;
  String? _cachedPetSubtitle;
  String? _cachedPetTitle;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _isDemoModeEnabled = ExperienceService.demoModeEnabled.value;
    ExperienceService.demoModeEnabled.addListener(_onDemoModeChanged);
    ExperienceService.monthlyBudgetNotifier.addListener(_onBudgetChanged);
    ExperienceService.loadDemoMode();
    _loadAll();
  }

  @override
  void dispose() {
    ExperienceService.demoModeEnabled.removeListener(_onDemoModeChanged);
    ExperienceService.monthlyBudgetNotifier.removeListener(_onBudgetChanged);
    _angryTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  // ── 외부 진입점 (MainScreenState → 결제 감지) ──────────────────────
  Future<void> onPaymentReceived(int amount) async {
    // 기준금액과 데이터 갱신을 병렬로 처리
    final results = await Future.wait([
      ExperienceService.getBudgetAlertThreshold(),
      _loadAll(),
    ]);
    final threshold = results[0] as int;
    if (threshold <= 0 || amount < threshold || !mounted) return;
    BudgetAlertDialog.show(
      context,
      onGoToHistory: () {
        Navigator.of(context).popUntil((route) => route.isFirst);
        MainScreen.globalKey.currentState?.changeTab(1);
      },
      onWasteful: _triggerAngryReaction,
    );
  }

  // ── 이벤트 핸들러 ─────────────────────────────────────────────────
  void _onDemoModeChanged() {
    if (!mounted) return;
    setState(() => _isDemoModeEnabled = ExperienceService.demoModeEnabled.value);
  }

  void _onBudgetChanged() {
    if (mounted) _loadAll();
  }

  // ── 상태 게터 ──────────────────────────────────────────────────────
  bool get _isAngry => _showAngryAnim;

  bool get _isOverBudget {
    if (_petMood == 'angry') return true;
    final total = _dailyBaseBudget + _carryover;
    return total > 0 && _todaySpend > total;
  }

  // ── 데이터 로드 ────────────────────────────────────────────────────
  Future<void> _loadAll() {
    // 이미 로딩 중이면 그 Future를 그대로 반환 (중복 호출 방지)
    _loadingFuture ??= _doLoadAll().whenComplete(() => _loadingFuture = null);
    return _loadingFuture!;
  }

  Future<void> _doLoadAll() async {

    if (mounted) setState(() { _isLoadingPetState = true; _petLoadError = null; });

    final now = DateTime.now();

    // ① 이번 달 + 펫 + 예산 + 전월 — 모두 동시에 병렬 시작
    //    전월은 캐시가 있어도 일단 같이 쏜다 (캐시 있으면 결과를 버림)
    final prevMonth = DateTime(now.year, now.month - 1);
    final needPrevFetch = _cachedPrevMonthKey != now.month;

    final futures = [
      ApiService.getPetState(),
      ApiService.getLedgerEntries(year: now.year, month: now.month),
      ApiService.getMonthlyBudget(year: now.year, month: now.month),
      if (needPrevFetch)
        ApiService.getLedgerEntries(year: prevMonth.year, month: prevMonth.month),
    ];

    final results = await Future.wait(futures);

    final petState   = results[0] as Map<String, dynamic>?;
    final entries    = results[1] as List<Map<String, dynamic>>;
    final budgetData = results[2] as Map<String, dynamic>?;
    final prevEntries = needPrevFetch
        ? results[3] as List<Map<String, dynamic>>
        : null;

    // ② 가계부 항목을 한 번만 순회해서 지출/통계 동시 집계
    int todaySpend   = 0;
    int monthlySpend = 0;
    final Map<String, int> categoryTotals = {};

    for (final entry in entries) {
      if ((entry['type'] as String? ?? '') != 'expense') continue;
      final amount = (entry['amount'] as num?)?.toInt() ?? 0;
      final cat    = entry['category']?.toString() ?? 'others';

      // 월간 지출
      monthlySpend += amount;

      // 오늘 지출
      final txAtStr = (entry['transaction_at'] as String? ??
              entry['created_at'] as String? ?? '').trim();
      if (txAtStr.isNotEmpty) {
        try {
          if (DateTime.parse(txAtStr).toLocal().day == now.day) {
            todaySpend += amount;
          }
        } catch (_) {}
      }

      // 카테고리 집계
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amount;
    }

    // 최다 지출 카테고리
    String? topCat;
    int topAmt = 0;
    for (final e in categoryTotals.entries) {
      if (e.value > topAmt) { topAmt = e.value; topCat = e.key; }
    }

    // ③ 전월 지출 — 이미 위에서 병렬로 받아뒀거나 캐시 사용
    int prevMonthSpend;
    if (!needPrevFetch) {
      prevMonthSpend = _cachedPrevMonthSpend;
    } else {
      prevMonthSpend = 0;
      for (final e in prevEntries!) {
        if ((e['type'] as String? ?? '') != 'expense') continue;
        prevMonthSpend += (e['amount'] as num?)?.toInt() ?? 0;
      }
      _cachedPrevMonthKey   = now.month;
      _cachedPrevMonthSpend = prevMonthSpend;
    }

    // ④ SharedPreferences 4개 병렬 읽기
    final sprefs = await Future.wait([
      ExperienceService.getMonthlyBudget(),
      ExperienceService.getDailyBaseBudget(),
      ExperienceService.getCarryoverAmount(),
    ]);
    final localBudget = sprefs[0] as int;
    final dailyBase   = sprefs[1] as int;
    final carryover   = sprefs[2] as int;

    // ⑤ 예산 확정 + 오늘 지출 기록 (병렬)
    final budgetConfigured = budgetData?['is_configured'] as bool? ?? false;
    final serverBudget = budgetConfigured
        ? ((budgetData?['monthly_limit'] as num?)?.toInt() ?? 0) : 0;
    final monthlyBudget = serverBudget > 0 ? serverBudget : localBudget;

    await Future.wait([
      ExperienceService.recordTodaySpend(todaySpend),
      if (serverBudget > 0) ExperienceService.setMonthlyBudget(serverBudget),
    ]);

    // ⑥ 펫 레벨 / 진화 판단
    final newLevel    = petState == null ? null : _validLevel(petState['level']);
    final totalExp    = petState == null ? null : max(0, _intValue(petState['exp']) ?? 0);
    final prevLevel   = _level;
    final shouldEvolve =
        prevLevel != null && newLevel != null &&
        _crossedEvolution(prevLevel, newLevel) && !_evolutionPending;
    final petMood = (petState?['mood']?.toString() == 'angry') ? 'angry' : 'normal';

    _loadingFuture = null;  // Future 참조 해제
    if (!mounted) return;

    setState(() {
      _todaySpend      = todaySpend;
      _monthlyBudget   = monthlyBudget;
      _monthlySpend    = monthlySpend;
      _dailyBaseBudget = dailyBase;
      _carryover       = carryover;
      _topCategory        = topCat;
      _topCategoryAmount  = topAmt;
      _prevMonthSpend     = prevMonthSpend;
      _isLoadingPetState  = false;

      if (petState == null || newLevel == null) {
        _petLoadError = '펫 상태를 불러오지 못했어요';
        if (_level == null) { _totalExp = 0; _expProgress = 0.0; }
        _invalidateLabelCache();
        return;
      }

      _petLoadError = null;
      _level        = newLevel;
      _totalExp     = totalExp ?? 0;
      _expProgress  = ExperienceService.expProgress(_totalExp);
      _petName      = _stringValue(petState['name']);
      _petSpecies   = _stringValue(petState['species']);
      _petMood      = petMood;
      if (shouldEvolve) _evolutionPending = true;

      // 파생 레이블 갱신
      _invalidateLabelCache();
    });

    if (newLevel == null) return;
    if (shouldEvolve) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _triggerEvolution());
      return;
    }
    _refreshCharacterIfNeeded(newLevel);
  }

  // ── 레이블 캐시 무효화 (setState 내부에서 호출) ─────────────────────
  void _invalidateLabelCache() {
    _cachedCharacterLabel = _level == null ? null : _characterLabel(_level!);
    _cachedPetTitle = _petName ?? _cachedCharacterLabel ?? '펫 상태 확인 중';
    final speciesLabel = _petSpecies == null ? null : _petSpeciesLabel(_petSpecies!);
    if (_level == null) {
      _cachedPetSubtitle = null;
    } else if (_petSpecies == null) {
      _cachedPetSubtitle = _cachedCharacterLabel;
    } else if (speciesLabel == null) {
      _cachedPetSubtitle = null;
    } else {
      _cachedPetSubtitle = '$_cachedCharacterLabel · $speciesLabel';
    }
  }

  // ── 캐릭터 영상 ────────────────────────────────────────────────────
  void _initVideoController(int level) {
    final asset = characterAsset(level, species: _petSpecies, angry: _isAngry);
    final controller = VideoPlayerController.asset(asset);
    _videoController = controller;
    _currentAsset    = asset;
    controller.initialize().then((_) {
      if (!mounted || _videoController != controller) return;
      setState(() {});
      controller
        ..setLooping(true)
        ..setVolume(0.0)
        ..play();
    });
  }

  void _refreshCharacterIfNeeded(int newLevel) {
    final needed = characterAsset(newLevel, species: _petSpecies, angry: _isAngry);
    if (_currentAsset == needed) return;
    _videoController?.dispose();
    _initVideoController(newLevel);
  }

  // ── 분노 리액션 ────────────────────────────────────────────────────
  void _triggerAngryReaction() {
    final level = _level;
    if (!mounted || level == null) return;
    _angryTimer?.cancel();
    setState(() {
      _showAngryAnim  = true;
      _currentComment = _pickAngryComment();
    });
    _refreshCharacterIfNeeded(level);
    _angryTimer = Timer(_angryReactionDuration, () {
      if (!mounted) return;
      setState(() => _showAngryAnim = false);
      final lvl = _level;
      if (lvl != null) _refreshCharacterIfNeeded(lvl);
    });
  }

  // ── 펫 상호작용 ────────────────────────────────────────────────────
  Future<void> _playWithPet() async {
    if (_isInteractingPet || _level == null) return;
    setState(() => _isInteractingPet = true);
    try {
      await _interactWithPet('play',
          successComment: _dialogs.playComment(species: _petSpecies));
    } finally {
      if (mounted) setState(() => _isInteractingPet = false);
    }
  }

  Future<void> _interactWithPet(String action,
      {required String successComment}) async {
    final petState = await ApiService.interactWithPet(action);
    if (!mounted) return;
    if (petState == null) {
      setState(() => _petLoadError = '펫 상태를 갱신하지 못했어요');
      return;
    }
    _applyPetState(petState, successComment: successComment);
  }

  void _applyPetState(Map<String, dynamic> petState, {String? successComment}) {
    final newLevel = _validLevel(petState['level']);
    if (newLevel == null) {
      setState(() => _petLoadError = '펫 상태를 불러오지 못했어요');
      return;
    }

    final prevLevel  = _level;
    final totalExp   = max(0, _intValue(petState['exp']) ?? 0);
    final shouldEvo  = prevLevel != null &&
        _crossedEvolution(prevLevel, newLevel) && !_evolutionPending;
    final moodRaw    = petState['mood']?.toString() ?? 'normal';

    setState(() {
      _petLoadError    = null;
      _isLoadingPetState = false;
      _level           = newLevel;
      _totalExp        = totalExp;
      _expProgress     = ExperienceService.expProgress(totalExp);
      _petName         = _stringValue(petState['name']);
      _petSpecies      = _stringValue(petState['species']);
      _petMood         = moodRaw == 'angry' ? 'angry' : 'normal';
      if (successComment != null) _currentComment = successComment;
      if (shouldEvo) _evolutionPending = true;
      _invalidateLabelCache();
    });

    if (shouldEvo) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _triggerEvolution());
    } else {
      _refreshCharacterIfNeeded(newLevel);
    }
  }

  // ── 진화 ───────────────────────────────────────────────────────────
  void _triggerEvolution() {
    final level = _level;
    if (!mounted || level == null) return;
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, animation, _) => FadeTransition(
        opacity: animation,
        child: EvolutionScreen(
          newCharacterAsset: characterAsset(level, species: _petSpecies),
          newLevel: level,
          species: _petSpecies,
          onComplete: () {
            if (!mounted) return;
            setState(() => _evolutionPending = false);
            _videoController?.dispose();
            _initVideoController(level);
          },
        ),
      ),
    ));
  }

  // ── 권한 요청 ──────────────────────────────────────────────────────
  Future<void> _requestPermissions() async {
    try {
      final granted = await NotificationListenerService.isPermissionGranted();
      if (!granted) await NotificationListenerService.requestPermission();
    } catch (e) {
      debugPrint('권한 요청 에러: $e');
    }
  }

  // ── 헬퍼 ───────────────────────────────────────────────────────────
  int? _validLevel(Object? value) {
    final level = _intValue(value);
    return (level == null || level < 1) ? null : level;
  }

  int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String? _stringValue(Object? value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  String _formatAmount(int amount) =>
      amount.toString().replaceAllMapped(_amountRegex, (m) => '${m[1]},');

  // ── 대사 ───────────────────────────────────────────────────────────
  // 대사 내용 수정은 character_dialogs.dart 에서 하세요.

  String _pickAngryComment() => _dialogs.randomAngryComment(
        species: _petSpecies,       level: _level ?? 1,
        topCategory: _topCategory,  topCategoryAmount: _topCategoryAmount,
        prevMonthSpend: _prevMonthSpend,
        monthlySpend: _monthlySpend, monthlyBudget: _monthlyBudget,
      );

  Future<void> _generateRandomComment() async {
    // 먼저 댓글 선택 후 한 번에 setState
    final comment = _isOverBudget
        ? _dialogs.randomAngryComment(
            species: _petSpecies,       level: _level ?? 1,
            topCategory: _topCategory,  topCategoryAmount: _topCategoryAmount,
            prevMonthSpend: _prevMonthSpend,
            monthlySpend: _monthlySpend, monthlyBudget: _monthlyBudget,
          )
        : _dialogs.randomNormalComment(
            species: _petSpecies,       level: _level ?? 1,
            topCategory: _topCategory,  topCategoryAmount: _topCategoryAmount,
            prevMonthSpend: _prevMonthSpend,
            monthlySpend: _monthlySpend, monthlyBudget: _monthlyBudget,
          );

    if (_level == null || _isInteractingPet) {
      setState(() => _currentComment = comment);
      return;
    }

    // 댓글 세팅 + interacting 플래그를 한 번에 처리
    setState(() { _currentComment = comment; _isInteractingPet = true; });
    try {
      await _interactWithPet('pet', successComment: comment);
    } finally {
      if (mounted) setState(() => _isInteractingPet = false);
    }
  }

  // ── 레이블 ─────────────────────────────────────────────────────────
  String _characterLabel(int level) {
    switch (_petSpecies) {
      case 'horse':
        if (level >= 10) return '유니콘';
        if (level >= 5)  return '말';
        return '조랑말';
      case 'parrot':
        if (level >= 10) return '파이널 앵무새';
        if (level >= 5)  return '앵무새';
        return '초록 앵무새';
      default:
        if (level >= 10) return '범고래';
        if (level >= 5)  return '파란 고래';
        return '돌고래';
    }
  }

  String? _petSpeciesLabel(String species) {
    switch (species) {
      case 'horse':   return '말';
      case 'parrot':  return '앵무새';
      case 'dolphin': return '돌고래';
      default:        return null;
    }
  }

  // ── UI 빌더 ────────────────────────────────────────────────────────
  List<Widget> _buildDailyBudgetBar(ThemeColors colors) {
    final total    = _dailyBaseBudget + _carryover;
    final isOver   = _todaySpend > total;
    final progress = total > 0 ? (_todaySpend / total).clamp(0.0, 1.0) : 0.0;
    return [
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress, minHeight: 6,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                  isOver ? Colors.red : colors.primaryText),
            ),
          ),
        ),
        if (isOver) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('초과',
                style: TextStyle(color: Colors.red, fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ]),
    ];
  }

  Widget _buildPetMoodChip(bool isAngry, ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isAngry ? Colors.red.withValues(alpha: 0.12) : colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isAngry ? Icons.mood_bad : Icons.mood,
            size: 14, color: isAngry ? Colors.red : colors.primaryText),
        const SizedBox(width: 4),
        Text(isAngry ? '화남' : '평온',
            style: TextStyle(
                color: isAngry ? Colors.red : colors.primaryText,
                fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors          = context.watch<ThemeProvider>().colors;
    final level           = _level;
    final hasPetState     = level != null;
    final videoController = _videoController;
    final remainingBudget = _monthlyBudget > 0
        ? _monthlyBudget - _monthlySpend : null;
    final isOverBudget    = _isOverBudget;

    return Scaffold(
      backgroundColor: colors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu, color: colors.primaryText, size: 32),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none, color: colors.primaryText, size: 32),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationScreen()))
              .then((_) => _loadAll()),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),

              // ── 상태 카드 ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: colors.cardBackground,
                    borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 레벨 + 이름
                    Row(children: [
                      Text(hasPetState ? 'LV : $level' : 'LV : --',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.primaryText)),
                      const SizedBox(width: 8),
                      Text(_cachedPetTitle ?? '펫 상태 확인 중',
                          style: TextStyle(fontSize: 13, color: colors.subText)),
                    ]),
                    if (_cachedPetSubtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(_cachedPetSubtitle!,
                          style: TextStyle(fontSize: 12, color: colors.subText)),
                    ],
                    const SizedBox(height: 10),
                    // EXP 바
                    Row(children: [
                      Text('EXP',
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colors.primaryText)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: _expProgress, minHeight: 10,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                colors.primaryText),
                          ),
                        ),
                      ),
                    ]),
                    // 데모 버튼
                    if (_isDemoModeEnabled) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8, runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isLoadingPetState ? null : _loadAll,
                              icon: const Icon(Icons.sync, size: 18),
                              label: Text(_isLoadingPetState ? '동기화 중...' : '상태 동기화'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.primaryText,
                                side: BorderSide(color: colors.primaryText),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _isInteractingPet || !hasPetState
                                  ? null : _playWithPet,
                              icon: const Icon(Icons.favorite, size: 18),
                              label: Text(_isInteractingPet ? '반영 중...' : '놀아주기'),
                              style: FilledButton.styleFrom(
                                backgroundColor: colors.primaryText,
                                foregroundColor: colors.background,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // 에러
                    if (_petLoadError != null) ...[
                      Text(_petLoadError!,
                          style: TextStyle(fontSize: 12, color: colors.subText)),
                      const SizedBox(height: 12),
                    ],
                    // 무드 칩
                    if (hasPetState) ...[
                      _buildPetMoodChip(isOverBudget, colors),
                      const SizedBox(height: 20),
                    ],
                    // 오늘 소비 / 남은 예산
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatColumn('오늘의 소비',
                            '${_formatAmount(_todaySpend)}원', colors),
                        _buildStatColumn(
                          '남은 예산',
                          remainingBudget != null
                              ? '${_formatAmount(remainingBudget)}원'
                              : '예산 미설정',
                          colors,
                          valueColor: remainingBudget != null && remainingBudget < 0
                              ? Colors.red : colors.primaryText,
                        ),
                      ],
                    ),
                    // 일일 예산 바
                    if (_dailyBaseBudget > 0) ..._buildDailyBudgetBar(colors),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── 캐릭터 영상 ────────────────────────────────────────
              Expanded(
                flex: 5,
                child: GestureDetector(
                  onTap: _generateRandomComment,
                  child: Container(
                    decoration: BoxDecoration(
                        color: colors.cardBackground,
                        borderRadius: BorderRadius.circular(20)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Center(
                        child: videoController != null &&
                                videoController.value.isInitialized
                            ? AspectRatio(
                                aspectRatio: videoController.value.aspectRatio,
                                child: VideoPlayer(videoController))
                            : _isLoadingPetState
                                ? CircularProgressIndicator(color: colors.primaryText)
                                : Icon(Icons.pets, color: colors.primaryText, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── 멘트 카드 ──────────────────────────────────────────
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(20)),
                  child: Center(
                    child: Text(_currentComment,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16,
                            color: colors.primaryText, height: 1.5)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 레이블 + 값으로 구성된 열 위젯 (build 중복 제거)
  Widget _buildStatColumn(String label, String value, ThemeColors colors,
      {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: colors.subText)),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold,
                color: valueColor ?? colors.primaryText)),
      ],
    );
  }
}
