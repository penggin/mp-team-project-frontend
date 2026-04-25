import 'package:flutter/material.dart';

// --- 회원가입 화면 위젯 ---
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // 앱 전체 테마 색상
  final Color themeSkyBlue = const Color(0xFFE8F6F8);
  final Color themeDarkBlue = const Color(0xFF1E105C);

  // 💡 반복되는 텍스트 입력칸을 쉽게 만들기 위한 헬퍼 함수입니다.
  Widget _buildInputField(String label, {bool isObscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: themeDarkBlue)),
        const SizedBox(height: 8),
        TextField(
          obscureText: isObscure, // 비밀번호 가림 처리
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.blue.shade200, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: themeDarkBlue, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: themeDarkBlue), // 뒤로가기 화살표 색상
        title: Text('회원가입', style: TextStyle(color: themeDarkBlue, fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: themeDarkBlue, height: 1.5), // 시안처럼 앱바 아래 진한 선 추가
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView( // 키보드가 올라와도 화면이 스크롤되도록 설정
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. ID 입력 & 중복확인 버튼 영역
              Text('ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: themeDarkBlue)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.blue.shade200, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: themeDarkBlue, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 중복확인 버튼
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: themeDarkBlue,
                      side: BorderSide(color: themeDarkBlue, width: 1.5), // 테두리 있는 버튼
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    child: const Text('중복확인', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. 나머지 입력 필드들 (헬퍼 함수 사용)
              _buildInputField('password', isObscure: true),
              _buildInputField('check password', isObscure: true),
              _buildInputField('name'),
              _buildInputField('Email'),

              const SizedBox(height: 20),

              // 3. 완료(Sign In) 버튼
              ElevatedButton(
                onPressed: () {
                  // 💡 뒤로 가기 (회원가입 완료 후 다시 로그인 화면으로 돌아감)
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeSkyBlue,
                  foregroundColor: themeDarkBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}