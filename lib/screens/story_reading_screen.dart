import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/story_provider.dart';
import '../models/story.dart';
import 'settings_screen.dart';
import '../services/audio_player_service.dart';
import '../services/azure_tts_service.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/rendering.dart';

class StoryReadingScreen extends StatefulWidget {
  final Story story;
  const StoryReadingScreen({super.key, required this.story});

  @override
  State<StoryReadingScreen> createState() => _StoryReadingScreenState();
}

class _StoryReadingScreenState extends State<StoryReadingScreen> {
  int _currentVisemeId = 0; // 립싱크 neutral
  int _currentPage = 0;
  bool _isPlaying = false;
  late List<String> _pages;
  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  final AzureTTSService _ttsService = AzureTTSService();
  List<String>? _currentPageSentences;
  bool _isTtsPlaying = false;

  @override
  void initState() {
    super.initState();
    final initialContent = widget.story.adaptedScript ?? widget.story.content;
    _pages = [initialContent];
    _currentPageSentences = _splitPageIntoSentences(_pages[_currentPage]);
    _currentVisemeId = 0; // neutral
  }
  // viseme 이미지 파일명 매핑 (viseme.md 참조)
  static const Map<int, String> visemeFileMap = {
    0: 'viseme_00_neutral.png',
    1: 'viseme_01_bmp.png',
    2: 'viseme_02_ai.png',
    3: 'viseme_03_eh.png',
    4: 'viseme_04_aa.png',
    5: 'viseme_05_ah.png',
    6: 'viseme_06_ao.png',
    7: 'viseme_07_uw.png',
    8: 'viseme_08_oy.png',
    9: 'viseme_09_sz.png',
    10: 'viseme_10_ch.png',
    11: 'viseme_11_lr.png',
    12: 'viseme_12_fv.png',
  };

  String getLipSyncCharacterImage(String gender) {
    return gender == 'male' ? 'assets/images/MH_lip_ani.png' : 'assets/images/SY_lip_ani.png';
  }
  String getVisemeFolder(String gender) {
    return gender == 'male' ? 'assets/images/MH_viseme/' : 'assets/images/SY_viseme/';
  }

