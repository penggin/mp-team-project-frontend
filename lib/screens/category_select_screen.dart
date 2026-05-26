import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';

class CategorySelectScreen extends StatefulWidget {
  final String currentCategory;
  final bool showChangeDialog;

  const CategorySelectScreen({
    super.key,
    required this.currentCategory,
    this.showChangeDialog = false,
  });

  @override
  State<CategorySelectScreen> createState() => _CategorySelectScreenState();
}

class _CategorySelectScreenState extends State<CategorySelectScreen> {
  final List<Map<String, dynamic>> _categories = [
    {'name': '식비', 'color': const Color(0xFFFFB3B3)},
    {'name': '카페', 'color': const Color(0xFFFFCC99)},
    {'name': '쇼핑, 여가', 'color': const Color(0xFFFFE599)},
    {'name': '여행, 숙박', 'color': const Color(0xFFB3FFB3)},
    {'name': '계좌이체', 'color': const Color(0xFFB3D9FF)},
    {'name': '의료, 건강', 'color': const Color(0xFFD9B3FF)},
    {'name': '편의점, 마트, 잡화', 'color': const Color(0xFFFFB3E6)},
    {'name': '교통비', 'color': const Color(0xFFB3FFFF)},
    {'name': '학원', 'color': const Color(0xFFFFD9B3)},
  ];

  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.currentCategory;
  }

  void _onCategoryTap(String categoryName) {
    setState(() {
      _selectedCategory = categoryName;
    });

    if (widget.showChangeDialog) {
      _showChangeConfirmSheet(categoryName);
    } else {
      Navigator.pop(context, categoryName);
    }
  }

  void _showChangeConfirmSheet(String categoryName) {
    final colors = context.read<ThemeProvider>().colors;

    bool applyToAll = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '카테고리를 변경합니다',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  InkWell(
                    onTap: () {
                      setModalState(() {
                        applyToAll = !applyToAll;
                      });
                    },
                    child: Row(
                      children: [
                        Checkbox(
                          value: applyToAll,
                          activeColor: colors.accent,
                          onChanged: (value) {
                            setModalState(() {
                              applyToAll = value ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: Text(
                            '동일 결제 이력의 카테고리를 변경하시겠습니까?',
                            style: TextStyle(
                              fontSize: 15,
                              color: colors.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);

                        Navigator.pop(
                          this.context,
                          {
                            'category': categoryName,
                            'applyToAll': applyToAll,
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.cardBackground,
                        foregroundColor: colors.primaryText,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = widget.currentCategory;
                      });

                      Navigator.pop(context);
                    },
                    child: Text(
                      '취소',
                      style: TextStyle(
                        color: colors.subText,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCategoryDialog() {
    final colors = context.read<ThemeProvider>().colors;

    final controller = TextEditingController();
    Color selectedColor = const Color(0xFFFFB3B3);

    final colorOptions = [
      const Color(0xFFFFB3B3),
      const Color(0xFFFFCC99),
      const Color(0xFFFFE599),
      const Color(0xFFB3FFB3),
      const Color(0xFFB3D9FF),
      const Color(0xFFD9B3FF),
      const Color(0xFFFFB3E6),
      const Color(0xFFB3FFFF),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '카테고리 추가',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: '카테고리 이름',
                        filled: true,
                        fillColor: colors.cardBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      '색상 선택',
                      style: TextStyle(
                        color: colors.primaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 10,
                      children: colorOptions.map((color) {
                        final isSelected = selectedColor == color;

                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                color: colors.primaryText,
                                width: 2.5,
                              )
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          final name = controller.text.trim();

                          if (name.isEmpty) return;

                          setState(() {
                            _categories.add({
                              'name': name,
                              'color': selectedColor,
                            });
                          });

                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.cardBackground,
                          foregroundColor: colors.primaryText,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '추가',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
          icon: Icon(
            Icons.arrow_back,
            color: colors.primaryText,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '카테고리를 선택해주세요',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: ListView.separated(
                itemCount: _categories.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _categories[index];
                  final isSelected =
                      _selectedCategory == item['name'];

                  return GestureDetector(
                    onTap: () => _onCategoryTap(item['name']),
                    child: Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: colors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: item['color'],
                              shape: BoxShape.circle,
                            ),
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Text(
                              item['name'],
                              style: TextStyle(
                                fontSize: 15,
                                color: colors.primaryText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            color: isSelected
                                ? colors.primaryText
                                : colors.accent.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            GestureDetector(
              onTap: _showAddCategoryDialog,
              child: Container(
                width: double.infinity,
                height: 56,
                margin: const EdgeInsets.only(bottom: 30),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '카테고리 추가',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.primaryText,
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