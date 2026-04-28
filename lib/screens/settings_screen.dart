import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';
class ThemeProvider extends ChangeNotifier {
  AppThemeType _currentTheme = AppThemeType.sky; // 기본값: 하늘색

  AppThemeType get currentTheme => _currentTheme;
  ThemeColors get colors => AppColors.of(_currentTheme);

  void setTheme(AppThemeType type) {
    if (_currentTheme == type) return;
    _currentTheme = type;
    notifyListeners();
  }
}
// --- 설정 화면 위젯 ---
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key}); // ✅ super.key로 변경

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isNotificationOn = true; // 알림 스위치 상태

  // 💡 공통적으로 사용되는 팝업창(다이얼로그)을 띄우는 함수
  void _showConfirmDialog(String title, VoidCallback onConfirm) {
    // ✅ 다이얼로그 열 때 현재 테마 색상 가져오기
    final colors = context.read<ThemeProvider>().colors;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.background, // ✅ 테마 적용
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                  MaterialPageRoute(builder: (context) => const InfoEditScreen()),
                );
              },
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.cardBackground, width: 2), // ✅ 테마 적용
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: colors.cardBackground, // ✅ 테마 적용
                      child: Icon(Icons.person, size: 35, color: colors.primaryText), // ✅ 테마 적용
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '알 수 없음',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colors.primaryText, // ✅ 테마 적용
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '내 정보 수정',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.subText, // ✅ 테마 적용
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: colors.primaryText, size: 18), // ✅ 테마 적용
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
                      style: TextStyle(color: colors.primaryText, fontWeight: FontWeight.w600), // ✅ 테마 적용
                    ),
                    trailing: Switch(
                      value: isNotificationOn,
                      activeColor: colors.primaryText,       // ✅ 테마 적용
                      activeTrackColor: colors.cardBackground, // ✅ 테마 적용
                      onChanged: (value) {
                        setState(() {
                          isNotificationOn = value;
                        });
                      },
                    ),
                  ),
                  Divider(color: colors.cardBackground, height: 1, thickness: 1), // ✅ 테마 적용
                  ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ThemeSettingsScreen()),
                      );
                    },
                    title: Text(
                      '화면 테마',
                      style: TextStyle(color: colors.primaryText, fontWeight: FontWeight.w600), // ✅ 테마 적용
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, color: colors.primaryText, size: 18), // ✅ 테마 적용
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // 3. 보안 및 계정 관리 그룹
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: colors.cardBackground, width: 2), // ✅ 테마 적용
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PasswordSecurityScreen()),
                      );
                    },
                    title: Text(
                      '비밀번호 및 보안',
                      style: TextStyle(color: colors.primaryText, fontWeight: FontWeight.w600), // ✅ 테마 적용
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, color: colors.primaryText, size: 18), // ✅ 테마 적용
                  ),
                  Divider(color: colors.cardBackground, height: 1, thickness: 1),
                  ListTile(
                    onTap: () {
                      _showConfirmDialog('로그아웃을 진행하시겠습니까?', () {
                        // TODO: 실제 로그아웃 처리 후 로그인 화면으로 이동
                        Navigator.pop(context); // 팝업 닫기 임시 처리
                      });
                    },
                    title: Text(
                      '로그아웃',
                      style: TextStyle(color: colors.primaryText, fontWeight: FontWeight.w600), // ✅ 테마 적용
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, color: colors.primaryText, size: 18), // ✅ 테마 적용
                  ),
                  Divider(color: colors.cardBackground, height: 1, thickness: 1), // ✅ 테마 적용
                  ListTile(
                    onTap: () {
                      _showConfirmDialog('탈퇴를 진행하시겠습니까?', () {
                        // TODO: 실제 탈퇴 처리 로직
                        Navigator.pop(context); // 팝업 닫기 임시 처리
                      });
                    },
                    title: Text(
                      '탈퇴하기',
                      style: TextStyle(color: colors.primaryText, fontWeight: FontWeight.w600), // ✅ 테마 적용
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, color: colors.primaryText, size: 18), // ✅ 테마 적용
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
  const InfoEditScreen({super.key});

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
                  child: Icon(Icons.person, size: 60, color: colors.primaryText),
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
          _buildInfoTile(context, '이름', '알 수 없음', colors),
          _buildInfoTile(context, '영문 이름', 'Unknown', colors),
          _buildInfoTile(context, '생년월일', '2000. 01. 01', colors),
          _buildInfoTile(context, '휴대폰 번호', '010-1234-5678', colors),
          _buildInfoTile(context, '이메일', 'Unknown@gachon.ac.kr', colors),
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ValueEditScreen(title: label, initialValue: value),
          ),
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
          Text(
            value,
            style: TextStyle(color: colors.subText),
          ),
        ],
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: colors.primaryText),
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
                  borderSide: BorderSide(
                    color: colors.primaryText,
                    width: 2,
                  ),
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
    // ✅ sky: 0, pink: 1 로 매핑
    final currentTheme = context.read<ThemeProvider>().currentTheme;
    selectedThemeIndex = currentTheme == AppThemeType.sky ? 0 : 1;
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
            Row(
              children: [
                // ✅ 0: sky 테마, 1: pink 테마
                _buildThemeOption(0, 'sky', colors),
                const SizedBox(width: 20),
                _buildThemeOption(1, 'pink', colors),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                // ✅ 인덱스에 따라 올바른 테마 적용
                final themeType = selectedThemeIndex == 0
                    ? AppThemeType.sky
                    : AppThemeType.pink;
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

  Widget _buildThemeOption(int index, String label, ThemeColors colors) {
    // ✅ 각 테마의 미리보기 색상 직접 지정
    final previewColors = index == 0 ? AppColors.skyTheme : AppColors.pinkTheme;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedThemeIndex = index),
        child: Column(
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(
                  color: selectedThemeIndex == index
                      ? colors.primaryText
                      : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(15),
                color: previewColors.cardBackground, // ✅ 각 테마 미리보기 색상
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.palette,
                      color: previewColors.primaryText, // ✅ 각 테마 미리보기 색상
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label == 'sky' ? '하늘 테마' : '핑크 테마', // ✅ 테마 이름 표시
                      style: TextStyle(
                        color: previewColors.primaryText, // ✅ 각 테마 미리보기 색상
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Icon(
              selectedThemeIndex == index
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: colors.primaryText,
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
                  foregroundColor: colors.primaryText,    // ✅ 테마 적용
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      ),
    );
  }
}