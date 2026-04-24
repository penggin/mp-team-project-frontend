import 'package:flutter/material.dart';
import 'dart:math';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const MoneyTrackerApp());
}
class MoneyTrackerApp extends StatelessWidget {
  const MoneyTrackerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '가계부 키우기',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      // 시작 화면을 로그인 화면으로 할지, 메인 화면으로 할지에 따라 변경
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
// --- 1. 전체 화면을 관리하는 껍데기 (네비게이션 바 전용) ---
class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 처음 앱을 켜면 '홈(고래)' 화면(인덱스 2)이 보이도록 설정
  int _selectedIndex = 2;

  // 하단 탭을 눌렀을 때 보여줄 알맹이 화면들 리스트
  final List<Widget> _screens = [
    const SettingsScreen(),                     // 💡 0: 이제 임시 텍스트 대신 진짜 설정 화면이 나옵니다!
    const Center(child: Text('가계부 화면')),       // 1: 가계부
    const HomeScreen(),                         // 2: 홈 (기존 고래 화면)
    const StatisticsScreen(),                   // 3: 통계
    const Center(child: Text('마이페이지 화면')),     // 4: 마이페이지
  ];

  // 탭을 누르면 실행되는 함수
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 💡 IndexedStack: 화면을 이동해도 영상이 꺼지지 않고 백그라운드에서 유지되게 해주는 마법의 위젯!
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.lightBlue.shade100,
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex, // 현재 선택된 탭 알려주기
          onTap: _onItemTapped,         // 탭을 눌렀을 때 화면 바꾸기 함수 실행
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Colors.red.shade900,
          unselectedItemColor: const Color(0xFF1E105C),
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined, size: 30), label: '설정'),
            BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined, size: 30), label: '가계부'),
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined, size: 30), label: '홈'),
            BottomNavigationBarItem(icon: Icon(Icons.pie_chart_outline, size: 30), label: '통계'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline, size: 30), label: '마이페이지'),
          ],
        ),
      ),
    );
  }
}


