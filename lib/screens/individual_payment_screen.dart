import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';
import '../services/api_service.dart';
import '../services/category_mapper.dart';
import 'category_select_screen.dart';

// ✅ TransactionItem 클래스
class TransactionItem {
  final String date;
  final String title;
  final String amount;
  final bool isIncome;
  final String category;
  final IconData icon;
  final DateTime? createdAt;
  final String? id;
  final String? bundleId;

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
  bool _isSaving = false;

  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.transaction.category;
  }

  // ══════════════════════════════
  // 카테고리 변경 + API 호출
  // ══════════════════════════════
  Future<void> _onCategoryChanged(String newCategory, bool applyToAll) async {
    final prevCategory = _selectedCategory;

    setState(() {
      _selectedCategory = newCategory;
      _isSaving = true;
    });

    try {
      final entryId = widget.transaction.id;
      if (entryId == null) {
        // id 없으면 화면 반영만
        setState(() => _isSaving = false);
        return;
      }

      bool success;

      if (applyToAll) {
        // 동일 가게명 전체 변경: 목록 조회 후 병렬 PATCH
        final allEntries = await ApiService.getLedgerEntries();
        final sameTitle = (allEntries ?? [])
            .where((e) => e['description'] == widget.transaction.title)
            .toList();

        final results = await Future.wait(
          sameTitle.map((e) => ApiService.updateLedgerEntry(
                e['id'].toString(),
                category: newCategory,
              )),
        );
        success = results.every((r) => r == true);
      } else {
        // 단건 변경
        success = await ApiService.updateLedgerEntry(
          entryId,
          category: newCategory,
        );
      }

      if (!success && mounted) {
        // 실패 시 원복
        setState(() => _selectedCategory = prevCategory);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카테고리 변경에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _selectedCategory = prevCategory);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카테고리 변경 중 오류가 발생했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
              // 3. 상세 정보
              // ══════════════════════════════
              _buildSimpleRow('주문금액', widget.transaction.amount, colors),
              _buildDivider(colors),

              // 카테고리 (> 화살표 + API 연동)
              _buildArrowRow(
                '카테고리 설정',
                _selectedCategory,
                colors,
                onTap: _isSaving
                    ? null
                    : () async {
                        final result =
                            await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategorySelectScreen(
                              currentCategory: _selectedCategory,
                              showChangeDialog: true,
                            ),
                          ),
                        );

                        if (result != null && mounted) {
                          final newCategory = result['category'] as String;
                          final applyToAll =
                              result['applyToAll'] as bool? ?? false;
                          await _onCategoryChanged(newCategory, applyToAll);
                        }
                      },
              ),
              _buildDivider(colors),

              // 메모
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
              // 4. 결제 정보
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

  Widget _buildSimpleRow(String label, String value, ThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 15, color: colors.primaryText)),
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
            Text(label,
                style: TextStyle(fontSize: 15, color: colors.primaryText)),
            Row(
              children: [
                if (_isSaving)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: colors.subText,
                    ),
                  )
                else
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
            Text('메모',
                style: TextStyle(fontSize: 15, color: colors.primaryText)),
            Row(
              children: [
                Text(
                  '메모를 남겨보세요',
                  style: TextStyle(
                    fontSize: 15,
                    color: colors.accent,
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

  Widget _buildSwitchRow(ThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('지출 합계에 포함',
              style: TextStyle(fontSize: 15, color: colors.primaryText)),
          Switch(
            value: _includeInTotal,
            onChanged: (value) => setState(() => _includeInTotal = value),
            activeThumbColor: Colors.white,
            activeTrackColor: colors.accent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: colors.cardBackground,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(ThemeColors colors) {
    return Divider(
      color: colors.primaryText.withValues(alpha: 0.08),
      thickness: 1,
      height: 1,
    );
  }
}
