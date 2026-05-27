import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';
import 'ledger_screen.dart';
import 'main_screen.dart';

// ══════════════════════════════════════════════════════════════
// AppDrawer — 앱 전역 슬라이드 드로어
// 사용법: Scaffold의 drawer: const AppDrawer() 로 연결
// ══════════════════════════════════════════════════════════════
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  // 드로어 닫힐 애니메이션 완료 후 탭 전환 (충돌 방지)
  void _navigate(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    Future.delayed(const Duration(milliseconds: 300), action);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.78,
      backgroundColor: colors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더: 닫기 버튼 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: colors.primaryText,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── 메뉴 목록 ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _tile(
                    context: context,
                    colors: colors,
                    label: '내 통계',
                    icon: Icons.bar_chart_outlined,
                    onTap: () => _navigate(context, () {
                      MainScreen.globalKey.currentState?.changeTab(3);
                    }),
                  ),
                  _tile(
                    context: context,
                    colors: colors,
                    label: '월간 결제 이력',
                    icon: Icons.calendar_month_outlined,
                    onTap: () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      Future.delayed(const Duration(milliseconds: 300), () {
                        navigator.push(
                          MaterialPageRoute(
                            builder: (_) => const LedgerScreenWrapper(),
                          ),
                        );
                      });
                    },
                  ),
                  _tile(
                    context: context,
                    colors: colors,
                    label: '전체 결제 내역',
                    icon: Icons.list_alt_outlined,
                    onTap: () => _navigate(context, () {
                      MainScreen.globalKey.currentState?.changeTab(1);
                    }),
                  ),
                  _tile(
                    context: context,
                    colors: colors,
                    label: '카테고리별 결제이력',
                    icon: Icons.pie_chart_outline,
                    onTap: () => _navigate(context, () {
                      MainScreen.globalKey.currentState?.changeTabWithRefresh(
                        4,
                      );
                    }),
                  ),
                  _tile(
                    context: context,
                    colors: colors,
                    label: '설정',
                    icon: Icons.settings_outlined,
                    onTap: () => _navigate(context, () {
                      MainScreen.globalKey.currentState?.changeTab(0);
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required BuildContext context,
    required ThemeColors colors,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: colors.primaryText.withValues(alpha: 0.06),
        highlightColor: colors.primaryText.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Icon(icon, color: colors.primaryText, size: 22),
              const SizedBox(width: 18),
              Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colors.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
