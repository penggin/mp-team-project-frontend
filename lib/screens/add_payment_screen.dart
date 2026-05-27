import 'package:flutter/material.dart';
import 'individual_payment_screen.dart';
import 'category_select_screen.dart';
import '../services/api_service.dart';
import '../services/category_mapper.dart';
import '../services/experience_service.dart';
import 'budget_alert_dialog.dart';
import 'main_screen.dart';

class AddPaymentScreen extends StatefulWidget {
  final Function(TransactionItem) onAdd;

  const AddPaymentScreen({super.key, required this.onAdd});

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  bool isIncome = false;
  bool _isSaving = false;

  final TextEditingController amountController = TextEditingController();
  final TextEditingController titleController = TextEditingController();

  String selectedCategory = CategoryMapper.othersDisplay;

  @override
  void dispose() {
    amountController.dispose();
    titleController.dispose();
    super.dispose();
  }

  Future<void> _savePayment() async {
    if (_isSaving) return;

    final rawAmount = amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(rawAmount);
    final title = titleController.text.trim();

    if (amount == null || amount <= 0 || title.isEmpty) return;

    setState(() => _isSaving = true);
    final saved = await ApiService.createManualLedgerEntry(
      amount: amount,
      type: isIncome ? 'income' : 'expense',
      category: selectedCategory,
      merchantName: title,
      transactionAt: DateTime.now(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('내역 저장에 실패했습니다')));
      return;
    }

    final formatted = rawAmount.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );

    final item = TransactionItem(
      date: '${DateTime.now().month}.${DateTime.now().day}',
      title: title,
      amount: '${isIncome ? '+' : '-'}$formatted 원',
      isIncome: isIncome,
      category: selectedCategory,
      icon: isIncome ? Icons.account_balance_wallet : Icons.shopping_bag,
    );

    widget.onAdd(item);
    Navigator.pop(context, true);
    if (!isIncome) {
      final rootContext = MainScreen.globalKey.currentContext;
      if (rootContext != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkBudgetAfterAdd(rootContext, amount);
        });
      }
    }
  }

  /// 결제 추가 후 하루 예산 초과 여부를 체크—창이 이미 닫혀서 BuildContext는 원래 화면의 것을 사용
  Future<void> _checkBudgetAfterAdd(BuildContext ctx, int addedAmount) async {
    // 오늘 지출 기록 업데이트 (현지에서 정확한 합계를 알 수 없으므로 개산)
    final prefs = await _getSpendFromPrefs();
    final newTotal = prefs + addedAmount;
    await ExperienceService.recordTodaySpend(newTotal);

    final exceeded = await ExperienceService.checkDailyBudgetExceeded(newTotal);
    if (!exceeded) return;

    // 다시 마운트되어 있는 상위 컨텍스트가 필요
    if (!ctx.mounted) return;
    BudgetAlertDialog.show(
      ctx,
      onGoToHistory: () {
        MainScreen.globalKey.currentState?.changeTab(1);
      },
    );
  }

  Future<int> _getSpendFromPrefs() async {
    // ExperienceService의 오늘 지출 기록을 읽어온다
    final spend = await ExperienceService.getTodayRecordedSpend();
    return spend;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF8F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF7A1C1C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isIncome ? '입금 추가' : '출금 추가',
          style: const TextStyle(
            color: Color(0xFF7A1C1C),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // 스위치
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFF8DCDC),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          isIncome = false;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: !isIncome ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: Text(
                            '지출',
                            style: TextStyle(
                              color: const Color(0xFF7A1C1C),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          isIncome = true;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isIncome ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: Text(
                            '입금',
                            style: TextStyle(
                              color: const Color(0xFF7A1C1C),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            Text(
              '금액을 입력하세요',
              style: TextStyle(color: Color(0xFF7A1C1C), fontSize: 16),
            ),

            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '0원'),
            ),

            const SizedBox(height: 40),

            Text(
              isIncome ? '입금처를 입력하세요' : '지출처를 입력하세요',
              style: const TextStyle(color: Color(0xFF7A1C1C), fontSize: 16),
            ),

            TextField(controller: titleController),

            const SizedBox(height: 40),

            // 기존 DropdownButton 부분을 아래로 교체
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '카테고리 선택',
                  style: TextStyle(color: Color(0xFF7A1C1C), fontSize: 16),
                ),
                GestureDetector(
                  onTap: () async {
                    // ✅ 카테고리 선택 화면으로 이동
                    final result = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategorySelectScreen(
                          currentCategory: selectedCategory,
                          showChangeDialog: false, // 추가 화면에서는 팝업 없음
                        ),
                      ),
                    );
                    if (result != null) {
                      setState(() => selectedCategory = result);
                    }
                  },
                  child: Row(
                    children: [
                      Text(
                        selectedCategory,
                        style: const TextStyle(
                          color: Color(0xFF7A1C1C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF7A1C1C)),
                    ],
                  ),
                ),
              ],
            ),

            const Spacer(),

            GestureDetector(
              onTap: _savePayment,
              child: Container(
                height: 56,
                margin: const EdgeInsets.only(bottom: 40),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8DCDC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    _isSaving ? '저장 중...' : '추가하기',
                    style: TextStyle(
                      color: Color(0xFF7A1C1C),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
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
