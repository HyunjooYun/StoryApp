import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/story_provider.dart';
import '../models/story.dart';
import 'settings_screen.dart';
import '../services/audio_player_service.dart';
import '../services/viseme_event_service.dart';
import '../services/azure_tts_service.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class StoryReadingScreen extends StatefulWidget {
  final Story story;
  const StoryReadingScreen({super.key, required this.story});

  @override
  State<StoryReadingScreen> createState() => _StoryReadingScreenState();
}

class _StoryReadingScreenState extends State<StoryReadingScreen> {
  int _currentVisemeId = 0; // 립싱크 neutral
  VisemeEventService? _visemeService;
  int _currentPage = 0;
  bool _isPlaying = false;
  late List<String> _pages;
  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  final AzureTTSService _azureTTSService = AzureTTSService();
  List<String>? _currentPageSentences;
  bool _isTtsPlaying = false;
  AudioPlayer? _ttsAudioPlayer;
  StreamSubscription<Map<String, dynamic>>? _visemeStreamSubscription;
  StreamSubscription<void>? _ttsCompletionSubscription;
  Timer? _lipSyncTimer;
  final List<Map<String, dynamic>> _visemeQueue = [];
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    final initialContent = widget.story.adaptedScript ?? widget.story.content;
    _pages = [initialContent];
    _currentPageSentences = _splitPageIntoSentences(_pages[_currentPage]);
    _currentVisemeId = 0; // neutral

    // WebSocket 연결만 여기서 해둔다. (이 시점에서는 이벤트 listen 안 함)
    _visemeService =
        VisemeEventService("ws://192.168.0.10:8000/ws/tts"); // 서버 주소에 맞게 변경
  }

