import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';
import '../services/experience_service.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'character_select_screen.dart';

// --- 설정 화면 위젯 ---
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key}); // ✅ super.key로 변경

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isNotificationOn = true;
  int _monthlyBudget = 0;
  Map<String, dynamic>? _userProfile;
  bool _isLoadingUserProfile = true;
  bool _isDemoModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBudget();
    _loadUserProfile();
    _loadDemoMode();
  }

  Future<void> _loadBudget() async {
    // 서버 API에서 월간 예산 조회
    final now = DateTime.now();
    final budgetData = await ApiService.getMonthlyBudget(
      year: now.year,
      month: now.month,
    );
    final configured = budgetData?['is_configured'] as bool? ?? false;
    final serverBudget = configured
        ? ((budgetData?['monthly_limit'] as num?)?.toInt() ?? 0)
        : 0;

    if (serverBudget > 0) {
      // 서버 값을 로컈에도 동기
      await ExperienceService.setMonthlyBudget(serverBudget);
      if (mounted) setState(() => _monthlyBudget = serverBudget);
    } else {
      // 서버 미설정 시 로컈 폴백
      final localBudget = await ExperienceService.getMonthlyBudget();
      if (mounted) setState(() => _monthlyBudget = localBudget);
    }
  }
  Future<void> _loadUserProfile() async {
    final profile = await ApiService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _userProfile = profile;
      _isLoadingUserProfile = false;
    });
  }

  Future<void> _loadDemoMode() async {
    final enabled = await ExperienceService.loadDemoMode();
    if (mounted) setState(() => _isDemoModeEnabled = enabled);
  }

  Future<void> _setDemoModeEnabled(bool enabled) async {
    setState(() => _isDemoModeEnabled = enabled);
    await ExperienceService.setDemoModeEnabled(enabled);
  }

  String get _displayNickname {
    if (_isLoadingUserProfile) return '불러오는 중...';
    final nickname = _userProfile?['nickname']?.toString().trim();
    return nickname == null || nickname.isEmpty ? '알 수 없음' : nickname;
  }

  String get _displayEmail {
    final email = _userProfile?['email']?.toString().trim();
    return email == null || email.isEmpty ? '내 정보 수정' : email;
  }

  void _showBudgetDialog(ThemeColors colors) {
    final controller = TextEditingController(
      text: _monthlyBudget > 0 ? _monthlyBudget.toString() : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          '월 예산 설정',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colors.primaryText,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(color: colors.primaryText),
          decoration: InputDecoration(
            hintText: '예: 600000',
            hintStyle: TextStyle(color: colors.subText),
            suffixText: '원',
            suffixStyle: TextStyle(color: colors.primaryText),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.cardBackground, width: 2),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.primaryText, width: 2),
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () async {
              final value = int.tryParse(controller.text) ?? 0;
              if (value > 0) {
                // 서버 API에 저장
                final now = DateTime.now();
                final result = await ApiService.setMonthlyBudget(
                  year: now.year,
                  month: now.month,
                  monthlyLimit: value,
                );
                // 로컬 SharedPreferences에도 동기 (홈 타이머가 로컈 값 사용)
                await ExperienceService.setMonthlyBudget(value);
                if (mounted) {
                  setState(() => _monthlyBudget = value);
                  if (result == null && ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('서버 저장에 실패했습니다. 로컈에만 저장되었습니다.'),
                      ),
                    );
                  }
                }
              } else {
                await ExperienceService.setMonthlyBudget(0);
                if (mounted) setState(() => _monthlyBudget = 0);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(
              '확인',
              style: TextStyle(
                color: colors.primaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소', style: TextStyle(color: colors.subText)),
          ),
        ],
      ),
    );
  }

  void _showCharacterChangeDialog(ThemeColors colors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          '캐릭터 변경 및 초기화',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colors.primaryText,
          ),
        ),
        content: Text(
          '다른 캐릭터로 변경하면 현재 캐릭터의 레벨이 초기화됩니다.\n변경하시겠습니까?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: colors.subText, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // XP 초기화
              await ExperienceService.resetExp();
              await ExperienceService.saveLastLevel(1);
              if (!mounted) return;
              // 캐릭터 선택창으로 이동
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const CharacterSelectScreen(),
                ),
              );
            },
            child: Text(
              'Yes',
              style: TextStyle(
                color: colors.primaryText,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'No',
              style: TextStyle(
                color: colors.subText,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBudget(int amount) {
    if (amount <= 0) return '미설정';
    return '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원';
  }

  // 공통 확인 다이얼로그
  void _showConfirmDialog(String title, VoidCallback onConfirm) {
    // ✅ 다이얼로그 열 때 현재 테마 색상 가져오기
    final colors = context.read<ThemeProvider>().colors;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.background, // ✅ 테마 적용
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.primaryText, // ✅ 테마 적용
              ),
              textAlign: TextAlign.center,
            ),
          ),
          contentPadding: const EdgeInsets.only(top: 20, bottom: 0),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: onConfirm,
              child: Text(
                'Yes',
                style: TextStyle(
                  color: colors.primaryText, // ✅ 테마 적용
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'No',
                style: TextStyle(
                  color: colors.subText, // ✅ 테마 적용
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;
    return Scaffold(
      backgroundColor: colors.background, // ✅ 테마 적용
      appBar: AppBar(
        backgroundColor: colors.background, // ✅ 테마 적용
        elevation: 0,
        centerTitle: true,
        title: Text(
          '설정',
          style: TextStyle(
            color: colors.primaryText, // ✅ 테마 적용
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 1. 프로필 영역 (클릭 시 내 정보 수정으로 이동 예정)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        InfoEditScreen(userProfile: _userProfile),
                  ),
                ).then((_) => _loadUserProfile());
              },
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colors.cardBackground,
                    width: 2,
                  ), // ✅ 테마 적용
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: colors.cardBackground, // ✅ 테마 적용
                      child: Icon(
                        Icons.person,
                        size: 35,
                        color: colors.primaryText,
                      ), // ✅ 테마 적용
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayNickname,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colors.primaryText, // ✅ 테마 적용
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _displayEmail,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.subText, // ✅ 테마 적용
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: colors.primaryText,
                      size: 18,
                    ), // ✅ 테마 적용
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            // 2. 알림 및 화면 테마 설정 그룹
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: colors.cardBackground, width: 2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      '알림',
                      style: TextStyle(
                        color: colors.primaryText,
                        fontWeight: FontWeight.w600,
                      ), // ✅ 테마 적용
                    ),
                    trailing: Switch(
                      value: isNotificationOn,
                      activeThumbColor: colors.primaryText, // ✅ 테마 적용
                      activeTrackColor: colors.cardBackground, // ✅ 테마 적용
                      onChanged: (value) {
                        setState(() {
                          isNotificationOn = value;
                        });
                      },
                    ),
                  ),
                  Divider(
                    color: colors.cardBackground,
                    height: 1,
                    thickness: 1,
                  ), // ✅ 테마 적용
                  ListTile(
                    title: Text(
                      '데모 모드',
                      style: TextStyle(
                        color: colors.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '홈에서 진화 테스트 버튼을 표시합니다',
                      style: TextStyle(color: colors.subText),
                    ),
                    trailing: Switch(
                      value: _isDemoModeEnabled,
                      activeThumbColor: colors.primaryText,
                      activeTrackColor: colors.cardBackground,
                      onChanged: _setDemoModeEnabled,
                    ),
                  ),
                  Divider(
                    color: colors.cardBackground,
                    height: 1,
                    thickness: 1,
                  ),
                  ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ThemeSettingsScreen(),
                        ),
                      );
                    },
                    title: Text(
                      '화면 테마',
                      style: TextStyle(
                        color: colors.primaryText,
                        fontWeight: FontWeight.w600,
                      ), // ✅ 테마 적용
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: colors.primaryText,
                      size: 18,
                    ), // ✅ 테마 적용
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // 3. 예산 설정 그룹
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: colors.cardBackground, width: 2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                onTap: () => _showBudgetDialog(colors),
                title: Text(
                  '월 예산 설정',
                  style: TextStyle(
                    color: colors.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatBudget(_monthlyBudget),
                      style: TextStyle(color: colors.subText),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: colors.primaryText,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            // 3-1. 캐릭터 변경 및 초기화
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: colors.cardBackground, width: 2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                onTap: () => _showCharacterChangeDialog(colors),
                title: Text(
                  '캐릭터 변경 및 초기화',
                  style: TextStyle(
                    color: colors.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  color: colors.primaryText,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 25),

            // 4. 보안 및 계정 관리 그룹
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: colors.cardBackground,
                  width: 2,
                ), // ✅ 테마 적용
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PasswordSecurityScreen(),
                        ),
                      );
                    },
                    title: Text(
                      '비밀번호 및 보안',
                      style: TextStyle(
                        color: colors.primaryText,
                        fontWeight: FontWeight.w600,
                      ), // ✅ 테마 적용
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: colors.primaryText,
                      size: 18,
                    ), // ✅ 테마 적용
                  ),
                  Divider(
                    color: colors.cardBackground,
                    height: 1,
                    thickness: 1,
                  ),
                  ListTile(
                    onTap: () {
                      _showConfirmDialog('로그아웃을 진행하시겠습니까?', () async {
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        await ApiService.logout();
                        if (!mounted) return;
                        navigator.pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                          (_) => false,
                        );
                      });
                    },
                    title: Text(
                      '로그아웃',
                      style: TextStyle(
                        color: colors.primaryText,
                        fontWeight: FontWeight.w600,
                      ), // ✅ 테마 적용
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: colors.primaryText,
                      size: 18,
                    ), // ✅ 테마 적용
                  ),
                  Divider(
                    color: colors.cardBackground,
                    height: 1,
                    thickness: 1,
                  ), // ✅ 테마 적용
                  ListTile(
                    onTap: () {
                      _showConfirmDialog('탈퇴를 진행하시겠습니까?', () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('회원 탈퇴 API가 아직 제공되지 않았습니다'),
                          ),
                        );
                      });
                    },
                    title: Text(
                      '탈퇴하기',
                      style: TextStyle(
                        color: colors.primaryText,
                        fontWeight: FontWeight.w600,
                      ), // ✅ 테마 적용
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: colors.primaryText,
                      size: 18,
                    ), // ✅ 테마 적용
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 1. 내 정보 수정 메인 화면 (Frame 4) ---
// --- 1. 내 정보 수정 화면 ---
class InfoEditScreen extends StatelessWidget {
  final Map<String, dynamic>? userProfile;