  List<String> _splitPageIntoSentences(String pageContent) {
    return pageContent
        .split(RegExp(r'[\n\r]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  // 실제 텍스트 박스 크기에 맞춰 페이지네이션
  List<String> paginateTextByBox({
    required String text,
    required double boxWidth,
    required double boxHeight,
    required TextStyle style,
  }) {
    final lines = text.split(RegExp(r'[\n\r]+')).map((s) => s.trim()).toList();
    final List<String> pages = [];
    String current = '';
    for (int i = 0; i < lines.length; i++) {
      final test = current.isEmpty ? lines[i] : current + '\n' + lines[i];
      final tp = TextPainter(
        text: TextSpan(text: test, style: style),
        textDirection: TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: boxWidth);
      if (tp.height > boxHeight && current.isNotEmpty) {
        pages.add(current);
        current = lines[i];
      } else {
        current = test;
      }
    }
    if (current.isNotEmpty) pages.add(current);
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    // 텍스트 박스 크기 측정용
    final screenWidth = MediaQuery.of(context).size.width;
    final boxWidth = screenWidth * 0.8;
    final boxHeight = 400.0;
    final textStyle = const TextStyle(
      fontSize: 20,
      height: 1.8,
      color: Color(0xFF333333),
      fontWeight: FontWeight.w500,
    );
    // 페이지네이션 동적 적용
    final initialContent = widget.story.adaptedScript ?? widget.story.content;
    _pages = paginateTextByBox(
      text: initialContent,
      boxWidth: boxWidth,
      boxHeight: boxHeight,
      style: textStyle,
    );
    if (_currentPage >= _pages.length) {
      _currentPage = _pages.length - 1;
    }
    _currentPageSentences = _splitPageIntoSentences(_pages[_currentPage]);

    final provider = Provider.of<StoryProvider>(context, listen: false);
    final gender = provider.settings.gender;
    return Scaffold(
      backgroundColor: const Color(0xFF7665FF),
      body: Container(
        color: const Color(0xFF7665FF),
        child: Stack(
          children: [
            // 설정 버튼
            Positioned(
              top: 60,
              left: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text(
                    '설정 Setting',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            // 닫기 버튼
            Positioned(
              top: 60,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // 메인 컨텐츠
            Consumer<StoryProvider>(
              builder: (context, provider, child) {
                final screenWidth = MediaQuery.of(context).size.width;
                // 립싱크 애니메이션: 캐릭터 + viseme 이미지 스와핑
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 110),
                      // 캐릭터 이미지 + 립싱크 viseme 오버레이
                      Stack(
                        children: [
                          Container(
                            width: 360,
                            height: 360,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5E6D3),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.asset(
                                getLipSyncCharacterImage(gender),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.person, size: 120, color: Color(0xFF7C4DFF));
                                },
                              ),
                            ),
                          ),
                          // 립싱크 viseme 이미지 (스와핑)
                          // 캐릭터 박스 크기에 따라 viseme 위치 자동 조정
                          Builder(
                            builder: (context) {
                              // 박스 크기
                              double characterBoxWidth = 360;
                              double characterBoxHeight = 360;
                              // 원본 기준 좌표
                              const double baseX = 430;
                              const double baseY = 453;
                              const double baseWidth = 1024;
                              const double baseHeight = 1024;
                              // 실제 위치 계산
                              double visemeX = baseX * (characterBoxWidth / baseWidth);
                              double visemeY = baseY * (characterBoxHeight / baseHeight);
                              // viseme 이미지 크기를 캐릭터 박스 비율에 맞게 자동 조정
                              // viseme 이미지 크기를 캐릭터 박스 비율에 맞게 자동 조정
                              const double visemeBaseWidth = 135;
                              const double visemeBaseHeight = 104;
                              double visemeWidth = visemeBaseWidth * (characterBoxWidth / baseWidth);
                              double visemeHeight = visemeBaseHeight * (characterBoxHeight / baseHeight);
                              return Positioned(
                                left: visemeX,
                                top: visemeY,
                                child: Image.asset(
                                  getVisemeFolder(gender) + visemeFileMap[_currentVisemeId]!,
                                  width: visemeWidth,
                                  height: visemeHeight,
                                  fit: BoxFit.contain,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      // 텍스트 박스
                      Container(
                        width: boxWidth,
                        height: boxHeight,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Text(
                          _pages[_currentPage],
                          style: textStyle,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 페이지 번호
                      Text(
                        '${_currentPage + 1}/${_pages.length}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 30),
                      // 컨트롤 버튼
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildControlButton(
                              '이전\nPrevious',
                              Icons.skip_previous,
                              _currentPage > 0,
                              () async {
                                if (_currentPage > 0) {
                                  await _stopAllAudio();
                                  setState(() {
                                    _currentPage--;
                                    _isPlaying = false;
                                    _isTtsPlaying = false;
                                    _currentPageSentences = _splitPageIntoSentences(_pages[_currentPage]);
                                  });
                                }
                              },
                              false,
                            ),
                            const SizedBox(width: 15),
                            _buildControlButton(
                              _isPlaying ? '멈춤\nPause' : '실행\nPlay',
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              true,
                              () async {
                                if (_isPlaying || _isTtsPlaying) {
                                  await _stopAllAudio();
                                } else {
                                  await _playCurrentPageTTS(context);
                                }
                              },
                              true,
                            ),
                            const SizedBox(width: 15),
                            _buildControlButton(
                              '다음\nNext',
                              Icons.skip_next,
                              _currentPage < _pages.length - 1 && !_isPlaying,
                              () async {
                                if (_currentPage < _pages.length - 1 && !_isPlaying && !_isTtsPlaying) {
                                  await _stopAllAudio();
                                  setState(() {
                                    _currentPage++;
                                    _currentPageSentences = _splitPageIntoSentences(_pages[_currentPage]);
                                  });
                                }
                              },
                              false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                );
              },
            ),
            // 홈 버튼
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: FloatingActionButton(
                  onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                  backgroundColor: const Color(0xFF5E35B1),
                  child: const Icon(Icons.home, color: Colors.white, size: 32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(
    String label,
    IconData icon,
    bool enabled,
    VoidCallback onPressed,
    bool isPrimary,
  ) {
    final parts = label.split('\n');
    final koreanText = parts.isNotEmpty ? parts[0] : '';
    final englishText = parts.length > 1 ? parts[1] : '';
    return SizedBox(
      width: 170,
      height: 56,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? const Color(0xFF5E35B1) : const Color(0xFFACA2FF),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[600],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: enabled ? 4 : 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              koreanText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (englishText.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                englishText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // TTS에서 viseme id를 받아 이미지 스와핑 (예시: 랜덤 스와핑, 실제 구현은 TTS viseme 이벤트와 연동 필요)
  Future<void> _playCurrentPageTTS(BuildContext context) async {
    final provider = Provider.of<StoryProvider>(context, listen: false);
    final sentences = _currentPageSentences ?? _splitPageIntoSentences(_pages[_currentPage]);
    if (sentences.isEmpty) return;
    setState(() {
      _isTtsPlaying = true;
      _isPlaying = true;
    });
    try {
      for (final sentence in sentences) {
        if (!_isTtsPlaying) break;
        final audioPath = await _ttsService.generateAudio(
          text: sentence,
          language: provider.settings.language,
          characterGender: provider.settings.gender,
          age: provider.settings.age,
        );
        final completer = Completer<void>();
        // 예시: TTS 재생 중 viseme id를 랜덤하게 스와핑 (실제는 TTS viseme 이벤트와 연동 필요)
        Timer.periodic(const Duration(milliseconds: 120), (timer) {
          if (!_isTtsPlaying) {
            timer.cancel();
            return;
          }
          setState(() {
            _currentVisemeId = Random().nextInt(13); // 0~12
          });
        });
        await _audioPlayerService.play(audioPath, onComplete: () {
          completer.complete();
        });
        setState(() {
          _currentVisemeId = 0; // TTS 끝나면 neutral
        });
        await completer.future;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('TTS 오류: $e'), duration: const Duration(seconds: 2)),
      );
    }
    setState(() {
      _isTtsPlaying = false;
      _isPlaying = false;
      _currentVisemeId = 0; // TTS 종료 시 neutral
    });
  }

  Future<void> _stopAllAudio() async {
    _isTtsPlaying = false;
    await _audioPlayerService.stop();
    setState(() {
      _isPlaying = false;
    });
  }
}
