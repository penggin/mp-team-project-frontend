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
import '../services/location_service.dart';
import 'budget_alert_dialog.dart';
import 'main_screen.dart';

// 레벨 + species → 캐릭터 에셋 매핑
String characterAsset(int level, {String? species}) {
  switch (species) {
    case 'horse':
      if (level >= 10) return 'assets/unicon.mp4';
      if (level >= 5) return 'assets/horse.mp4';
      return 'assets/pony.mp4';
    case 'parrot':
      if (level >= 10) return 'assets/final_parrot.mp4';
      if (level >= 5) return 'assets/parrot.mp4';
      return 'assets/green_parrot.mp4';
    case 'dolphin':
    default:
      if (level >= 10) return 'assets/killerwhale.mp4';
      if (level >= 5) return 'assets/bluewhale.mp4';
      return 'assets/dolphin.mp4';
  }
}

// 진화가 필요한 레벨 임계값
bool _crossedEvolution(int prev, int curr) {
  return (prev < 5 && curr >= 5) || (prev < 10 && curr >= 10);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _level = 1;
  int _prevLevel = 1;
  double _expProgress = 0.0;
  int _todaySpend = 0;
  int _monthlyBudget = 0;
  int _monthlySpend = 0;
  int _totalExp = 0;
  bool _evolutionPending = false;
  bool _usesBackendPetState = false;
  bool _isDemoModeEnabled = false;
  bool _isAddingDemoExp = false;
  bool _isResettingDemoExp = false;
  String? _petName;
  String? _petSpecies;
  // mood: 'normal' | 'angry' 문자열 (백엔드 패치 후 int → String)
  String _petMood = 'normal';
  // health, cleanliness, coins는 팀 API에서 삭제됨

  // 일일 예산 관련
  int _dailyBaseBudget = 0;
  int _carryover = 0;
  bool _budgetAlertShown = false; // 같은 날 중복 표시 방지

  Timer? _xpTimer;
  bool _ticking = false;

  final List<String> _comments = [
    "저 너무 배가 불러요!!",
    "이곳저곳 많이 다녔어요!",
    "내 또래에 비해 식비에 10만원 더 사용했어요",
    "오늘은 절약의 날! 잘하고 있어요.",
    "조금만 더 모으면 다음 레벨이에요!",
  ];

  String _currentComment = "캐릭터를 클릭하면 멘트가 나와요!";
  late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _isDemoModeEnabled = ExperienceService.demoModeEnabled.value;
    ExperienceService.demoModeEnabled.addListener(_onDemoModeChanged);
    ExperienceService.monthlyBudgetNotifier.addListener(_onBudgetChanged);
    ExperienceService.loadDemoMode();
    _loadAll().then((usesBackendPetState) {
      if (mounted && !usesBackendPetState) _startXpTimer();
    });
    // _initVideoController는 _loadAll 내부에서 species 확인 후 호출하므로
    // 여기선 기본값(dolphin)으로 먼저 초기화해 두고 _loadAll 완료 시 교체됨
    _initVideoController(_level);
  }

  Future<void> _checkAndShowBudgetAlert() async {
    if (_budgetAlertShown) return;
    final exceeded = await ExperienceService.checkDailyBudgetExceeded(
      _todaySpend,
    );
    if (!exceeded || !mounted) return;
    _budgetAlertShown = true;
    BudgetAlertDialog.show(
      context,
      onGoToHistory: () {
        // 전체 결제 내역: 가계부 탭(1번째)으로 이동
        Navigator.of(context).popUntil((route) => route.isFirst);
        MainScreen.globalKey.currentState?.changeTab(1);
      },
    );
  }

  @override
  void dispose() {
    _xpTimer?.cancel();
    ExperienceService.demoModeEnabled.removeListener(_onDemoModeChanged);
    ExperienceService.monthlyBudgetNotifier.removeListener(_onBudgetChanged);
    _videoController.dispose();
    super.dispose();
  }

  void _onDemoModeChanged() {
    if (!mounted) return;
    setState(() {
      _isDemoModeEnabled = ExperienceService.demoModeEnabled.value;
    });
  }

  void _onBudgetChanged() {
    if (!mounted) return;
    _loadAll();
  }

  // ── 실시간 XP 타이머 ──────────────────────────────────────────

  void _startXpTimer() {
    if (_usesBackendPetState) return;
    _xpTimer?.cancel();
    _xpTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickXp());
  }

  Future<void> _tickXp() async {
    if (_usesBackendPetState) return;
    if (_ticking || !mounted) return;
    _ticking = true;
    try {
      await ExperienceService.addTimeBasedExp();
      await ExperienceService.applyDailyPenalty(_todaySpend);
      final totalExp = await ExperienceService.getTotalExp();
      final monthlyBudget = await ExperienceService.getMonthlyBudget();
      final newLevel = ExperienceService.levelFromExp(totalExp);

      if (!mounted) return;

      final shouldEvolve =
          _crossedEvolution(_level, newLevel) && !_evolutionPending;

      setState(() {
        _prevLevel = _level;
        _level = newLevel;
        _totalExp = totalExp;
        _expProgress = ExperienceService.expProgress(totalExp);
        _monthlyBudget = monthlyBudget;
        if (shouldEvolve) _evolutionPending = true;
      });

      if (shouldEvolve) {
        _xpTimer?.cancel(); // 진화 중 타이머 일시 정지
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _triggerEvolution(),
        );
      }
    } finally {
      _ticking = false;
    }
  }

  // ─────────────────────────────────────────────────────────────

  void _initVideoController(int level) {
    _videoController = VideoPlayerController.asset(
        characterAsset(level, species: _petSpecies))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _videoController.setLooping(true);
        _videoController.setVolume(0.0);
        _videoController.play();
      });
  }

  Future<bool> _loadAll() async {
    final now = DateTime.now();

    // 펫 상태 + 가계부 내역(이번 달) + 월간 예산을 병렬 호출
    final results = await Future.wait([
      ApiService.getPetState(),
      ApiService.getLedgerEntries(year: now.year, month: now.month),
      ApiService.getMonthlyBudget(year: now.year, month: now.month),
    ]);

    final petState = results[0] as Map<String, dynamic>?;
    final entries = results[1] as List<Map<String, dynamic>>;
    final budgetData = results[2] as Map<String, dynamic>?;

    final usesBackendPetState = petState != null;
    if (!usesBackendPetState) {
      await ExperienceService.addTimeBasedExp();
    }

    int todaySpend = 0;
    int monthlySpend = 0;

    for (final entry in entries) {
      if ((entry['type'] as String? ?? '') != 'expense') continue;
      final amount = (entry['amount'] as num?)?.toInt() ?? 0;
      final txAtStr =
          (entry['transaction_at'] as String? ??
                  entry['created_at'] as String? ??
                  '')
              .trim();
      if (txAtStr.isEmpty) continue;
      try {
        final txAt = DateTime.parse(txAtStr).toLocal();
        monthlySpend += amount;
        if (txAt.day == now.day) todaySpend += amount;
      } catch (_) {}
    }

    await ExperienceService.recordTodaySpend(todaySpend);
    if (!usesBackendPetState) {
      await ExperienceService.applyDailyPenalty(todaySpend);
    }

    // 월간 예산: 서버 API 응답의 monthly_limit 사용
    // is_configured == false 이거나 API 실패(null) 시 로컬 SharedPreferences 폴백
    final budgetConfigured = budgetData?['is_configured'] as bool? ?? false;
    final serverBudget = budgetConfigured
        ? ((budgetData?['monthly_limit'] as num?)?.toInt() ?? 0)
        : 0;
    final monthlyBudget = serverBudget > 0
        ? serverBudget
        : await ExperienceService.getMonthlyBudget(); // 서버 미설정/실패 시 로컬 폴백
    // 서버에서 받았으면 로컬에도 동기
    if (serverBudget > 0) {
      await ExperienceService.setMonthlyBudget(serverBudget);
    }

    final dailyBase = await ExperienceService.getDailyBaseBudget();
    final carryover = await ExperienceService.getCarryoverAmount();

    final totalExp = usesBackendPetState
        ? _intValue(petState['exp']) ?? 0
        : await ExperienceService.getTotalExp();
    final newLevel =
        (usesBackendPetState ? _intValue(petState['level']) : null) ??
        ExperienceService.levelFromExp(totalExp);
    final persistedLevel = await ExperienceService.getLastLevel();

    if (!mounted) return usesBackendPetState;

    final shouldEvolve =
        _crossedEvolution(persistedLevel, newLevel) && !_evolutionPending;
    await ExperienceService.saveLastLevel(newLevel);

    // 펫 mood: 이제 'normal' | 'angry' 문자열 (숫자 아님)
    final moodRaw = petState?['mood']?.toString() ?? 'normal';
    final petMood = (moodRaw == 'angry') ? 'angry' : 'normal';

    setState(() {
      _prevLevel = persistedLevel;
      _level = newLevel;
      _totalExp = totalExp;
      _expProgress = ExperienceService.expProgress(totalExp);
      _todaySpend = todaySpend;
      _monthlyBudget = monthlyBudget;
      _monthlySpend = monthlySpend;
      _dailyBaseBudget = dailyBase;
      _carryover = carryover;
      _usesBackendPetState = usesBackendPetState;
      _petName = usesBackendPetState
          ? _stringValue(petState['name'])
          : _petName;
      _petSpecies = usesBackendPetState
          ? _stringValue(petState['species'])
          : _petSpecies;
      _petMood = usesBackendPetState ? petMood : _petMood;
      if (shouldEvolve) _evolutionPending = true;
    });

    if (usesBackendPetState) _xpTimer?.cancel();
    if (mounted) await _checkAndShowBudgetAlert();

    if (shouldEvolve) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _triggerEvolution());
    } else {
      _refreshCharacterIfNeeded(newLevel);
    }
    return usesBackendPetState;
  }

  int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String? _stringValue(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  void _refreshCharacterIfNeeded(int newLevel) {
    final needed = characterAsset(newLevel, species: _petSpecies);
    if (_videoController.dataSource.contains(needed.split('/').last)) return;
    _videoController.dispose();
    _initVideoController(newLevel);
  }

  Future<void> _addDemoExperience() async {
    if (_isAddingDemoExp || !_isDemoModeEnabled) return;

    setState(() => _isAddingDemoExp = true);
    try {
      final nextTotalExp = _usesBackendPetState
          ? (_totalExp + ExperienceService.xpPerLevel)
          : await ExperienceService.addDemoExp();
      final newLevel = ExperienceService.levelFromExp(nextTotalExp);
      final shouldEvolve =
          _crossedEvolution(_level, newLevel) && !_evolutionPending;

      if (!mounted) return;
      setState(() {
        _prevLevel = _level;
        _level = newLevel;
        _totalExp = nextTotalExp;
        _expProgress = ExperienceService.expProgress(nextTotalExp);
        _currentComment = '데모 경험치가 추가됐어요!';
        if (shouldEvolve) _evolutionPending = true;
      });

      if (shouldEvolve) {
        _xpTimer?.cancel();
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _triggerEvolution(),
        );
      } else {
        _refreshCharacterIfNeeded(newLevel);
      }
    } finally {
      if (mounted) setState(() => _isAddingDemoExp = false);
    }
  }

  Future<void> _resetDemoExperience() async {
    if (_isResettingDemoExp || !_isDemoModeEnabled) return;

    setState(() => _isResettingDemoExp = true);
    try {
      if (!_usesBackendPetState) {
        await ExperienceService.resetExp();
      }

      if (!mounted) return;
      setState(() {
        _prevLevel = _level;
        _level = 1;
        _totalExp = 0;
        _expProgress = 0.0;
        _evolutionPending = false;
        _currentComment = '데모 경험치가 초기화됐어요!';
      });
      _refreshCharacterIfNeeded(1);
    } finally {
      if (mounted) setState(() => _isResettingDemoExp = false);
    }
  }

  void _triggerEvolution() {
    if (!mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (ctx, animation, _) {
          return FadeTransition(
            opacity: animation,
            child: EvolutionScreen(
              newCharacterAsset: characterAsset(_level, species: _petSpecies),
              newLevel: _level,
              species: _petSpecies,
              onComplete: () {
                if (!mounted) return;
                setState(() => _evolutionPending = false);
                _videoController.dispose();
                _initVideoController(_level);
                _startXpTimer(); // 진화 완료 후 타이머 재시작
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _requestPermissions() async {
    try {
      final granted = await NotificationListenerService.isPermissionGranted();
      if (!granted) await NotificationListenerService.requestPermission();
    } catch (e) {
      print('권한 요청 에러: $e');
    }
    // 위치 권한 요청 (백그라운드 isolate에서는 권한 요청이 불가능하므로
    // UI 진입 시 미리 받아둬야 GPS 좌표 기반 카테고라이징이 동작함)
    await LocationService.ensurePermission();
  }

  Future<void> _generateRandomComment() async {
    final random = Random();
    setState(() {
      _currentComment = _comments[random.nextInt(_comments.length)];
    });

    // 캐릭터 탭마다 5 XP 지급
    await ExperienceService.addExp(5);
    final totalExp = await ExperienceService.getTotalExp();
    final newLevel = ExperienceService.levelFromExp(totalExp);
    if (!mounted) return;

    final shouldEvolve = _crossedEvolution(_level, newLevel) && !_evolutionPending;
    setState(() {
      _prevLevel = _level;
      _level = newLevel;
      _totalExp = totalExp;
      _expProgress = ExperienceService.expProgress(totalExp);
      if (shouldEvolve) _evolutionPending = true;
    });

    if (shouldEvolve) {
      await ExperienceService.saveLastLevel(newLevel);
      _xpTimer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) => _triggerEvolution());
    } else {
      _refreshCharacterIfNeeded(newLevel);
    }
  }

  String _formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  /// 일일 예산 초과 그래프 (짧은 바 형태, 상단 카드 내부에 삽입)
  List<Widget> _buildDailyBudgetBar(ThemeColors colors) {
    final totalBudget = _dailyBaseBudget + _carryover;
    final isOver = _todaySpend > totalBudget;
    // 진행률: 예산 대비 지출 비율, 최대 1.0
    final progress = totalBudget > 0
        ? (_todaySpend / totalBudget).clamp(0.0, 1.0)
        : 0.0;

    return [
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOver ? Colors.red : colors.primaryText,
                ),
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
              child: const Text(
                '초과',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;
    final int? remainingBudget = _monthlyBudget > 0
        ? _monthlyBudget - _monthlySpend
        : null;
    final petTitle = _petName ?? _characterLabel(_level);
    final speciesLabel = _petSpecies == null
        ? null
        : _petSpeciesLabel(_petSpecies!);
    final petSubtitle = _petSpecies == null
        ? _characterLabel(_level)
        : speciesLabel == null
        ? null
        : '${_characterLabel(_level)} · $speciesLabel';

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
            icon: Icon(
              Icons.notifications_none,
              color: colors.primaryText,
              size: 32,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              ).then((_) => _loadAll());
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 15),

              // 레벨 / XP / 지출 카드
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'LV : $_level',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.primaryText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          petTitle,
                          style: TextStyle(fontSize: 13, color: colors.subText),
                        ),
                      ],
                    ),
                    if (petSubtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        petSubtitle,
                        style: TextStyle(fontSize: 12, color: colors.subText),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'EXP',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colors.primaryText,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: _expProgress,
                              minHeight: 10,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colors.primaryText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isDemoModeEnabled) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isResettingDemoExp
                                  ? null
                                  : _resetDemoExperience,
                              icon: const Icon(Icons.restart_alt, size: 18),
                              label: Text(
                                _isResettingDemoExp ? '초기화 중...' : 'EXP 초기화',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.primaryText,
                                side: BorderSide(color: colors.primaryText),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _isAddingDemoExp
                                  ? null
                                  : _addDemoExperience,
                              icon: const Icon(Icons.bolt, size: 18),
                              label: Text(
                                _isAddingDemoExp ? '추가 중...' : 'EXP +100',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: colors.primaryText,
                                foregroundColor: colors.background,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (_usesBackendPetState) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildPetMoodChip(_petMood, colors),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '오늘의 소비',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.subText,
                              ),
                            ),
                            Text(
                              '${_formatAmount(_todaySpend)}원',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colors.primaryText,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '남은 예산',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.subText,
                              ),
                            ),
                            Text(
                              remainingBudget != null
                                  ? '${_formatAmount(remainingBudget)}원'
                                  : '예산 미설정',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                 color:
                                    remainingBudget != null &&
                                        remainingBudget < 0
                                    ? Colors.red
                                    : colors.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // ── 일일 예산 초과 그래프 (짧게) ──
                    if (_dailyBaseBudget > 0) ..._buildDailyBudgetBar(colors),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 캐릭터 영상
              Expanded(
                child: GestureDetector(
                  onTap: _generateRandomComment,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Center(
                        child: _videoController.value.isInitialized
                            ? AspectRatio(
                                aspectRatio: _videoController.value.aspectRatio,
                                child: VideoPlayer(_videoController),
                              )
                            : CircularProgressIndicator(
                                color: colors.primaryText,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 멘트 카드
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 30,
                ),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    _currentComment,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: colors.primaryText,
                      height: 1.5,
                    ),
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

  String _characterLabel(int level) {
    switch (_petSpecies) {
      case 'horse':
        if (level >= 10) return '유니콘';
        if (level >= 5) return '말';
        return '조랑말';
      case 'parrot':
        if (level >= 10) return '파이널 앵무새';
        if (level >= 5) return '앵무새';
        return '초록 앵무새';
      case 'dolphin':
      default:
        if (level >= 10) return '범고래';
        if (level >= 5) return '파란 고래';
        return '돌고래';
    }
  }

  String? _petSpeciesLabel(String species) {
    switch (species) {
      case 'horse':
        return '말';
      case 'parrot':
        return '앵무새';
      case 'dolphin':
        return '돌고래';
      default:
        return null;
    }
  }

  Widget _buildPetMoodChip(String mood, ThemeColors colors) {
    final isAngry = mood == 'angry';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isAngry
            ? Colors.red.withValues(alpha: 0.12)
            : colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAngry ? Icons.mood_bad : Icons.mood,
            size: 14,
            color: isAngry ? Colors.red : colors.primaryText,
          ),
          const SizedBox(width: 4),
          Text(
            isAngry ? '화남' : '평온',
            style: TextStyle(
              color: isAngry ? Colors.red : colors.primaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetStatusChip(String label, int? value, ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label ${value ?? '-'}',
        style: TextStyle(
          color: colors.primaryText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
