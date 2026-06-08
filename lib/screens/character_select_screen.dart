import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_colors.dart';
import '../services/api_service.dart';
import 'main_screen.dart';

class CharacterSelectScreen extends StatefulWidget {
  const CharacterSelectScreen({super.key});

  @override
  State<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends State<CharacterSelectScreen> {
  int? _selectedIndex;
  bool _isLoading = false;

  final List<_CharacterOption> _characters = [
    _CharacterOption(
      name: '말',
      imagePath: 'assets/horse.png',
      species: 'horse',
      enabled: true,
    ),
    _CharacterOption(
      name: '돌고래',
      imagePath: 'assets/dolphin.png',
      species: 'dolphin',
      enabled: true,
    ),
    _CharacterOption(
      name: '앵무새',
      imagePath: 'assets/parrot.png',
      species: 'parrot',
      enabled: true,
    ),
  ];

  Future<void> _onConfirm() async {
    if (_selectedIndex == null) return;
    final character = _characters[_selectedIndex!];
    if (!character.enabled) return;

    setState(() => _isLoading = true);

    await ApiService.updatePetInfo(species: character.species);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_first_login');

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MainScreen(key: MainScreen.globalKey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.colors;
        return Scaffold(
          backgroundColor: colors.cardBackground,
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                Text(
                  '함께할 친구들을\n선택해주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryText,
                    height: 1.4,
                  ),
                ),
                const Spacer(),
                // 캐릭터 카드 — 화면 세로 중앙
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(_characters.length, (i) {
                      final char = _characters[i];
                      final isSelected = _selectedIndex == i;
                      return _CharacterCard(
                        character: char,
                        isSelected: isSelected,
                        accentColor: colors.accent,
                        primaryColor: colors.primaryText,
                        onTap: char.enabled
                            ? () => setState(() => _selectedIndex = i)
                            : null,
                      );
                    }),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                  child: ElevatedButton(
                    onPressed: (_selectedIndex != null && !_isLoading)
                        ? _onConfirm
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: colors.accent.withOpacity(0.4),
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                        : Text(
                      '선택했어요',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
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
  }
}

class _CharacterOption {
  final String name;
  final String imagePath;
  final String species;
  final bool enabled;

  const _CharacterOption({
    required this.name,
    required this.imagePath,
    required this.species,
    required this.enabled,
  });
}

class _CharacterCard extends StatelessWidget {
  final _CharacterOption character;
  final bool isSelected;
  final Color accentColor;
  final Color primaryColor;
  final VoidCallback? onTap;

  const _CharacterCard({
    required this.character,
    required this.isSelected,
    required this.accentColor,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: (MediaQuery.of(context).size.width - 64) / 3,
        height: (MediaQuery.of(context).size.width - 64) / 3 * 1.4,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: accentColor, width: 3)
              : Border.all(color: Colors.transparent, width: 3),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? accentColor.withOpacity(0.4)
                  : Colors.black.withOpacity(0.07),
              blurRadius: isSelected ? 14 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                    child: Image.asset(
                      character.imagePath,
                      fit: BoxFit.contain,
                      color: character.enabled ? null : Colors.grey,
                      colorBlendMode:
                      character.enabled ? null : BlendMode.saturation,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    character.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: character.enabled
                          ? primaryColor
                          : Colors.grey.shade400,
                    ),
                  ),
                ),
              ],
            ),
            if (!character.enabled)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '준비 중',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
