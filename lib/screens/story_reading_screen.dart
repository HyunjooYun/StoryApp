import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/story_provider.dart';
import '../models/story.dart';
import 'settings_screen.dart';
import '../services/audio_player_service.dart';

class StoryReadingScreen extends StatefulWidget {
  final Story story;
  
  const StoryReadingScreen({
    super.key,
    required this.story,
  });

  @override
  State<StoryReadingScreen> createState() => _StoryReadingScreenState();
}

class _StoryReadingScreenState extends State<StoryReadingScreen> {
  int _currentPage = 0;
  bool _isPlaying = false;
  late List<String> _pages;
  List<String>? _audioPaths;
  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  
  @override
  void initState() {
    super.initState();
    // Initialize pages from story's adapted script or original content
    final initialContent = widget.story.adaptedScript ?? widget.story.content;
    _pages = _splitContentIntoPages(initialContent);
    _audioPaths = widget.story.audioPaths;
  }
  
  List<String> _splitContentIntoPages(String content) {
    if (content.isEmpty) return [''];
    
    // Split by newline for sentence-by-sentence display
    final sentences = content
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    
    if (sentences.isEmpty) return [''];
    
    // Estimate character limit per page based on text box size
    // Text box height: 400px (fixed)
    // Padding: 24px * 2 = 48px, Available height: ~352px
    // Font size: 20, line height: 1.8 = 36px per line
    // Available lines: ~9-10 lines
    // Characters per line: ~35 (considering Korean characters and line breaks)
    // Total chars per page: ~350
    const int estimatedCharsPerPage = 350;
    
    final pages = <String>[];
    String currentPage = '';
    
    for (var sentence in sentences) {
      final testPage = currentPage.isEmpty 
          ? sentence 
          : '$currentPage\n$sentence';
      
      // Check if adding this sentence exceeds the page limit
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
              // Settings button
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Close button
              Positioned(
                top: 60,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              
              // Main content
              Consumer<StoryProvider>(
                builder: (context, provider, child) {
                  final characterImage = provider.settings.getCharacterImage();
                  final screenWidth = MediaQuery.of(context).size.width;
                  
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 110), // 80 + 30 = 110
                        
                        // Character image (120% size: 360x360)
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
                        
                        const SizedBox(height: 30), // 캐릭터 이미지 아래 여백
                        
                        // Text content box (fixed size: 80% width, 400px height)
                        Container(
                          width: screenWidth * 0.8, // 80% of screen width
                          height: 400, // Fixed 400px height
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
                      
                      const SizedBox(height: 20), // 텍스트 박스 아래 여백
                      
                      // Page number only (no slider)
                      Text(
                        '${_currentPage + 1}/${_pages.length}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      
                      const SizedBox(height: 30), // 페이지 번호 아래 여백
                      
                      // Control buttons
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
                                  await _audioPlayerService.stop();
                                  setState(() {
                                    _currentPage--;
                                    _isPlaying = false;
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
                                if (_isPlaying) {
                                  await _stopPlaying(Provider.of<StoryProvider>(context, listen: false));
                                } else {
                                  await _startPlaying(Provider.of<StoryProvider>(context, listen: false));
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
                                if (_currentPage < _pages.length - 1 && !_isPlaying) {
                                  setState(() {
                                    _currentPage++;
                                  });
                                }
                              },
                              false,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 80), // 컨트롤 버튼 아래 여백 (홈 버튼 위 20px + 홈 버튼 높이 56px + 하단 여백 4px)
                    ],
                    ),
                  );
                },
              ),
              
              // Home button (flush with bottom: 0)
              Positioned(
                bottom: 0, // 화면 하단에 딱 붙게
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
    // Split label into Korean and English parts
    final parts = label.split('\n');
    final koreanText = parts.isNotEmpty ? parts[0] : '';
    final englishText = parts.length > 1 ? parts[1] : '';
    
    return SizedBox(
      width: 170, // Reduced from 182 to prevent overflow
      height: 56, // 80 * 0.7 = 56
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
  
  void _onAudioComplete() {
    setState(() {
      _isPlaying = false;
    });
  }

  Future<void> _startPlaying(StoryProvider provider) async {
    if (_audioPaths == null || _audioPaths!.length <= _currentPage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('음성 파일이 준비되지 않았습니다.'), duration: Duration(seconds: 2)),
      );
      setState(() {
        _isPlaying = false;
      });
      return;
    }
    setState(() {
      _isPlaying = true;
    });
    await _audioPlayerService.play(_audioPaths![_currentPage], onComplete: _onAudioComplete);
  }

  Future<void> _stopPlaying(StoryProvider provider) async {
    await _audioPlayerService.stop();
    setState(() {
      _isPlaying = false;
    });
  }
}