/*
  @override
  void initState() {
    super.initState();
    final initialContent = widget.story.adaptedScript ?? widget.story.content;
    _pages = [initialContent];
    _currentPageSentences = _splitPageIntoSentences(_pages[_currentPage]);
    _currentVisemeId = 0; // neutral
    _visemeService = VisemeEventService("ws://192.168.0.10:8000/ws/tts"); // 서버 주소에 맞게 변경
    _visemeService!.events.listen((event) {
      if (event.containsKey('viseme_id')) {
        setState(() {
          _currentVisemeId = event['viseme_id'] ?? 0;
        });
      }
      if (event.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('TTS 오류: ${event['error']}'), duration: const Duration(seconds: 2)),
        );
      }
    });
  }
*/

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

  static const Map<int, int> _azureVisemeToUniversal = {
    0: 0, // silence
    1: 5, // ae/ax/ah -> AH
    2: 4, // aa -> AA
    3: 6, // ao -> AO
    4: 3, // ey/eh/uh -> EH
    5: 11, // er -> LR
    6: 2, // iy/ih -> AI
    7: 7, // uw/w -> UW
    8: 6, // ow -> AO
    9: 8, // aw -> OY
    10: 8, // oy -> OY
    11: 2, // ay -> AI
    12: 0, // h -> neutral mouth
    13: 11, // r -> LR
    14: 11, // l -> LR
    15: 9, // s/z -> SZ
    16: 10, // sh/ch -> CH
    17: 9, // th/dh -> SZ (closest)
    18: 12, // f/v -> FV
    19: 1, // d/t/n -> BMP (tongue behind teeth)
    20: 9, // k/g/ng -> SZ style (closed mouth)
    21: 1, // p/b/m -> BMP
  };

  String getLipSyncCharacterImage(String gender) {
    return gender == 'male'
        ? 'assets/images/MH_lip_ani.png'
        : 'assets/images/SY_lip_ani.png';
  }

  String getVisemeFolder(String gender) {
    return gender == 'male'
        ? 'assets/images/MH_viseme/'
        : 'assets/images/SY_viseme/';
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
    // 미사용 screenWidth 변수 완전 제거
    final boxWidth = MediaQuery.of(context).size.width * 0.8;
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
                      MaterialPageRoute(
                          builder: (context) => const SettingsScreen()),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                // 미사용 screenWidth 변수 완전 제거
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
                                  return const Icon(Icons.person,
                                      size: 120, color: Color(0xFF7C4DFF));
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
                              double visemeX =
                                  baseX * (characterBoxWidth / baseWidth);
                              double visemeY =
                                  baseY * (characterBoxHeight / baseHeight);
                              // viseme 이미지 크기를 캐릭터 박스 비율에 맞게 자동 조정
                              // viseme 이미지 크기를 캐릭터 박스 비율에 맞게 자동 조정
                              const double visemeBaseWidth = 135;
                              const double visemeBaseHeight = 104;
                              double visemeWidth = visemeBaseWidth *
                                  (characterBoxWidth / baseWidth);
                              double visemeHeight = visemeBaseHeight *
                                  (characterBoxHeight / baseHeight);
                              return Positioned(
                                left: visemeX,
                                top: visemeY,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 70),
                                  switchInCurve: Curves.easeIn,
                                  switchOutCurve: Curves.easeOut,
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                                  child: Image.asset(
                                    key: ValueKey<int>(_currentVisemeId),
                                    getVisemeFolder(gender) +
                                        visemeFileMap[_currentVisemeId]!,
                                    width: visemeWidth,
                                    height: visemeHeight,
                                    fit: BoxFit.contain,
                                  ),
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
                                    _currentPageSentences =
                                        _splitPageIntoSentences(
                                            _pages[_currentPage]);
                                  });
                                }
                              },
                              false,
                            ),
                            const SizedBox(width: 15),
                            _buildControlButton(
                              _isPlaying
                                  ? '멈춤\nPause'
                                  : _isPaused && _isTtsPlaying
                                      ? '재개\nResume'
                                      : '실행\nPlay',
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              true,
                              () async {
                                if (_isPlaying) {
                                  await _pauseTtsPlayback();
                                } else if (_isPaused && _isTtsPlaying) {
                                  await _resumeTtsPlayback();
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
                                if (_currentPage < _pages.length - 1 &&
                                    !_isPlaying &&
                                    !_isTtsPlaying) {
                                  await _stopAllAudio();
                                  setState(() {
                                    _currentPage++;
                                    _currentPageSentences =
                                        _splitPageIntoSentences(
                                            _pages[_currentPage]);
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
                  onPressed: () =>
                      Navigator.popUntil(context, (route) => route.isFirst),
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
          backgroundColor:
              isPrimary ? const Color(0xFF5E35B1) : const Color(0xFFACA2FF),
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
    final settings = provider.settings;
    final sentences =
        _currentPageSentences ?? _splitPageIntoSentences(_pages[_currentPage]);

    if (sentences.isEmpty) return;

    // 1. 현재 페이지 전체 텍스트 (혹은 문장 단위로 바꾸고 싶으면 sentences[i] 사용)
    final String ttsText = _pages[_currentPage];

    try {
      await _stopTtsPlayback(resetState: false);
      setState(() {
        _isTtsPlaying = true;
        _isPlaying = true;
        _isPaused = false;
        _currentVisemeId = 0;
      });
      _visemeQueue.clear();
      final audioPlayer = _ttsAudioPlayer ??= AudioPlayer();
      await audioPlayer.stop();
      final mp3FilePath = await _azureTTSService.generateAudio(
        text: ttsText,
        language: settings.language,
        characterGender: settings.gender,
        speed: settings.speechRate,
        pitch: settings.pitch,
        age: settings.age,
      );

      final visemeService = _visemeService;
      if (visemeService != null) {
        await _visemeStreamSubscription?.cancel();
        _visemeStreamSubscription = visemeService.events.listen((event) {
          if (event['type'] == 'viseme') {
            final rawViseme = (event['viseme_id'] as num?)?.toInt() ?? 0;
            final mappedViseme = visemeFileMap.containsKey(rawViseme)
                ? rawViseme
                : (_azureVisemeToUniversal[rawViseme] ?? 0);
            _visemeQueue.add({
              'viseme_id': mappedViseme,
              'audio_offset_ms': event['audio_offset_ms'] ?? 0,
            });
            if (!visemeFileMap.containsKey(rawViseme) &&
                !_azureVisemeToUniversal.containsKey(rawViseme)) {
              debugPrint(
                  'Unknown viseme id $rawViseme received. Defaulting to neutral.');
            }
          } else if (event['type'] == 'error') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('TTS 오류: ${event['message'] ?? event['error']}'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        });

        final voiceName =
            _azureTTSService.resolveVoiceName(settings.language, settings.gender);
        final effectiveSpeechRate =
            _azureTTSService.applySpeechRateMultiplier(settings.speechRate);
        visemeService.sendTTSRequest(
          text: ttsText,
          voice: voiceName,
          speakingRate: effectiveSpeechRate,
        );
      }

      await audioPlayer.play(DeviceFileSource(mp3FilePath));

      await _ttsCompletionSubscription?.cancel();
      _ttsCompletionSubscription =
          audioPlayer.onPlayerComplete.listen((event) async {
        await _handleTtsPlaybackCompleted();
      });

      _startLipSyncTimer();
    } catch (e) {
      await _stopTtsPlayback();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('TTS 오류: $e'), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _resumeTtsPlayback() async {
    final player = _ttsAudioPlayer;
    if (player == null) {
      return;
    }
    try {
      await player.resume();
      _startLipSyncTimer();
      if (mounted) {
        setState(() {
          _isPlaying = true;
          _isPaused = false;
        });
      } else {
        _isPlaying = true;
        _isPaused = false;
      }
    } catch (e) {
      await _stopTtsPlayback();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('TTS 오류: $e'), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _pauseTtsPlayback() async {
    final player = _ttsAudioPlayer;
    if (player == null) {
      return;
    }
    await player.pause();
    _lipSyncTimer?.cancel();
    _lipSyncTimer = null;
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _isPaused = true;
      });
    } else {
      _isPlaying = false;
      _isPaused = true;
    }
  }

  Future<void> _stopTtsPlayback({bool resetState = true}) async {
    _lipSyncTimer?.cancel();
    _lipSyncTimer = null;
    _visemeQueue.clear();
    await _visemeStreamSubscription?.cancel();
    _visemeStreamSubscription = null;
    await _ttsCompletionSubscription?.cancel();
    _ttsCompletionSubscription = null;
    if (_ttsAudioPlayer != null) {
      await _ttsAudioPlayer!.stop();
    }
    _isPaused = false;
    if (resetState && mounted) {
      setState(() {
        _isTtsPlaying = false;
        _isPlaying = false;
        _currentVisemeId = 0;
        _isPaused = false;
      });
    } else {
      _isTtsPlaying = false;
      _isPlaying = false;
      _currentVisemeId = 0;
      _isPaused = false;
    }
  }

  Future<void> _handleTtsPlaybackCompleted() async {
    await _stopTtsPlayback();
  }

  void _startLipSyncTimer() {
    _lipSyncTimer?.cancel();
    _lipSyncTimer = Timer.periodic(const Duration(milliseconds: 20),
        (timer) async {
      final activePlayer = _ttsAudioPlayer;
      if (activePlayer == null) {
        timer.cancel();
        return;
      }
      final position = await activePlayer.getCurrentPosition();
      final posMs = position?.inMilliseconds ?? 0;

      while (_visemeQueue.isNotEmpty) {
        final current = _visemeQueue.first;
        final rawOffset = current['audio_offset_ms'];
        final offsetMs = rawOffset is num
            ? rawOffset.toInt()
            : int.tryParse('$rawOffset') ?? 0;
        if (offsetMs > posMs) {
          break;
        }
        _visemeQueue.removeAt(0);
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _currentVisemeId = (current['viseme_id'] as num?)?.toInt() ?? 0;
        });
      }
    });
  }

/*
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
      // 1. 오디오 플레이어로 mp3 재생
      final audioPlayer = AudioPlayer();
      await audioPlayer.play(mp3FilePath, isLocal: true);

      // 2. viseme 이벤트 큐에 저장
      List<Map<String, dynamic>> visemeQueue = []; // {viseme_id, audio_offset}
      visemeStream.listen((event) {
        if (event['type'] == 'viseme') {
          visemeQueue.add({
            'viseme_id': event['viseme_id'],
            'audio_offset': event['audio_offset'], // ms 단위
          });
        }
      });

      // 3. 싱크 맞추기 (타이머로 주기적으로 체크)
      Timer.periodic(Duration(milliseconds: 20), (timer) async {
        final position = await audioPlayer.getCurrentPosition(); // ms 단위
        // visemeQueue에서 audio_offset <= position 인 이벤트만 처리
        while (visemeQueue.isNotEmpty && visemeQueue.first['audio_offset'] <= position) {
          final viseme = visemeQueue.removeAt(0);
          setState(() {
            _currentVisemeId = viseme['viseme_id'];
          });
        }
        // 오디오가 끝나면 타이머 종료
        if (audioPlayer.state == PlayerState.completed) {
          timer.cancel();
          setState(() {
            _currentVisemeId = 0; // neutral
          });
        }
      });
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
*/

  Future<void> _stopAllAudio() async {
    await _stopTtsPlayback();
    await _audioPlayerService.stop();
  }

  @override
  void dispose() {
    _lipSyncTimer?.cancel();
    _visemeStreamSubscription?.cancel();
    _ttsCompletionSubscription?.cancel();
    _ttsAudioPlayer?.dispose();
    _visemeService?.dispose();
    super.dispose();
  }

/*
  void sendTTSRequest(String text, String voice) {
    print('sendTTSRequest called: text=$text, voice=$voice');
    // ...existing code...
  }
*/
}
