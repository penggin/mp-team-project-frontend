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
    const Center(child: Text('설정 화면')),         // 0: 설정 (추후 제작)
    const Center(child: Text('가계부 화면')),       // 1: 가계부 (추후 제작)
    const HomeScreen(),                         // 2: 홈 (기존 고래 화면)
    const StatisticsScreen(),                   // 3: 통계 (아까 만든 차트 화면!)
    const Center(child: Text('마이페이지 화면')),     // 4: 마이페이지 (추후 제작)
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
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Sign In 버튼을 눌렀을 때 메인 화면으로 이동
  void _goToMainScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. 로고 영역 (아이콘 -> 실제 이미지로 교체 완료!)
                Center(
                  child: Image.asset(
                    'assets/icon.png', // 💡 여기에 실제 파일 이름을 적어주세요! (예: book.png)
                    width: 120, // 이미지 가로 크기 (원하는 대로 조절 가능)
                    height: 120, // 이미지 세로 크기
                  ),
                ),
                const SizedBox(height: 50),

                // 2. 이메일 입력 영역
                const Text('Email', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: 'Value',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.blue.shade300, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. 비밀번호 입력 영역
                const Text('Password', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Value',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.blue.shade300, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  ),
                ),
                const SizedBox(height: 40),

                // 4. Sign In 버튼
                ElevatedButton(
                  onPressed: _goToMainScreen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEEF1F6),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
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
      body: SingleChildScrollView(
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
                      Column(
                        children: [
                          const Icon(Icons.keyboard_arrow_up, color: Colors.black54),
                          const Text('3월', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
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

