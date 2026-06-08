import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 진화 레벨별 사용할 영상 에셋
String evolutionVideoAsset(int newLevel, {String? species}) {
  switch (species) {
    case 'horse':
      if (newLevel >= 10) return 'assets/evo_unicon.mp4';
      return 'assets/evo_horse.mp4';
    case 'parrot':
      if (newLevel >= 10) return 'assets/evo_final_parrot.mp4';
      return 'assets/evo_parrot.mp4';
    case 'dolphin':
    default:
      if (newLevel >= 10) return 'assets/evo_bluewhale.mp4';
      return 'assets/evo_dolphin.mp4';
  }
}

class EvolutionScreen extends StatefulWidget {
  final String newCharacterAsset;
  final int newLevel;
  final String? species;
  final VoidCallback onComplete;

  const EvolutionScreen({
    super.key,
    required this.newCharacterAsset,
    required this.newLevel,
    this.species,
    required this.onComplete,
  });

  @override
  State<EvolutionScreen> createState() => _EvolutionScreenState();
}

class _EvolutionScreenState extends State<EvolutionScreen> {
  late VideoPlayerController _evoController;

  bool _evoReady = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();

    _evoController = VideoPlayerController.asset(
      evolutionVideoAsset(widget.newLevel, species: widget.species),
    )..initialize().then((_) {
        if (!mounted) return;
        setState(() => _evoReady = true);
        _evoController.setVolume(1.0);
        _evoController.play();
        _evoController.addListener(_checkEvoDone);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 진화 영상 (원본 비율 유지)
          if (_evoReady)
            Center(
              child: AspectRatio(
                aspectRatio: _evoController.value.aspectRatio,
                child: VideoPlayer(_evoController),
              ),
            ),

          // 탭하면 스킵
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
}
