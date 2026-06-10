import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';
import '../services/category_mapper.dart';

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
  static const Map<String, Color> _categoryColors = {
    'cafe': Color(0xFFFFCC99),
    'food': Color(0xFFFFB3B3),
    'shopping': Color(0xFFFFE599),
    'transport': Color(0xFFB3FFFF),
    'telecommunications': Color(0xFFB3D9FF),
    'education': Color(0xFFB3FFD9),
    'transfer_in': Color(0xFFA5D6A7),
    'transfer_out': Color(0xFFFFAB91),
    'others': Color(0xFFD9B3FF),
  };

  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = CategoryMapper.toDisplay(widget.currentCategory);
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
                        Navigator.pop(this.context, {
                          'category': categoryName,
                          'applyToAll': applyToAll,
                        });
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
                    child: Text('취소', style: TextStyle(color: colors.subText)),
                  ),
                ],
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
    final categories = CategoryMapper.paymentCategoryOptions;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primaryText),
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
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = categories[index];
                  final isSelected = _selectedCategory == item.label;

                  return GestureDetector(
                    onTap: () => _onCategoryTap(item.label),
                    child: Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                              color: _categoryColors[item.value] ??
                                  const Color(0xFFBDBDBD),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              item.label,
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
                                : colors.accent.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
