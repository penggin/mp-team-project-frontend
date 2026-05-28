import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';
import 'category_select_screen.dart';

// ✅ TransactionItem 클래스
class TransactionItem {
  final String date;
  final String title;
  final String amount;
  final bool isIncome;
  final String category;
  final IconData icon;
  final DateTime? createdAt; // 날짜 정렬용
  final String? id; // 백엔드 ledger ID (그룹화 PATCH 용)
  final String? bundleId; // 백엔드 bundle_id (그룹 소속 표시)

  const TransactionItem({
    required this.date,
    required this.title,
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.icon,
    this.createdAt,
    this.id,
    this.bundleId,
  });

  TransactionItem copyWith({String? bundleId, bool clearBundle = false}) {
    return TransactionItem(
      date: date,
      title: title,
      amount: amount,
      isIncome: isIncome,
      category: category,
      icon: icon,
      createdAt: createdAt,
      id: id,
      bundleId: clearBundle ? null : (bundleId ?? this.bundleId),
    );
  }
}

class IndividualPaymentScreen extends StatefulWidget {
  final TransactionItem transaction;

  const IndividualPaymentScreen({super.key, required this.transaction});

  @override
  State<IndividualPaymentScreen> createState() =>
      _IndividualPaymentScreenState();
}

class _IndividualPaymentScreenState extends State<IndividualPaymentScreen> {
  bool _includeInTotal = true;

  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.transaction.category;
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
          '상세내역',
          style: TextStyle(
            color: colors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ══════════════════════════════
              // 1. 상단 아이콘 + 가게명
              // ══════════════════════════════
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      widget.transaction.icon,
                      color: colors.primaryText,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    // ✅ title에서 가게명만 짧게 표시 (ex. '메가커피')
                    widget.transaction.title.split(' ').first,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colors.primaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ══════════════════════════════
              // 2. 금액
              // ══════════════════════════════
              Text(
                widget.transaction.amount,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: widget.transaction.isIncome ? Colors.blue : Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Divider(
                color: colors.primaryText.withValues(alpha: 0.15),
                thickness: 1,
              ),
              const SizedBox(height: 8),

              // ══════════════════════════════
              // 3. 상세 정보 그룹 1 (주문금액, 카테고리, 메모, 지출합계포함)
              // ══════════════════════════════
              _buildSimpleRow('주문금액', widget.transaction.amount, colors),
              _buildDivider(colors),

              // 카테고리 (> 화살표 포함)
              // 카테고리 (> 화살표 포함)
              _buildArrowRow(
                '카테고리 설정',
                _selectedCategory,
                colors,
                onTap: () async {
                  final result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategorySelectScreen(
                        currentCategory: _selectedCategory,
                        showChangeDialog: true,
                      ),
                    ),
                  );

                  if (result != null) {
                    setState(() {
                      _selectedCategory = result['category'] as String;
                    });

                    final bool applyToAll =
                        result['applyToAll'] as bool? ?? false;

                    if (applyToAll) {
                      // TODO:
                      // 동일 결제 이력 전체 카테고리 변경
                    }
                  }
                },
              ),

              _buildDivider(colors),

              // 메모 (핑크색 텍스트 + > 화살표)
              _buildMemoRow(colors),
              _buildDivider(colors),

              // 지출 합계에 포함 (스위치)
              _buildSwitchRow(colors),
              const SizedBox(height: 24),

              Divider(
                color: colors.primaryText.withValues(alpha: 0.15),
                thickness: 1,
              ),
              const SizedBox(height: 12),

              // ══════════════════════════════
              // 4. 상세 정보 그룹 2 (결제수단, 결제일시, 사용처)
              // ══════════════════════════════
              _buildSimpleRow('결제수단', 'NH 카드', colors),
              _buildDivider(colors),
              _buildSimpleRow(
                '결제일시',
                '2026년 ${widget.transaction.date.replaceAll('.', '월 ')}일 08:27',
                colors,
              ),
              _buildDivider(colors),
              _buildSimpleRow('사용처', widget.transaction.title, colors),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════
  // 헬퍼 위젯들
  // ══════════════════════════════

  // 일반 텍스트 행
  Widget _buildSimpleRow(String label, String value, ThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 15, color: colors.primaryText),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: colors.primaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // 화살표(>) 있는 행 (카테고리)
  Widget _buildArrowRow(
    String label,
    String value,
    ThemeColors colors, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 15, color: colors.primaryText),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: colors.primaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: colors.primaryText),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 메모 행 (accent 색상 텍스트 + > 화살표)
  Widget _buildMemoRow(ThemeColors colors) {
    return GestureDetector(
      onTap: () {
        // TODO: 메모 입력
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '메모',
              style: TextStyle(fontSize: 15, color: colors.primaryText),
            ),
            Row(
              children: [
                Text(
                  '메모를 남겨보세요',
                  style: TextStyle(
                    fontSize: 15,
                    color: colors.accent, // ✅ 테마 accent 색상
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: colors.accent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 지출 합계에 포함 스위치 행
  Widget _buildSwitchRow(ThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '지출 합계에 포함',
            style: TextStyle(fontSize: 15, color: colors.primaryText),
          ),
          // ✅ 스위치 색상 테마 적용
          Switch(
            value: _includeInTotal,
            onChanged: (value) {
              setState(() {
                _includeInTotal = value;
              });
            },
            activeThumbColor: Colors.white,
            activeTrackColor: colors.accent, // ✅ 켜졌을 때 트랙: accent 색상
            inactiveThumbColor: Colors.white,
            inactiveTrackColor:
                colors.cardBackground, // ✅ 꺼졌을 때 트랙: cardBackground
          ),
        ],
      ),
    );
  }

  // 구분선
  Widget _buildDivider(ThemeColors colors) {
    return Divider(
      color: colors.primaryText.withValues(alpha: 0.08),
      thickness: 1,
      height: 1,
    );
  }
}
