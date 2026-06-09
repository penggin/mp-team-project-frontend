import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';

/// 하루 예산 초과 시 표시되는 비상 알림창
class BudgetAlertDialog extends StatefulWidget {
  /// 알림창에서 "그룹화를 해야합니다"를 체크했을 때 전체 결제 이력 화면으로 이동하는 콜백
  final VoidCallback onGoToHistory;

  /// "불필요한 금액입니다" 를 체크했을 때 호출 — 캐릭터 분노 리액션 등에 사용
  final VoidCallback? onWasteful;

  const BudgetAlertDialog({
    super.key,
    required this.onGoToHistory,
    this.onWasteful,
  });

  /// showDialog를 통해 간편하게 표시
  static Future<void> show(
    BuildContext context, {
    required VoidCallback onGoToHistory,
    VoidCallback? onWasteful,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BudgetAlertDialog(
        onGoToHistory: onGoToHistory,
        onWasteful: onWasteful,
      ),
    );
  }

  @override
  State<BudgetAlertDialog> createState() => _BudgetAlertDialogState();
}

class _BudgetAlertDialogState extends State<BudgetAlertDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _bellController;

  @override
  void initState() {
    super.initState();
    _bellController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bellController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: colors.background,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더 ──
            Row(
              children: [
                AnimatedBuilder(
                  animation: _bellController,
                  builder: (context, child) => Transform.rotate(
                    angle: (_bellController.value - 0.5) * 0.4,
                    child: Icon(
                      Icons.notifications_active,
                      color: colors.primaryText,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '비상!!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                    Text(
                      '예상치 못한 결제가 발생했습니다!',
                      style: TextStyle(fontSize: 12, color: colors.subText),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── 체크리스트 ──
            _AlertCheckItem(
              label: '그룹화를 해야합니다',
              isLink: true,
              colors: colors,
              onTap: () {
                Navigator.of(context).pop();
                widget.onGoToHistory();
              },
            ),
            _AlertCheckItem(
              label: '주에 한 번 필요한 금액입니다',
              colors: colors,
              onTap: () => Navigator.of(context).pop(),
            ),
            _AlertCheckItem(
              label: '달에 한 번 필요한 금액입니다',
              colors: colors,
              onTap: () => Navigator.of(context).pop(),
            ),
            _AlertCheckItem(
              label: '년에 한 번 필요한 금액입니다',
              colors: colors,
              onTap: () => Navigator.of(context).pop(),
            ),
            _AlertCheckItem(
              label: '불필요한 금액입니다',
              colors: colors,
              onTap: () {
                Navigator.of(context).pop();
                widget.onWasteful?.call();
              },
            ),
            _AlertCheckItem(
              label: '제외해야할 금액입니다',
              colors: colors,
              onTap: () => Navigator.of(context).pop(),
            ),

            const SizedBox(height: 20),

            // ── 확인 버튼 ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.cardBackground,
                  foregroundColor: colors.primaryText,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  '확인',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: colors.primaryText,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 알림창 내 체크 항목 하나
class _AlertCheckItem extends StatefulWidget {
  final String label;
  final bool isLink;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _AlertCheckItem({
    required this.label,
    required this.colors,
    required this.onTap,
    this.isLink = false,
  });

  @override
  State<_AlertCheckItem> createState() => _AlertCheckItemState();
}

class _AlertCheckItemState extends State<_AlertCheckItem> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _checked = true);
        // 살짝 딜레이 후 콜백 실행 (체크 애니메이션이 보이도록)
        Future.delayed(const Duration(milliseconds: 150), widget.onTap);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _checked
                    ? widget.colors.primaryText
                    : Colors.transparent,
                border: Border.all(
                  color: _checked
                      ? widget.colors.primaryText
                      : widget.colors.subText,
                  width: 1.8,
                ),
              ),
              child: _checked
                  ? Icon(Icons.check, size: 13, color: widget.colors.background)
                  : null,
            ),
            const SizedBox(width: 12),
            widget.isLink
                ? Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.colors.primaryText,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.colors.primaryText,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
