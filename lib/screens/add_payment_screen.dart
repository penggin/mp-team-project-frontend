import 'package:flutter/material.dart';
import 'category_payment_screen.dart';
import 'individual_payment_screen.dart'; // ✅ 추가
import '../app_colors.dart';
import 'category_select_screen.dart';

class AddPaymentScreen extends StatefulWidget {
  final Function(TransactionItem) onAdd;

  const AddPaymentScreen({
    super.key,
    required this.onAdd,
  });

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  bool isIncome = false;

  final TextEditingController amountController = TextEditingController();
  final TextEditingController titleController = TextEditingController();

  String selectedCategory = '카테고리 없음';

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
                          color: !isIncome
                              ? Colors.white
                              : Colors.transparent,
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
                          color: isIncome
                              ? Colors.white
                              : Colors.transparent,
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
              style: TextStyle(
                color: Color(0xFF7A1C1C),
                fontSize: 16,
              ),
            ),

            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '0원',
              ),
            ),

            const SizedBox(height: 40),

            Text(
              isIncome ? '입금처를 입력하세요' : '지출처를 입력하세요',
              style: const TextStyle(
                color: Color(0xFF7A1C1C),
                fontSize: 16,
              ),
            ),

            TextField(
              controller: titleController,
            ),

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
              onTap: () {
                final amount = amountController.text.trim();
                final title = titleController.text.trim();

                if (amount.isEmpty || title.isEmpty) return;

                final formatted =
                amount.replaceAllMapped(
                  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                      (m) => '${m[1]},',
                );

                final item = TransactionItem(
                  date: '${DateTime.now().month}.${DateTime.now().day}',
                  title: title,
                  amount:
                  '${isIncome ? '+' : '-'}$formatted 원',
                  isIncome: isIncome,
                  category: selectedCategory,
                  icon: isIncome
                      ? Icons.account_balance_wallet
                      : Icons.shopping_bag,
                );

                widget.onAdd(item);

                Navigator.pop(context);
              },
              child: Container(
                height: 56,
                margin: const EdgeInsets.only(bottom: 40),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8DCDC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    '추가하기',
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