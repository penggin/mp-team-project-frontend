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

// 레벨 + species (+ angry) → 캐릭터 에셋 매핑
String characterAsset(int level, {String? species, bool angry = false}) {
  final suffix = angry ? '_rage' : '';
  switch (species) {
    case 'horse':
      if (level >= 10) return 'assets/unicon$suffix.mp4';
      if (level >= 5) return 'assets/horse$suffix.mp4';
      return 'assets/pony$suffix.mp4';
    case 'parrot':
      if (level >= 10) return 'assets/final_parrot$suffix.mp4';
      if (level >= 5) return 'assets/parrot$suffix.mp4';
      return 'assets/green_parrot$suffix.mp4';
    case 'dolphin':
    default:
      if (level >= 10) return 'assets/killerwhale$suffix.mp4';
      if (level >= 5) return 'assets/bluewhale$suffix.mp4';
      return 'assets/dolphin$suffix.mp4';
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
  int? _level;
  double _expProgress = 0.0;
  int _todaySpend = 0;
  int _monthlyBudget = 0;
  int _monthlySpend = 0;
  int _totalExp = 0;
  bool _evolutionPending = false;
  bool _isLoadingPetState = true;
  bool _isInteractingPet = false;
  bool _isDemoModeEnabled = false;
  String? _petName;
  String? _petSpecies;
  String? _petLoadError;
  // mood: 'normal' | 'angry' 문자열 (백엔드 패치 후 int → String)
  String _petMood = 'normal';
  // health, cleanliness, coins는 팀 API에서 삭제됨

  // 일일 예산 관련
  int _dailyBaseBudget = 0;
  int _carryover = 0;
  bool _budgetAlertShown = false; // 같은 날 중복 표시 방지

  final List<String> _comments = [
    "저 너무 배가 불러요!!",
    "이곳저곳 많이 다녔어요!",
    "내 또래에 비해 식비에 10만원 더 사용했어요",
    "오늘은 절약의 날! 잘하고 있어요.",
    "조금만 더 모으면 다음 레벨이에요!",
  ];

  String _currentComment = "캐릭터를 클릭하면 멘트가 나와요!";
  VideoPlayerController? _videoController;
  String? _currentAsset;

  // 분노 리액션(에피소드) 관련
  Timer? _angryTimer;
  bool _showAngryAnim = false;
  static const Duration _angryReactionDuration = Duration(seconds: 5);

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
      onWasteful: () {
        // "불필요한 금액입니다" 체크 → 캐릭터가 즉시 분노 영상 재생
        _triggerAngryReaction();
      },
    );
  }

  @override
  void dispose() {
    ExperienceService.demoModeEnabled.removeListener(_onDemoModeChanged);
    ExperienceService.monthlyBudgetNotifier.removeListener(_onBudgetChanged);
    _angryTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  /// 일일 예산 초과 결제가 발생한 순간 캐릭터가 잠깐 분노했다가 평상시로 복귀하도록 트리거
  void _triggerAngryReaction() {
    final level = _level;
    if (!mounted || level == null) return;
    _angryTimer?.cancel();
    setState(() {
      _showAngryAnim = true;
      // 종/단계에 맞는 꾸짖는 멘트로 즉시 교체 — 리액션이 끝나도 다음 탭 전까지 유지.
      _currentComment = _pickAngryComment();
    });
    _refreshCharacterIfNeeded(level); // rage 영상으로 전환
    _angryTimer = Timer(_angryReactionDuration, () {
      if (!mounted) return;
      setState(() => _showAngryAnim = false);
      final lvl = _level;
      if (lvl != null) _refreshCharacterIfNeeded(lvl); // 평상시 영상 복귀
    });
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

  /// 분노 영상은 짧은 리액션 동안에만 켜진다(에피소드 모델).
  bool get _isAngry => _showAngryAnim;

  /// 무드 칩 등 "지속" 표시를 위한 일일 예산 초과 여부.
  /// 백엔드가 angry 라고 알려주면 그것도 같이 반영한다.
  bool get _isOverBudget {
    if (_petMood == 'angry') return true;
    final totalBudget = _dailyBaseBudget + _carryover;
    return totalBudget > 0 && _todaySpend > totalBudget;
  }

  void _initVideoController(int level) {
    final asset = characterAsset(level, species: _petSpecies, angry: _isAngry);
    final controller = VideoPlayerController.asset(asset);
    _videoController = controller;
    _currentAsset = asset;
    controller.initialize().then((_) {
      if (!mounted || _videoController != controller) return;
      setState(() {});
      controller.setLooping(true);
      controller.setVolume(0.0);
      controller.play();
    });
  }

  Future<void> _loadAll() async {
    if (mounted) {
      setState(() {
        _isLoadingPetState = true;
        _petLoadError = null;
      });
    }

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

    final newLevel = petState == null ? null : _validLevel(petState['level']);
    final totalExp = petState == null
        ? null
        : max(0, _intValue(petState['exp']) ?? 0);
    final previousLevel = _level;
    final shouldEvolve =
        previousLevel != null &&
        newLevel != null &&
        _crossedEvolution(previousLevel, newLevel) &&
        !_evolutionPending;

    if (!mounted) return;

    // 펫 mood: 이제 'normal' | 'angry' 문자열 (숫자 아님)
    final moodRaw = petState?['mood']?.toString() ?? 'normal';
    final petMood = (moodRaw == 'angry') ? 'angry' : 'normal';

    setState(() {
      _todaySpend = todaySpend;
      _monthlyBudget = monthlyBudget;
      _monthlySpend = monthlySpend;
      _dailyBaseBudget = dailyBase;
      _carryover = carryover;
      _isLoadingPetState = false;

      if (petState == null || newLevel == null) {
        _petLoadError = '펫 상태를 불러오지 못했어요';
        if (_level == null) {
          _totalExp = 0;
          _expProgress = 0.0;
        }
        return;
      }

      _petLoadError = null;
      _level = newLevel;
      _totalExp = totalExp ?? 0;
      _expProgress = ExperienceService.expProgress(_totalExp);
      _petName = _stringValue(petState['name']);
      _petSpecies = _stringValue(petState['species']);
      _petMood = petMood;
      if (shouldEvolve) _evolutionPending = true;
    });

    if (mounted) await _checkAndShowBudgetAlert();

    if (newLevel == null) return;
    if (shouldEvolve) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _triggerEvolution());
      return;
    }

    // 분노 리액션은 더 이상 과소비 감지로 자동 발동되지 않는다.
    // BudgetAlertDialog 의 "불필요한 금액입니다" 체크에서만 _triggerAngryReaction() 이 호출된다.
    _refreshCharacterIfNeeded(newLevel);
  }

  int? _validLevel(Object? value) {
    final level = _intValue(value);
    if (level == null || level < 1) return null;
    return level;
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
    final needed = characterAsset(
      newLevel,
      species: _petSpecies,
      angry: _isAngry,
    );
    if (_videoController != null && _currentAsset == needed) return;
    _videoController?.dispose();
    _initVideoController(newLevel);
  }

  Future<void> _playWithPet() async {
    if (_isInteractingPet || _level == null) return;

    setState(() => _isInteractingPet = true);
    try {
      await _interactWithPet('play', successComment: '같이 놀아서 기분이 좋아졌어요!');
    } finally {
      if (mounted) setState(() => _isInteractingPet = false);
    }
  }

  Future<void> _interactWithPet(
    String action, {
    required String successComment,
  }) async {
    final petState = await ApiService.interactWithPet(action);
    if (!mounted) return;
    if (petState == null) {
      setState(() {
        _petLoadError = '펫 상태를 갱신하지 못했어요';
      });
      return;
    }
    _applyPetState(petState, successComment: successComment);
  }

  void _applyPetState(Map<String, dynamic> petState, {String? successComment}) {
    final newLevel = _validLevel(petState['level']);
    if (newLevel == null) {
      setState(() {
        _petLoadError = '펫 상태를 불러오지 못했어요';
      });
      return;
    }

    final previousLevel = _level;
    final totalExp = max(0, _intValue(petState['exp']) ?? 0);
    final shouldEvolve =
        previousLevel != null &&
        _crossedEvolution(previousLevel, newLevel) &&
        !_evolutionPending;
    final moodRaw = petState['mood']?.toString() ?? 'normal';

    setState(() {
      _petLoadError = null;
      _isLoadingPetState = false;
      _level = newLevel;
      _totalExp = totalExp;
      _expProgress = ExperienceService.expProgress(totalExp);
      _petName = _stringValue(petState['name']);
      _petSpecies = _stringValue(petState['species']);
      _petMood = moodRaw == 'angry' ? 'angry' : 'normal';
      if (successComment != null) _currentComment = successComment;
      if (shouldEvolve) _evolutionPending = true;
    });

    if (shouldEvolve) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _triggerEvolution());
    } else {
      _refreshCharacterIfNeeded(newLevel);
    }
  }

  void _triggerEvolution() {
    final level = _level;
    if (!mounted || level == null) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (ctx, animation, _) {
          return FadeTransition(
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

  /// 종(species) × 진화 단계별로 과소비를 꾸짖는 멘트 풀.
  /// level: 1~4 → 1단계, 5~9 → 2단계, 10+ → 3단계
  List<String> _angryCommentsFor(String? species, int level) {
    switch (species) {
      case 'horse':
        if (level >= 10) {
          return const [
            "유니콘도 못 막는 과소비라니… 답이 없네.",
            "예산 초과야. 이번엔 진짜 실망했어.",
            "이 지출, 진짜 꼭 필요했어?",
          ];
        }
        if (level >= 5) {
          return const [
            "히이잉! 또 예산을 넘기다니, 정신 차리세요!",
            "이러시면 못 달려요. 잠깐 멈춰 보세요.",
            "한 번만 더 결제하면 진짜 화낼 거예요.",
          ];
        }
        return const [
          "히힝! 또 사면 어떡해요!",
          "조랑말도 이건 못 봐줘요…",
          "흥! 오늘은 안 놀아줄 거예요!",
        ];
      case 'parrot':
        if (level >= 10) {
          return const [
            "또 예산 초과네. 학습 능력 어디 갔어?",
            "내가 몇 번을 말했지? 이번이 진짜 마지막 경고야.",
            "한 번 더 묻자. 그거 정말 필요했어?",
          ];
        }
        if (level >= 5) {
          return const [
            "주의! 일일 예산을 초과했습니다!",
            "또 그러시면 진짜로 화낼 거예요!",
            "조금만 참으셨어도 됐을 텐데요…",
          ];
        }
        return const [
          "과소비! 과소비! 안 돼! 안 돼!",
          "예산 초과… 예산 초과… 흥!",
          "또 샀어? 또 샀어?! 으악!",
        ];
      case 'dolphin':
      default:
        if (level >= 10) {
          return const [
            "예산 초과다. 다음 결제는 멈춰라.",
            "또 과소비? 내 인내심에도 한계가 있다.",
            "한 번 더 그러면 가만 안 둔다…!",
          ];
        }
        if (level >= 5) {
          return const [
            "벌써 예산을 넘기다니, 정신 차리세요!",
            "이번 달에도 이러시면 곤란해요.",
            "푸우… 과소비는 멈춰주세요.",
          ];
        }
        return const [
          "또 과소비예요?! 흥, 삐졌어요!",
          "오늘 예산 다 썼다고요… 진짜로요?",
          "끼익! 지갑이 운다고요!",
        ];
    }
  }

  String _pickAngryComment() {
    final pool = _angryCommentsFor(_petSpecies, _level ?? 1);
    return pool[Random().nextInt(pool.length)];
  }

  Future<void> _generateRandomComment() async {
    final random = Random();
    // 예산 초과 중에는 꾸짖는 멘트 풀에서, 아니면 평상시 풀에서 선택.
    final pool = _isOverBudget
        ? _angryCommentsFor(_petSpecies, _level ?? 1)
        : _comments;
    setState(() {
      _currentComment = pool[random.nextInt(pool.length)];
    });

    if (_level == null || _isInteractingPet) return;
    setState(() => _isInteractingPet = true);
    try {
      await _interactWithPet('pet', successComment: _currentComment);
    } finally {
      if (mounted) setState(() => _isInteractingPet = false);
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
    final level = _level;
    final hasPetState = level != null;
    final characterLabel = level == null ? null : _characterLabel(level);
    final petTitle = _petName ?? characterLabel ?? '펫 상태 확인 중';
    final speciesLabel = _petSpecies == null
        ? null
        : _petSpeciesLabel(_petSpecies!);
    final petSubtitle = !hasPetState
        ? null
        : _petSpecies == null
        ? characterLabel
        : speciesLabel == null
        ? null
        : '$characterLabel · $speciesLabel';
    final videoController = _videoController;

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
              const SizedBox(height: 4),

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
                          hasPetState ? 'LV : $level' : 'LV : --',
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
                              onPressed: _isLoadingPetState ? null : _loadAll,
                              icon: const Icon(Icons.sync, size: 18),
                              label: Text(
                                _isLoadingPetState ? '동기화 중...' : '상태 동기화',
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
                              onPressed: _isInteractingPet || !hasPetState
                                  ? null
                                  : _playWithPet,
                              icon: const Icon(Icons.favorite, size: 18),
                              label: Text(
                                _isInteractingPet ? '반영 중...' : '놀아주기',
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
                    if (_petLoadError != null) ...[
                      Text(
                        _petLoadError!,
                        style: TextStyle(fontSize: 12, color: colors.subText),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (hasPetState) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildPetMoodChip(
                            _isOverBudget ? 'angry' : 'normal',
                            colors,
                          ),
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
              const SizedBox(height: 8),

              // 캐릭터 영상
              Expanded(
                flex: 5,
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
                        child:
                            videoController != null &&
                                videoController.value.isInitialized
                            ? AspectRatio(
                                aspectRatio: videoController.value.aspectRatio,
                                child: VideoPlayer(videoController),
                              )
                            : _isLoadingPetState
                            ? CircularProgressIndicator(
                                color: colors.primaryText,
                              )
                            : Icon(
                                Icons.pets,
                                color: colors.primaryText,
                                size: 48,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 멘트 카드
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
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
        color: isAngry ? Colors.red.withValues(alpha: 0.12) : colors.background,
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
}
