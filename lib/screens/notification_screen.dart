import 'package:flutter/material.dart';

// 💡 1. 데이터 모델 뼈대 (나중에 서버에서 받아올 데이터의 형태입니다)
class AppNotification {
  final String content;     // 알림 원본 내용 또는 가공된 제목 (예: "카페에서 16,800원 출금")
  final String category;    // 백엔드에서 분류해 준 카테고리 (예: 'CAFE', 'FOOD', 'DEPOSIT', 'SYSTEM')

  AppNotification({
    required this.content,
    required this.category,
  });
}

// --- 알림 화면 위젯 (동적 데이터 처리를 위해 StatefulWidget으로 변경!) ---
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final Color themeSkyBlue = const Color(0xFFE8F6F8);
  final Color themeDarkBlue = const Color(0xFF1E105C);

  // 화면에 띄울 알림 리스트 변수
  List<AppNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications(); // 화면이 켜질 때 데이터 불러오기
  }

  // 💡 2. 데이터 불러오기 함수 (★나중에 여기서 백엔드 연동 작업을 합니다!★)
  void _fetchNotifications() {
    /* TODO [백엔드 연동 & 알림 파싱 작업]
      1. 휴대폰 권한 얻기 (flutter_sms_inbox 또는 notification_listener_service 패키지 사용)
      2. 휴대폰에 쌓인 결제 알림 텍스트들을 긁어옴
      3. 백엔드 서버로 전송 (http 또는 dio 패키지 사용)
         -> 서버가 카카오 지도 API로 상호명 검색 및 카테고리 분류 수행
      4. 서버에서 예쁘게 분류된 List 데이터를 받아와서 아래 _notifications 변수에 덮어씀
    */

    // 지금은 서버가 없으니 임시(더미) 데이터를 넣어둡니다.
    setState(() {
      _notifications = [
        AppNotification(content: '주경민님께서 15,000원 입금하셨습니다', category: 'DEPOSIT'),
        AppNotification(content: '박소연님께서 15,000원 입금하셨습니다', category: 'DEPOSIT'),
        AppNotification(content: '카페에서 16,800원 출금됐습니다', category: 'CAFE'),
        AppNotification(content: '식당에서 45,000원 출금됐습니다', category: 'FOOD'),
        AppNotification(content: '캐릭터의 상태가 변화했습니다', category: 'SYSTEM'),
        AppNotification(content: '카페에서 4,800원 출금됐습니다.', category: 'CAFE'),
      ];
    });
  }

  // 💡 3. 카테고리에 맞는 아이콘을 자동으로 뱉어주는 마법의 자판기 함수
  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'CAFE':
      case 'FOOD':
      case 'SHOPPING':
        return Icons.account_balance_wallet; // 지출 아이콘
      case 'DEPOSIT':
        return Icons.card_giftcard;          // 입금/선물 아이콘
      case 'SYSTEM':
        return Icons.egg_alt;                // 캐릭터 변화 아이콘
    // TODO: 나중에 백엔드 카테고리가 늘어나면 여기에 case를 계속 추가하시면 됩니다! (예: 교통, 병원 등)
      default:
        return Icons.notifications;          // 기본 아이콘
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeDarkBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('알림', style: TextStyle(color: themeDarkBlue, fontWeight: FontWeight.bold)),
      ),

      // 💡 4. ListView.builder : 리스트가 100개든 1000개든 메모리 낭비 없이 스크롤되게 그려줍니다.
      body: ListView.builder(
        padding: const EdgeInsets.all(20.0),
        physics: const BouncingScrollPhysics(),
        itemCount: _notifications.length, // 리스트의 개수만큼 알아서 그립니다.
        itemBuilder: (context, index) {
          final item = _notifications[index]; // 현재 순서의 데이터 하나 꺼내기

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: themeSkyBlue, width: 2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: themeSkyBlue,
                  // 위에서 만든 마법의 자판기 함수로 아이콘을 자동 세팅합니다.
                  child: Icon(_getIconForCategory(item.category), color: themeDarkBlue),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                      item.content,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}