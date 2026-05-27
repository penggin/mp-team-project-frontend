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
import 'main_screen.dart';

// 레벨 → 캐릭터 에셋 매핑
String characterAsset(int level) {
  if (level >= 10) return 'assets/killerwhale.mp4';
  if (level >= 5) return 'assets/bluewhale.mp4';
  return 'assets/dolphin.mp4';
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
  bool _evolutionPending = false;

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
    _loadAll().then((_) {
      if (mounted) _startXpTimer();
    });
    _initVideoController(_level);
  }

  Future<void> _loadDailyBudget() async {
    final base = await ExperienceService.getDailyBaseBudget();
    final carryover = await ExperienceService.getCarryoverAmount();
    if (!mounted) return;
    setState(() {
      _dailyBaseBudget = base;
      _carryover = carryover;
    });
  }

  Future<void> _checkAndShowBudgetAlert() async {
    if (_budgetAlertShown) return;
    final exceeded = await ExperienceService.checkDailyBudgetExceeded(_todaySpend);
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
    _videoController.dispose();
    super.dispose();
  }

  // ── 실시간 XP 타이머 ──────────────────────────────────────────

  void _startXpTimer() {
    _xpTimer?.cancel();
    _xpTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickXp());
  }

  Future<void> _tickXp() async {
    if (_ticking || !mounted) return;
    _ticking = true;
    try {
      await ExperienceService.addTimeBasedExp();
      await ExperienceService.applyDailyPenalty(_todaySpend);
      final totalExp = await ExperienceService.getTotalExp();
      final monthlyBudget = await ExperienceService.getMonthlyBudget();
      final newLevel = ExperienceService.levelFromExp(totalExp);

      if (!mounted) return;

      final shouldEvolve = _crossedEvolution(_level, newLevel) && !_evolutionPending;

      setState(() {
        _prevLevel = _level;
        _level = newLevel;
        _expProgress = ExperienceService.expProgress(totalExp);
        _monthlyBudget = monthlyBudget;
        if (shouldEvolve) _evolutionPending = true;
      });

      if (shouldEvolve) {
        _xpTimer?.cancel(); // 진화 중 타이머 일시 정지
        WidgetsBinding.instance.addPostFrameCallback((_) => _triggerEvolution());
      }
    } finally {
      _ticking = false;
    }
  }

  // ─────────────────────────────────────────────────────────────

  void _initVideoController(int level) {
    _videoController = VideoPlayerController.asset(characterAsset(level))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _videoController.setLooping(true);
        _videoController.setVolume(0.0);
        _videoController.play();
      });
  }

  Future<void> _loadAll() async {
    await ExperienceService.addTimeBasedExp();

    final entries = await ApiService.getLedgerEntries();
    final now = DateTime.now();
    int todaySpend = 0;
    int monthlySpend = 0;

    for (final entry in entries) {
      if ((entry['type'] as String? ?? '') != 'expense') continue;
      final amount = (entry['amount'] as num?)?.toInt() ?? 0;
      final txAtStr = (entry['transaction_at'] as String? ??
              entry['created_at'] as String? ??
              '')
          .trim();
      if (txAtStr.isEmpty) continue;
      try {
        final txAt = DateTime.parse(txAtStr).toLocal();
        if (txAt.year == now.year && txAt.month == now.month) {
          monthlySpend += amount;
          if (txAt.day == now.day) todaySpend += amount;
        }
      } catch (_) {}
    }

    await ExperienceService.applyDailyPenalty(todaySpend);
    await ExperienceService.recordTodaySpend(todaySpend);

    final totalExp = await ExperienceService.getTotalExp();
    final monthlyBudget = await ExperienceService.getMonthlyBudget();
    final newLevel = ExperienceService.levelFromExp(totalExp);
    final dailyBase = await ExperienceService.getDailyBaseBudget();
    final carryover = await ExperienceService.getCarryoverAmount();

    if (!mounted) return;

    final shouldEvolve = _crossedEvolution(_prevLevel, newLevel) && !_evolutionPending;

    setState(() {
      _prevLevel = _level;
      _level = newLevel;
      _expProgress = ExperienceService.expProgress(totalExp);
      _todaySpend = todaySpend;
      _monthlyBudget = monthlyBudget;
      _monthlySpend = monthlySpend;
      _dailyBaseBudget = dailyBase;
      _carryover = carryover;
      if (shouldEvolve) _evolutionPending = true;
    });

    // 하루 예산 초과 여부 체크
    if (mounted) await _checkAndShowBudgetAlert();

    if (shouldEvolve) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _triggerEvolution());
    } else {
      _refreshCharacterIfNeeded(newLevel);
    }
  }

  void _refreshCharacterIfNeeded(int newLevel) {
    final needed = characterAsset(newLevel);
    if (_videoController.dataSource.contains(needed.split('/').last)) return;
    _videoController.dispose();
    _initVideoController(newLevel);
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
              newCharacterAsset: characterAsset(_level),
              newLevel: _level,
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
  }

  void _generateRandomComment() {
    final random = Random();
    setState(() {
      _currentComment = _comments[random.nextInt(_comments.length)];
    });
  }

  String _formatAmount(int amount) {
    return amount
        .toString()
        .replaceAllMapped(
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
          if (isOver) ...
            [
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
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
    final int? remainingBudget =
        _monthlyBudget > 0 ? _monthlyBudget - _monthlySpend : null;

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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          _characterLabel(_level),
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.subText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '오늘의 소비',
                              style: TextStyle(fontSize: 12, color: colors.subText),
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
                              style: TextStyle(fontSize: 12, color: colors.subText),
                            ),
                            Text(
                              remainingBudget != null
                                  ? '${_formatAmount(remainingBudget)}원'
                                  : '예산 미설정',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: remainingBudget != null &&
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
                                aspectRatio:
                                    _videoController.value.aspectRatio,
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
    if (level >= 10) return '범고래';
    if (level >= 5) return '파란 고래';
    return '돌고래';
  }
}
