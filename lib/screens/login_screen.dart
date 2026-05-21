import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main_screen.dart';
import 'signup_screen.dart';
import '../app_colors.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  final Color themeSkyBlue = const Color(0xFFE8F6F8);
  final Color themeDarkBlue = const Color(0xFF1E105C);

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _goToMainScreen() async {
    final email = _idController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('이메일과 비밀번호를 입력해주세요');
      return;
    }

    setState(() => _isLoading = true);
    final result = await ApiService.login(email, password);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainScreen(key: MainScreen.globalKey),
        ),
      );
    } else {
      _showSnackBar(result['message'] ?? '로그인 실패');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.colors;
        return Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/icon.png',
                        width: 140,
                        height: 140,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Email',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: colors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _idController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: colors.cardBackground,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: colors.accent, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: colors.primaryText, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Password',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: colors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: colors.cardBackground,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: colors.accent, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: colors.primaryText, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _goToMainScreen,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.cardBackground,
                        foregroundColor: colors.primaryText,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Log In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SignUpScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.cardBackground,
                        foregroundColor: colors.primaryText,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {},
                          child: Text('비밀번호 찾기',
                              style: TextStyle(color: colors.subText, fontSize: 13)),
                        ),
                        Text('|', style: TextStyle(color: colors.subText, fontSize: 13)),
                        TextButton(
                          onPressed: () {},
                          child: Text('아이디 찾기',
                              style: TextStyle(color: colors.subText, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}