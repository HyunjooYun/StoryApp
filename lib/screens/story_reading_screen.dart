import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/story_provider.dart';
import '../models/story.dart';
import 'settings_screen.dart';
import '../services/audio_player_service.dart';
import '../services/azure_tts_service.dart';
import 'dart:async';

class StoryReadingScreen extends StatefulWidget {
  final Story story;
  const StoryReadingScreen({super.key, required this.story});

  @override
  State<StoryReadingScreen> createState() => _StoryReadingScreenState();
}

class _StoryReadingScreenState extends State<StoryReadingScreen> {
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
    _pages = _splitContentIntoPages(initialContent);
    _currentPageSentences = _splitPageIntoSentences(_pages[_currentPage]);
  }

  List<String> _splitPageIntoSentences(String pageContent) {
    return pageContent
        .split(RegExp(r'[\n\r]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  List<String> _splitContentIntoPages(String content) {
    if (content.isEmpty) return [''];
    final sentences = content
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (sentences.isEmpty) return [''];
    const int estimatedCharsPerPage = 350;
    final pages = <String>[];
    String currentPage = '';
    for (var sentence in sentences) {
      final testPage = currentPage.isEmpty ? sentence : '$currentPage\n$sentence';
      if (testPage.length > estimatedCharsPerPage && currentPage.isNotEmpty) {
        pages.add(currentPage.trim());
        currentPage = sentence;
      } else {
        currentPage = testPage;
      }
    }
    if (currentPage.isNotEmpty) {
      pages.add(currentPage.trim());
    }
    return pages.isEmpty ? [''] : pages;
  }

  @override
  Widget build(BuildContext context) {
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
                final characterImage = provider.settings.getCharacterImage();
                final screenWidth = MediaQuery.of(context).size.width;
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 110),
                      // 캐릭터 이미지
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
                            characterImage,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.person, size: 120, color: Color(0xFF7C4DFF));
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // 텍스트 박스
                      Container(
                        width: screenWidth * 0.8,
                        height: 400,
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
                          style: const TextStyle(
                            fontSize: 20,
                            height: 1.8,
                            color: Color(0xFF333333),
                            fontWeight: FontWeight.w500,
                          ),
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
        await _audioPlayerService.play(audioPath, onComplete: () {
          completer.complete();
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
