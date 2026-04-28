import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // ✅ 추가
import 'main_screen.dart'; // 로그인 완료 시 갈 곳
import 'signup_screen.dart'; // 회원가입 누를 시 갈 곳
import 'settings_screen.dart'; // ✅ 추가

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key}); // ✅ super.key로 변경

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController(); // Email -> ID로 변경
  final TextEditingController _passwordController = TextEditingController();

  // 메인 화면 테마와 동일한 색상 지정
  final Color themeSkyBlue = const Color(0xFFE8F6F8);
  final Color themeDarkBlue = const Color(0xFF1E105C);

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Log In 버튼을 눌렀을 때 메인 화면으로 이동
  void _goToMainScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;
    return Scaffold(
      backgroundColor: colors.background, // ✅ 테마 배경색
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. 로고 영역
                Center(
                  child: Image.asset(
                    'assets/icon.png',
                    width: 140,
                    height: 140,
                  ),
                ),
                const SizedBox(height: 40),

                // 2. ID 입력 영역
                Text(
                  'ID',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: colors.primaryText, // ✅ 테마 텍스트 색상
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _idController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colors.cardBackground, // ✅ 테마 카드 배경색
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: colors.accent, width: 1.5), // ✅ 테마 포인트 색상
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: colors.primaryText, width: 2), // ✅ 테마 텍스트 색상
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. 비밀번호 입력 영역
                Text(
                  'password',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: colors.primaryText, // ✅ 테마 텍스트 색상
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colors.cardBackground, // ✅ 테마 카드 배경색
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: colors.accent, width: 1.5), // ✅ 테마 포인트 색상
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: colors.primaryText, width: 2), // ✅ 테마 텍스트 색상
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),
                const SizedBox(height: 40),

                // 4. Log In 버튼
                ElevatedButton(
                  onPressed: _goToMainScreen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.cardBackground, // ✅ 테마 카드 배경색
                    foregroundColor: colors.primaryText,    // ✅ 테마 텍스트 색상
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Log In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 15),

                // 5. Sign In 버튼 (회원가입)
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SignUpScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.cardBackground, // ✅ 테마 카드 배경색
                    foregroundColor: colors.primaryText,    // ✅ 테마 텍스트 색상
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 25),

                // 6. 하단 링크
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        '비밀번호 찾기',
                        style: TextStyle(color: colors.subText, fontSize: 13), // ✅ 테마 서브 텍스트
                      ),
                    ),
                    Text('|', style: TextStyle(color: colors.subText, fontSize: 13)),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        '아이디 찾기',
                        style: TextStyle(color: colors.subText, fontSize: 13), // ✅ 테마 서브 텍스트
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

