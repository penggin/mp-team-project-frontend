import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 진화 레벨별 사용할 영상 에셋
String evolutionVideoAsset(int newLevel) {
  if (newLevel >= 10) return 'assets/evo_bluewhale.mp4'; // 파란 고래 → 범고래
  return 'assets/evo_dolphin.mp4';                        // 돌고래 → 파란 고래
}

class EvolutionScreen extends StatefulWidget {
  final String newCharacterAsset; // 진화 후 캐릭터 idle 영상
  final int newLevel;
  final VoidCallback onComplete;

  const EvolutionScreen({
    super.key,
    required this.newCharacterAsset,
    required this.newLevel,
    required this.onComplete,
  });

  @override
  State<EvolutionScreen> createState() => _EvolutionScreenState();
}

class _EvolutionScreenState extends State<EvolutionScreen>
    with TickerProviderStateMixin {
  // 진화 장면 영상 (evo_dolphin / evo_bluewhale)
  late VideoPlayerController _evoController;
  // 황금 링 오버레이 영상 (evolution_effect)
  late VideoPlayerController _fxController;

  late AnimationController _glowController;
  late AnimationController _textController;
  late Animation<double> _glowAnim;
  late Animation<double> _textFadeAnim;
  late Animation<double> _textScaleAnim;

  bool _evoReady = false;
  bool _fxReady = false;
  bool _showText = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();

    // 황금빛 맥동 글로우
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.1, end: 0.35).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // "진화!" 텍스트
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textScaleAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.elasticOut),
    );

    // 진화 장면 영상 로드
    _evoController = VideoPlayerController.asset(
      evolutionVideoAsset(widget.newLevel),
    )..initialize().then((_) {
        if (!mounted) return;
        setState(() => _evoReady = true);
        _evoController.setVolume(0);
        _evoController.play();

        // 1.2초 후 "진화!" 텍스트 표시
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (!mounted) return;
          setState(() => _showText = true);
          _textController.forward();
        });

        // 진화 장면 영상 끝나면 완료
        _evoController.addListener(_checkEvoDone);
      });

    // 황금 링 오버레이 영상 로드
    _fxController = VideoPlayerController.asset('assets/evolution_effect.mp4')
      ..initialize().then((_) {
          if (!mounted) return;
          setState(() => _fxReady = true);
          _fxController.setVolume(0);
          _fxController.play();
        });
  }

  void _checkEvoDone() {
    if (_finished) return;
    final pos = _evoController.value.position;
    final dur = _evoController.value.duration;
    if (dur > Duration.zero && pos >= dur - const Duration(milliseconds: 150)) {
      _finish();
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _evoController.removeListener(_checkEvoDone);
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onComplete();
  }

  @override
  void dispose() {
    _evoController.removeListener(_checkEvoDone);
    _evoController.dispose();
    _fxController.dispose();
    _glowController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 진화 장면 영상 (배경)
          if (_evoReady)
            VideoPlayer(_evoController),

          // 2. 황금 링 오버레이 영상
          if (_fxReady)
            Opacity(
              opacity: 0.6,
              child: VideoPlayer(_fxController),
            ),

          // 3. 황금빛 맥동 글로우
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (context, child) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Colors.amber.withValues(alpha: _glowAnim.value),
                    Colors.orange.withValues(alpha: _glowAnim.value * 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 4. "진화!" 텍스트
          if (_showText)
            Center(
              child: AnimatedBuilder(
                animation: _textController,
                builder: (context, child) => Opacity(
                  opacity: _textFadeAnim.value,
                  child: Transform.scale(
                    scale: _textScaleAnim.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '진화!',
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.amber.withValues(alpha: 0.9),
                                blurRadius: 30,
                              ),
                              Shadow(
                                color: Colors.orange.withValues(alpha: 0.6),
                                blurRadius: 60,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _newCharacterLabel(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade200,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 5. 탭하면 스킵
          GestureDetector(
            onTap: _finish,
            behavior: HitTestBehavior.translucent,
          ),

          Positioned(
            bottom: 40,
            right: 24,
            child: Text(
              '탭하여 건너뛰기',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _newCharacterLabel() {
    if (widget.newLevel >= 10) return '최종 진화형  범고래';
    if (widget.newLevel >= 5) return '2차 진화형  파란 고래';
    return '초기형  돌고래';
  }
}
