import 'dart:async';
import 'package:flutter/material.dart';

class VisemeDebugScreen extends StatefulWidget {
  const VisemeDebugScreen({super.key});

  @override
  State<VisemeDebugScreen> createState() => _VisemeDebugScreenState();
}

class _VisemeDebugScreenState extends State<VisemeDebugScreen> {
  static const List<String> _visemeAssets = [
    'assets/images/MH_viseme/viseme_00_neutral.png',
    'assets/images/MH_viseme/viseme_01_bmp.png',
    'assets/images/MH_viseme/viseme_02_ai.png',
    'assets/images/MH_viseme/viseme_03_eh.png',
    'assets/images/MH_viseme/viseme_04_aa.png',
    'assets/images/MH_viseme/viseme_05_ah.png',
    'assets/images/MH_viseme/viseme_06_ao.png',
    'assets/images/MH_viseme/viseme_07_uw.png',
    'assets/images/MH_viseme/viseme_08_oy.png',
    'assets/images/MH_viseme/viseme_09_sz.png',
    'assets/images/MH_viseme/viseme_10_ch.png',
    'assets/images/MH_viseme/viseme_11_lr.png',
    'assets/images/MH_viseme/viseme_12_fv.png',
  ];

  int _currentIndex = 0;
  Timer? _swapTimer;

  @override
  void initState() {
    super.initState();
    _swapTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _visemeAssets.length;
      });
    });
  }

  @override
  void dispose() {
    _swapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overlayAsset = _visemeAssets[_currentIndex];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Viseme Debug'),
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: 1.0,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final canvasSize = constraints.biggest.shortestSide;
              final visemeWidth = canvasSize * (135 / 1024);
              final visemeHeight = canvasSize * (88 / 1024);
              final visemeLeft = canvasSize * (432 / 1024);
              final visemeTop = canvasSize * (469 / 1024);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/MH_lip_ani.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    left: visemeLeft,
                    top: visemeTop,
                    width: visemeWidth,
                    height: visemeHeight,
                    child: Image.asset(
                      overlayAsset,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          'Viseme index: $_currentIndex\n${overlayAsset.split('/').last}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