  const InfoEditScreen({super.key, this.userProfile});

  String _profileValue(String key, String fallback) {
    final value = userProfile?[key]?.toString().trim();
    if (value == null || value.isEmpty) return fallback;
    return value;
  }

  String _dateValue(String key) {
    final raw = userProfile?[key]?.toString();
    if (raw == null || raw.isEmpty) return '알 수 없음';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return raw;
    return '${parsed.year}. ${parsed.month.toString().padLeft(2, '0')}. ${parsed.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // ✅ build() 하나만 존재, 하드코딩 제거
    final colors = context.watch<ThemeProvider>().colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '정보 수정',
          style: TextStyle(
            color: colors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: colors.cardBackground,
                  child: Icon(
                    Icons.person,
                    size: 60,
                    color: colors.primaryText,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: colors.background,
                    child: Icon(Icons.add, size: 20, color: colors.primaryText),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _buildInfoTile(
            context,
            '닉네임',
            _profileValue('nickname', '알 수 없음'),
            colors,
          ),
          _buildInfoTile(
            context,
            '이메일',
            _profileValue('email', '알 수 없음'),
            colors,
          ),
          _buildInfoTile(
            context,
            '사용자 ID',
            _profileValue('id', '알 수 없음'),
            colors,
          ),
          _buildInfoTile(context, '가입일', _dateValue('created_at'), colors),
          _buildInfoTile(context, '최근 수정일', _dateValue('updated_at'), colors),
        ],
      ),
    );
  }

  // ✅ _buildInfoTile은 build() 밖, 클래스 안에 위치
  Widget _buildInfoTile(
    BuildContext context,
    String label,
    String value,
    ThemeColors colors,
  ) {
    return ListTile(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('내 정보 수정 API가 아직 제공되지 않았습니다')),
        );
      },
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colors.primaryText,
            ),
          ),
          Text(value, style: TextStyle(color: colors.subText)),
        ],
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: colors.primaryText,
      ),
    );
  }
}