// --- 2. 기존의 고래가 있는 메인 화면 (이름을 HomeScreen으로 변경!) ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 상태 변수 (기존과 완벽하게 동일)
  int level = 5;
  double expProgress = 0.6;
  int todaySpend = 30700;
  int remainingBalance = 170580;

  final List<String> _comments = [
    "저 너무 배가 불러요!!",
    "이곳저곳 많이 다녔어요!",
    "내 또래에 비해 식비에 10만원 더 사용했어요",
    "오늘은 절약의 날! 잘하고 있어요.",
    "조금만 더 모으면 다음 레벨이에요!"
  ];

  String _currentComment = "캐릭터를 클릭하면 멘트가 나와요!";

  final Color cardBackgroundColor = const Color(0xFFE8F6F8);
  final Color primaryTextColor = const Color(0xFF1E105C);

  late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset('assets/killerwhale.mp4')
      ..initialize().then((_) {
        setState(() {});
        _videoController.setLooping(true);
        _videoController.setVolume(0.0);
        _videoController.play();
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  void _generateRandomComment() {
    final random = Random();
    int randomIndex = random.nextInt(_comments.length);
    setState(() {
      _currentComment = _comments[randomIndex];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 💡 껍데기(MainScreen)가 네비게이션 바를 가져갔으므로, 여기서는 AppBar와 본문(Body)만 그립니다.
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: primaryTextColor, size: 32),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none, color: primaryTextColor, size: 32),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // 1. 상태 카드
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBackgroundColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LV : $level', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text('EXP', style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: expProgress,
                              minHeight: 12,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(primaryTextColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('오늘의 소비', style: TextStyle(color: Colors.black54)),
                            Text('${todaySpend.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('남은 잔액', style: TextStyle(color: Colors.black54)),
                            Text('${remainingBalance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. 캐릭터 영역
              Expanded(
                child: GestureDetector(
                  onTap: _generateRandomComment,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBackgroundColor,
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
                            : const CircularProgressIndicator(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. 대사 박스
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                decoration: BoxDecoration(
                  color: cardBackgroundColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    _currentComment,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
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
}

// --- 로그인 화면 위젯 ---
// --- 로그인 화면 위젯 ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

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
    return Scaffold(
      backgroundColor: Colors.white, // 전체 배경은 깔끔한 흰색
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
                Text('ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: themeDarkBlue)),
                const SizedBox(height: 8),
                TextField(
                  controller: _idController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15), // 피그마 시안처럼 둥글게
                      borderSide: BorderSide(color: Colors.blue.shade200, width: 1.5), // 하늘색 테두리
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: themeDarkBlue, width: 2), // 클릭 시 진한 파란색
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. 비밀번호 입력 영역
                Text('password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: themeDarkBlue)),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
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
                const SizedBox(height: 40),

                // 4. Log In 버튼
                ElevatedButton(
                  onPressed: _goToMainScreen, // 로그인 버튼에 화면 이동 연결
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeSkyBlue, // 하늘색 배경
                    foregroundColor: themeDarkBlue, // 진한 파란색 글씨
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
                const SizedBox(height: 25),

                // 6. 하단 링크 (비밀번호 찾기 | 아이디 찾기)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {},
                      child: Text('비밀번호 찾기', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ),
                    Text('|', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                    TextButton(
                      onPressed: () {},
                      child: Text('아이디 찾기', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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

// --- 통계 화면 위젯 ---
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 상단 통계 카드 (하늘색 테마 적용)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50, // 연한 하늘색 배경
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 월 선택 부분
                      const Column(
                        children: [
                           Icon(Icons.keyboard_arrow_up, color: Colors.black54),
                           Text('3월', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                           Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                        ],
                      ),
                      // 도넛 차트
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: CustomPaint(
                          painter: DonutChartPainter(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 수입/지출 요약
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('수입', style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
                      Text('630,000 원', style: TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('지출', style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
                      Text('300,300 원', style: TextStyle(fontSize: 18, color: Colors.red.shade400, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 2. 최근 내역 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('최근내역', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                Row(
                  children: [
                    _buildTextButton(Icons.calendar_today, '달력 보기'),
                    const SizedBox(width: 10),
                    _buildTextButton(Icons.list_alt, '전체 보기'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),

            // 3. 내역 리스트 (하늘색 테마 적용)
            _buildTransactionItem(Icons.local_cafe, '메가커피 가천대점', '-2,000 원', Colors.red.shade400),
            _buildTransactionItem(Icons.account_balance_wallet, '공유빈', '+50,000 원', Colors.blue),
            _buildTransactionItem(Icons.restaurant, '호식당', '-13,000 원', Colors.red.shade400),
            _buildTransactionItem(Icons.shopping_bag, '김현수', '-24,000 원', Colors.red.shade400),
          ],
        ),
      ),
    );
  }

  // 상단 헤더 버튼을 만들어주는 헬퍼 함수
  Widget _buildTextButton(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // 거래 내역 아이템을 만들어주는 헬퍼 함수
  Widget _buildTransactionItem(IconData icon, String title, String amount, Color amountColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.blue.shade50, // 연한 하늘색 배경
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.black87),
          ),
          const SizedBox(width: 15),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          Text(amount, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: amountColor)),
        ],
      ),
    );
  }
}

// --- 도넛 차트를 그려주는 CustomPainter ---
class DonutChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 30.0; // 도넛 두께

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // 파이 차트 비율 (총합 100) 및 색상 설정
    final sections = [
      {'value': 50.0, 'color': Colors.blue},
      {'value': 13.0, 'color': Colors.grey.shade300},
      {'value': 20.0, 'color': Colors.blue.shade100},
      {'value': 10.0, 'color': Colors.blue.shade200},
      {'value': 7.0, 'color': Colors.tealAccent.shade400},
    ];

    double startAngle = -1.5708; // 12시 방향부터 시작 (-90도)
    for (var section in sections) {
      final sweepAngle = (section['value'] as double) / 100 * 6.2832; // 360도를 라디안으로 변환
      paint.color = section['color'] as Color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - (strokeWidth / 2)),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
                // TODO: 내 정보 수정 화면으로 이동
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
                      // TODO: 화면 테마 변경 화면으로 이동
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
                      // TODO: 비밀번호 및 보안 화면으로 이동
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