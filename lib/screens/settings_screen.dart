import 'package:flutter/material.dart';

// --- 설정 화면 위젯 ---
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isNotificationOn = true; // 알림 스위치 상태

  final Color themeSkyBlue = const Color(0xFFE8F6F8);
  final Color themeDarkBlue = const Color(0xFF1E105C);

  // 💡 공통적으로 사용되는 팝업창(다이얼로그)을 띄우는 함수
  void _showConfirmDialog(String title, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Center(
            child: Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeDarkBlue),
              textAlign: TextAlign.center,
            ),
          ),
          contentPadding: const EdgeInsets.only(top: 20, bottom: 0),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: onConfirm, // Yes 눌렀을 때 실행할 동작
              child: Text('Yes', style: TextStyle(color: themeDarkBlue, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context), // No 누르면 창 닫기
              child: Text('No', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text('설정', style: TextStyle(color: themeDarkBlue, fontWeight: FontWeight.bold)),
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
                  border: Border.all(color: themeSkyBlue, width: 2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: themeSkyBlue,
                      child: Icon(Icons.person, size: 35, color: themeDarkBlue),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('알 수 없음', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeDarkBlue)),
                          const SizedBox(height: 5),
                          Text('내 정보 수정', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: themeDarkBlue, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            // 2. 알림 및 화면 테마 설정 그룹
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: themeSkyBlue, width: 2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text('알림', style: TextStyle(color: themeDarkBlue, fontWeight: FontWeight.w600)),
                    trailing: Switch(
                      value: isNotificationOn,
                      activeColor: themeDarkBlue,
                      activeTrackColor: themeSkyBlue,
                      onChanged: (value) {
                        setState(() {
                          isNotificationOn = value;
                        });
                      },
                    ),
                  ),
                  Divider(color: themeSkyBlue, height: 1, thickness: 1),
                  ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ThemeSettingsScreen()),
                      );
                    },
                    title: Text('화면 테마', style: TextStyle(color: themeDarkBlue, fontWeight: FontWeight.w600)),
                    trailing: Icon(Icons.arrow_forward_ios, color: themeDarkBlue, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // 3. 보안 및 계정 관리 그룹
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: themeSkyBlue, width: 2),
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
                    title: Text('비밀번호 및 보안', style: TextStyle(color: themeDarkBlue, fontWeight: FontWeight.w600)),
                    trailing: Icon(Icons.arrow_forward_ios, color: themeDarkBlue, size: 18),
                  ),
                  Divider(color: themeSkyBlue, height: 1, thickness: 1),
                  ListTile(
                    onTap: () {
                      _showConfirmDialog('로그아웃을 진행하시겠습니까?', () {
                        // TODO: 실제 로그아웃 처리 후 로그인 화면으로 이동
                        Navigator.pop(context); // 팝업 닫기 임시 처리
                      });
                    },
                    title: Text('로그아웃', style: TextStyle(color: themeDarkBlue, fontWeight: FontWeight.w600)),
                    trailing: Icon(Icons.arrow_forward_ios, color: themeDarkBlue, size: 18),
                  ),
                  Divider(color: themeSkyBlue, height: 1, thickness: 1),
                  ListTile(
                    onTap: () {
                      _showConfirmDialog('탈퇴를 진행하시겠습니까?', () {
                        // TODO: 실제 탈퇴 처리 로직
                        Navigator.pop(context); // 팝업 닫기 임시 처리
                      });
                    },
                    title: Text('탈퇴하기', style: TextStyle(color: themeDarkBlue, fontWeight: FontWeight.w600)),
                    trailing: Icon(Icons.arrow_forward_ios, color: themeDarkBlue, size: 18),
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
class InfoEditScreen extends StatelessWidget {
  const InfoEditScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color themeSkyBlue = const Color(0xFFE8F6F8);
    final Color themeDarkBlue = const Color(0xFF1E105C);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeDarkBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('정보 수정', style: TextStyle(color: themeDarkBlue, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // 프로필 이미지 수정 영역
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: themeSkyBlue,
                  child: Icon(Icons.person, size: 60, color: themeDarkBlue),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.add, size: 20, color: themeDarkBlue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // 정보 목록
          _buildInfoTile(context, '이름', '알 수 없음'),
          _buildInfoTile(context, '영문 이름', 'Unknown'),
          _buildInfoTile(context, '생년월일', '2000. 01. 01'),
          _buildInfoTile(context, '휴대폰 번호', '010-1234-5678'),
          _buildInfoTile(context, '이메일', 'Unknown@gachon.ac.kr'),
        ],
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value) {
    return ListTile(
      onTap: () {
        // 클릭 시 세부 수정 화면으로 이동 (Frame 5)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ValueEditScreen(title: label, initialValue: value)),
        );
      },
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }
}

// --- 2. 세부 정보 수정 입력 화면 (Frame 5) ---
class ValueEditScreen extends StatelessWidget {
  final String title;
  final String initialValue;
  const ValueEditScreen({Key? key, required this.title, required this.initialValue}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color themeSkyBlue = const Color(0xFFE8F6F8);
    final Color themeDarkBlue = const Color(0xFF1E105C);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeDarkBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('정보 수정', style: TextStyle(color: Color(0xFF1E105C), fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$title을 입력해주세요', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(
                hintText: title,
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8F6F8), width: 2)),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeSkyBlue,
                foregroundColor: themeDarkBlue,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              child: const Text('확인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 3. 화면 테마 설정 화면 (Frame 3) ---
class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  int selectedThemeIndex = 1; // 0: 다크, 1: 라이트 (임시 선택 상태)

  @override
  Widget build(BuildContext context) {
    final Color themeSkyBlue = const Color(0xFFE8F6F8);
    final Color themeDarkBlue = const Color(0xFF1E105C);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeDarkBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('설정', style: TextStyle(color: themeDarkBlue, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('화면 테마', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            Row(
              children: [
                _buildThemeOption(0, 'assets/dark_preview.png'), // 다크 테마 프리뷰 이미지 필요
                const SizedBox(width: 20),
                _buildThemeOption(1, 'assets/light_preview.png'), // 라이트 테마 프리뷰 이미지 필요
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeSkyBlue,
                foregroundColor: themeDarkBlue,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              child: const Text('확인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(int index, String imagePath) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedThemeIndex = index),
        child: Column(
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(
                  color: selectedThemeIndex == index ? const Color(0xFF1E105C) : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(15),
                color: Colors.grey.shade100,
              ),
              child: const Center(child: Icon(Icons.image, color: Colors.grey)), // 이미지 없을 시 아이콘 대체
            ),
            const SizedBox(height: 10),
            Icon(
              selectedThemeIndex == index ? Icons.check_circle : Icons.radio_button_unchecked,
              color: const Color(0xFF1E105C),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 비밀번호 및 보안 화면 (Frame 6) ---
class PasswordSecurityScreen extends StatelessWidget {
  const PasswordSecurityScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color themeSkyBlue = const Color(0xFFE8F6F8);
    final Color themeDarkBlue = const Color(0xFF1E105C);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeDarkBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('비밀번호 및 보안', style: TextStyle(color: themeDarkBlue, fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: themeDarkBlue, height: 1.5), // 앱바 아래 진한 선
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
              Text('현재 비밀번호 입력', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: themeDarkBlue)),
              const SizedBox(height: 8),
              _buildPasswordField(themeDarkBlue),
              const SizedBox(height: 25),

              // 2. 새 비밀번호 입력
              Text('새 비밀번호 입력', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: themeDarkBlue)),
              const SizedBox(height: 8),
              _buildPasswordField(themeDarkBlue),
              const SizedBox(height: 25),

              // 3. 새 비밀번호 확인
              Text('새 비밀번호 확인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: themeDarkBlue)),
              const SizedBox(height: 8),
              _buildPasswordField(themeDarkBlue),
              const SizedBox(height: 40),

              // 4. 확인 버튼
              ElevatedButton(
                onPressed: () {
                  // TODO: 비밀번호 변경 처리 로직 추가
                  Navigator.pop(context); // 완료 후 이전 화면(설정)으로 돌아가기
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeSkyBlue,
                  foregroundColor: themeDarkBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15), // 피그마 시안에 맞춘 둥근 모서리
                  ),
                  elevation: 0,
                ),
                child: const Text('확인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 비밀번호 입력칸을 만들어주는 헬퍼 함수
  Widget _buildPasswordField(Color borderColor) {
    return TextField(
      obscureText: true, // 비밀번호 가림 처리
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.blue.shade200, width: 1.5), // 연한 파란색 테두리
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: borderColor, width: 2), // 클릭 시 진한 파란색 테두리
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      ),
    );
  }
}