// --- 2. 세부 정보 수정 입력 화면 ---
class ValueEditScreen extends StatelessWidget {
  final String title;
  final String initialValue;

  // ✅ 생성자 괄호 오류 수정
  const ValueEditScreen({
    super.key,
    required this.title,
    required this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '정보 수정',
          style: TextStyle(
            color: colors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title을 입력해주세요',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              style: TextStyle(color: colors.primaryText),
              decoration: InputDecoration(
                hintText: title,
                hintStyle: TextStyle(color: colors.subText),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: colors.cardBackground,
                    width: 2,
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.primaryText, width: 2),
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.cardBackground,
                foregroundColor: colors.primaryText,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 0,
              ),
              child: const Text(
                '확인',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 3. 화면 테마 설정 화면 (Frame 3) ---
// --- 테마 설정 화면 ---
class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  late int selectedThemeIndex;

  @override
  void initState() {
    super.initState();
    final currentTheme = context.read<ThemeProvider>().currentTheme;
    // ✅ AppColors 전역 함수로 인덱스 변환
    selectedThemeIndex = AppColors.indexFromType(currentTheme);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '설정',
          style: TextStyle(
            color: colors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '화면 테마',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...AppThemeType.values
                        .asMap()
                        .entries
                        .map((entry) {
                          final index = entry.key;
                          final themeType = entry.value;
                          return index != 0
                              ? [
                                  const SizedBox(width: 20),
                                  _buildThemeOption(index, themeType, colors),
                                ]
                              : [_buildThemeOption(index, themeType, colors)];
                        })
                        .expand((e) => e),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final themeType = AppColors.typeFromIndex(selectedThemeIndex);
                context.read<ThemeProvider>().setTheme(themeType);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.cardBackground,
                foregroundColor: colors.primaryText,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 0,
              ),
              child: const Text(
                '확인',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    int index,
    AppThemeType themeType,
    ThemeColors colors,
  ) {
    // ✅ AppColors.of() 전역 함수로 미리보기 색상 가져오기
    final previewColors = AppColors.of(themeType);
    // ✅ AppColors.labelOf() 전역 함수로 테마 이름 가져오기
    final label = AppColors.labelOf(themeType);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedThemeIndex = index),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color: selectedThemeIndex == index
                      ? colors.primaryText
                      : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(15),
                // ✅ AppColors.of()로 가져온 미리보기 색상 사용
                color: previewColors.cardBackground,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.palette,
                      color: previewColors.primaryText,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label, // ✅ AppColors.labelOf()로 가져온 이름 사용
                      style: TextStyle(
                        color: previewColors.primaryText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Icon(
                selectedThemeIndex == index
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: colors.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 비밀번호 및 보안 화면 (Frame 6) ---
class PasswordSecurityScreen extends StatelessWidget {
  const PasswordSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;
    return Scaffold(
      backgroundColor: colors.background, // ✅ 테마 적용
      appBar: AppBar(
        backgroundColor: colors.background, // ✅ 테마 적용
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primaryText), // ✅ 테마 적용
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '비밀번호 및 보안',
          style: TextStyle(
            color: colors.primaryText, // ✅ 테마 적용
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: colors.primaryText, // ✅ 테마 적용
            height: 1.5,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),

              // 1. 현재 비밀번호 입력
              Text(
                '현재 비밀번호 입력',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colors.primaryText, // ✅ 테마 적용
                ),
              ),
              const SizedBox(height: 8),
              _buildPasswordField(colors), // ✅ colors 전달
              const SizedBox(height: 25),

              // 2. 새 비밀번호 입력
              Text(
                '새 비밀번호 입력',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colors.primaryText, // ✅ 테마 적용
                ),
              ),
              const SizedBox(height: 8),
              _buildPasswordField(colors), // ✅ colors 전달
              const SizedBox(height: 25),

              // 3. 새 비밀번호 확인
              Text(
                '새 비밀번호 확인',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colors.primaryText, // ✅ 테마 적용
                ),
              ),
              const SizedBox(height: 8),
              _buildPasswordField(colors), // ✅ colors 전달
              const SizedBox(height: 40),

              // 4. 확인 버튼
              ElevatedButton(
                onPressed: () {
                  // TODO: 비밀번호 변경 처리 로직 추가
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.cardBackground, // ✅ 테마 적용
                  foregroundColor: colors.primaryText, // ✅ 테마 적용
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Color → ThemeColors로 변경
  Widget _buildPasswordField(ThemeColors colors) {
    return TextField(
      obscureText: true,
      style: TextStyle(color: colors.primaryText), // ✅ 입력 텍스트 테마 적용
      decoration: InputDecoration(
        filled: true,
        fillColor: colors.background, // ✅ 테마 적용
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: colors.cardBackground, // ✅ 테마 적용
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: colors.primaryText, // ✅ 테마 적용
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 15,
        ),
      ),
    );
  }
}
