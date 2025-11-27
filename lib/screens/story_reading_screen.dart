import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../providers/story_provider.dart';
import '../models/story.dart';
import 'settings_screen.dart';
import '../services/audio_player_service.dart';
import '../services/viseme_event_service.dart';
import '../services/azure_tts_service.dart';
import '../services/emotion_analysis_service.dart';
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
  StreamSubscription<PlayerState>? _ttsStateSubscription;
  StreamSubscription<Duration>? _ttsPositionSubscription;
  final List<Map<String, dynamic>> _visemeQueue = [];
  bool _isPaused = false;
  Timer? _positionPollTimer;
  Timer? _eyeBlinkTimer;
  Timer? _eyeBlinkInitialTimer;
  final List<Timer> _eyeFrameTimers = [];
  String? _currentEyeAsset;
  String? _activeEyeGender;
  final EmotionAnalysisService _emotionAnalysisService = EmotionAnalysisService();
  List<_EmotionPlan> _emotionPlans = [];
  List<_EmotionSegment> _pendingEmotionSegments = [];
  bool _emotionSegmentsScheduled = false;
  bool _isEmotionActive = false;
  _EmotionSegment? _currentEmotionSegment;
  _EmotionSegment? _delayedEmotionSegment;
  int _lastKnownAudioPositionMs = 0;
  StreamSubscription<Duration>? _ttsDurationSubscription;
  static const String _defaultVisemeSocketUrl = 'ws://127.0.0.1:8000/ws/tts';

  static const String _mhEyeBasePath = 'assets/images/MH_eye/';
  static const String _mhEyeNatural = '${_mhEyeBasePath}eye_00_natural.png';
  static const String _mhEyeHalf = '${_mhEyeBasePath}eye_01_half.png';
  static const String _mhEyeClosed = '${_mhEyeBasePath}eye_02_closed.png';
  static const String _mhEyeWorry = '${_mhEyeBasePath}eye_03_worry.png';
  static const String _mhEyeSurprised = '${_mhEyeBasePath}eye_04_surprised.png';
  static const String _mhEyeMoved = '${_mhEyeBasePath}eye_05_moved.png';
  static const double _mhEyeBaseX = 323;
  static const double _mhEyeBaseY = 248;
  static const double _mhEyeBaseWidth = 319;
  static const double _mhEyeBaseHeight = 169;
  bool _isEyeBlinking = false;
  static const int _emotionDisplayDurationMs = 2000;
  static const int _emotionGraceMs = 250;
  static const String _mhEndingOverlay = 'assets/images/MH_ending.png';
  bool _showEndingOverlay = false;

  bool get _canRenderEyeAsset => _activeEyeGender == 'male';
  bool get _shouldShowEndingOverlay => _showEndingOverlay && _canRenderEyeAsset;
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

  @override
  void initState() {
    super.initState();
    _initializeVisemeService();
  }

  void _initializeVisemeService() {
    final socketUrl = _resolveVisemeSocketUrl();
    try {
      _visemeService = VisemeEventService(socketUrl);
      debugPrint('[StoryReading] Viseme socket initialized: $socketUrl');
    } catch (error) {
      debugPrint('[StoryReading] Failed to initialize viseme socket: $error');
      _visemeService = null;
    }
  }

  String _resolveVisemeSocketUrl() {
    final envCandidates = <String?>[
      dotenv.env['VISEME_WEBSOCKET_URL'],
      dotenv.env['VISEME_SOCKET_URL'],
      dotenv.env['VISME_WEBSOCKET_URL'],
      dotenv.env['TTS_WEBSOCKET_URL'],
      dotenv.env['TTS_SOCKET_URL'],
    ];
    final resolvedFromEnv = envCandidates
        .firstWhere((value) => value != null && value.trim().isNotEmpty, orElse: () => null);
    if (resolvedFromEnv != null) {
      return resolvedFromEnv.trim();
    }
    if (Platform.isAndroid) {
      return 'ws://10.0.2.2:8000/ws/tts';
    }
    return _defaultVisemeSocketUrl;
  }

  // 실제 텍스트 박스 크기에 맞춰 페이지네이션
  List<String> paginateTextByBox({
    required String text,
    required double maxWidth,
    required double maxHeight,
    required TextStyle style,
  }) {
    final normalized = text.replaceAll('\r\n', '\n');
    final double effectiveWidth = math.max(1.0, maxWidth);
    final double effectiveHeight =
      math.max((style.fontSize ?? 14) * 1.2, maxHeight);

    double measureHeight(String value) {
      if (value.isEmpty) {
        return 0;
      }
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: effectiveWidth);
      return painter.height;
    }

    List<String> tokenize(String value) {
      final regex = RegExp(r'(\s+)');
      final tokens = <String>[];
      int start = 0;
      for (final match in regex.allMatches(value)) {
        if (match.start > start) {
          tokens.add(value.substring(start, match.start));
        }
        tokens.add(match.group(0)!);
        start = match.end;
      }
      if (start < value.length) {
        tokens.add(value.substring(start));
      }
      if (tokens.isEmpty) {
        tokens.add(value);
      }
      return tokens;
    }

    void pushBuffer(StringBuffer buffer, List<String> pages) {
      if (buffer.isEmpty) {
        return;
      }
      final text = buffer.toString().trimRight();
      if (text.isNotEmpty) {
        pages.add(text);
      }
      buffer.clear();
    }

    void splitAndPush(
      String token,
      List<String> pages,
    ) {
      var remaining = token;
      while (remaining.isNotEmpty) {
        int low = 1;
        int high = remaining.length;
        int fit = 0;
        while (low <= high) {
          final mid = (low + high) ~/ 2;
          final candidate = remaining.substring(0, mid);
          if (measureHeight(candidate) <= effectiveHeight) {
            fit = mid;
            low = mid + 1;
          } else {
            high = mid - 1;
          }
        }
        if (fit == 0) {
          fit = 1;
        }
        final chunk = remaining.substring(0, fit);
        final trimmedChunk = chunk.trimRight();
        if (trimmedChunk.isNotEmpty) {
          pages.add(trimmedChunk);
        }
        remaining = remaining.substring(fit);
      }
    }

    final tokens = tokenize(normalized);
    final pages = <String>[];
    final buffer = StringBuffer();

    for (final token in tokens) {
      final tentative = buffer.isEmpty ? token : '${buffer.toString()}$token';
      if (tentative.trim().isEmpty) {
        buffer.write(token);
        continue;
      }
      if (measureHeight(tentative) <= effectiveHeight) {
        buffer.write(token);
        continue;
      }

      if (buffer.isNotEmpty) {
        pushBuffer(buffer, pages);
        final trimmedToken = token.trimLeft();
        if (trimmedToken.isEmpty) {
          continue;
        }
        if (measureHeight(trimmedToken) <= effectiveHeight) {
          buffer.write(trimmedToken);
          continue;
        }
        splitAndPush(trimmedToken, pages);
      } else {
        final trimmedToken = token.trimLeft();
        if (trimmedToken.isEmpty) {
          continue;
        }
        if (measureHeight(trimmedToken) <= effectiveHeight) {
          buffer.write(trimmedToken);
        } else {
          splitAndPush(trimmedToken, pages);
        }
      }
    }

    pushBuffer(buffer, pages);

    if (pages.isEmpty) {
      return <String>[normalized.trim()];
    }
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
    const double textPadding = 24.0;
    final innerWidth = math.max(1.0, boxWidth - textPadding * 2);
    final innerHeight = math.max(1.0, boxHeight - textPadding * 2);
    _pages = paginateTextByBox(
      text: initialContent,
      maxWidth: innerWidth,
      maxHeight: innerHeight,
      style: textStyle,
    );
    if (_currentPage >= _pages.length) {
      _currentPage = _pages.length - 1;
    }
    _currentPageSentences = _splitPageIntoSentences(_pages[_currentPage]);

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
                final gender = provider.settings.gender;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) {
                    return;
                  }
                  _handleEyeBlinkingGender(gender);
                });
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
                          if (_currentEyeAsset != null)
                            Builder(
                              builder: (context) {
                                const double baseWidth = 1024;
                                const double baseHeight = 1024;
                                const double characterBoxWidth = 360;
                                const double characterBoxHeight = 360;
                                final double scaleX = characterBoxWidth / baseWidth;
                                final double scaleY = characterBoxHeight / baseHeight;
                                final double eyeX = _mhEyeBaseX * scaleX;
                                final double eyeY = _mhEyeBaseY * scaleY;
                                final double eyeWidth =
                                    _mhEyeBaseWidth * scaleX;
                                final double eyeHeight =
                                    _mhEyeBaseHeight * scaleY;
                                return Positioned(
                                  left: eyeX,
                                  top: eyeY,
                                  child: Image.asset(
                                    _currentEyeAsset!,
                                    key: ValueKey<String>(_currentEyeAsset!),
                                    width: eyeWidth,
                                    height: eyeHeight,
                                    fit: BoxFit.contain,
                                  ),
                                );
                              },
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
                          if (_shouldShowEndingOverlay)
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: IgnorePointer(
                                  child: Image.asset(
                                    _mhEndingOverlay,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
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
                                    _showEndingOverlay = false;
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
                                    _showEndingOverlay = false;
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
      _emotionPlans = _buildEmotionPlans(sentences);
      _pendingEmotionSegments = [];
      _currentEmotionSegment = null;
      _delayedEmotionSegment = null;
      _emotionSegmentsScheduled = false;
      _isEmotionActive = false;
      _lastKnownAudioPositionMs = 0;
      setState(() {
        _isTtsPlaying = true;
        _isPlaying = true;
        _isPaused = false;
        _currentVisemeId = 0;
        _showEndingOverlay = false;
      });
      _visemeQueue.clear();
      final audioPlayer = _ttsAudioPlayer ??= AudioPlayer();
      await audioPlayer.stop();
      await _ttsStateSubscription?.cancel();
        _ttsStateSubscription = audioPlayer.onPlayerStateChanged.listen((state) {
          debugPrint('[AudioPlayer] state=$state');
        });
      await _ttsDurationSubscription?.cancel();
      _ttsDurationSubscription =
          audioPlayer.onDurationChanged.listen((duration) {
        if (duration.inMilliseconds > 0 && !_emotionSegmentsScheduled) {
          _scheduleEmotionSegments(duration);
        }
      });
      final mp3FilePath = await _azureTTSService.generateAudio(
        text: ttsText,
        language: settings.language,
        characterGender: settings.gender,
        speed: settings.speechRate,
        pitch: settings.pitch,
        age: settings.age,
      );

      try {
        final file = File(mp3FilePath);
        final exists = await file.exists();
        final length = exists ? await file.length() : 0;
        debugPrint('[TTS Playback] file=$mp3FilePath exists=$exists length=$length');
      } catch (err) {
        debugPrint('[TTS Playback] file stat failed: $err');
      }
      final visemeService = _visemeService;
      if (visemeService != null) {
        await _visemeStreamSubscription?.cancel();
        _visemeStreamSubscription = visemeService.events.listen((event) {
          if (event['type'] == 'viseme') {
            final rawViseme = (event['viseme_id'] as num?)?.toInt() ?? 0;
            final mappedViseme = visemeFileMap.containsKey(rawViseme)
                ? rawViseme
                : (_azureVisemeToUniversal[rawViseme] ?? 0);
            debugPrint(
              '[VisemeQueue] raw=$rawViseme mapped=$mappedViseme offset=${event['audio_offset_ms']}',
            );
            _visemeQueue.add({
              'viseme_id': mappedViseme,
              'audio_offset_ms': event['audio_offset_ms'] ?? 0,
              'raw_viseme_id': rawViseme,
            });
            if (!visemeFileMap.containsKey(rawViseme) &&
                !_azureVisemeToUniversal.containsKey(rawViseme)) {
              debugPrint(
                  'Unknown viseme id $rawViseme received. Defaulting to neutral.');
            }
            debugPrint(
              '[Viseme] raw=$rawViseme mapped=$mappedViseme offset=${event['audio_offset_ms']}',
            );
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
      _attachPositionListener(audioPlayer);

      await _ttsCompletionSubscription?.cancel();
      _ttsCompletionSubscription =
          audioPlayer.onPlayerComplete.listen((event) async {
        await _handleTtsPlaybackCompleted();
      });
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
      _attachPositionListener(player);
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
    _visemeQueue.clear();
    await _visemeStreamSubscription?.cancel();
    _visemeStreamSubscription = null;
    await _ttsCompletionSubscription?.cancel();
    _ttsCompletionSubscription = null;
    await _ttsStateSubscription?.cancel();
    _ttsStateSubscription = null;
    await _ttsPositionSubscription?.cancel();
    _ttsPositionSubscription = null;
    await _ttsDurationSubscription?.cancel();
    _ttsDurationSubscription = null;
    _cancelPositionPoller();
    if (_ttsAudioPlayer != null) {
      await _ttsAudioPlayer!.stop();
    }
    _clearEmotionScheduling();
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
    final isLastPage = _currentPage >= _pages.length - 1;
    if (!mounted) {
      _showEndingOverlay = isLastPage;
      return;
    }
    setState(() {
      _showEndingOverlay = isLastPage;
    });
  }

  void _cancelPositionPoller() {
    _positionPollTimer?.cancel();
    _positionPollTimer = null;
  }

  void _processVisemeQueue(int posMs, {required String source}) {
    _lastKnownAudioPositionMs = posMs;
    _updateEmotionState(posMs);
    if (_visemeQueue.isEmpty) {
      // 빈 큐 상태를 추적하기 위해 소스별로 로그를 남긴다.
      debugPrint('[VisemeCheck:$source] posMs=$posMs queue=0');
      return;
    }
    debugPrint(
      '[VisemeCheck:$source] posMs=$posMs queue=${_visemeQueue.length}',
    );
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
        return;
      }
      final resolvedViseme = (current['viseme_id'] as num?)?.toInt() ?? 0;
      final rawViseme = (current['raw_viseme_id'] as num?)?.toInt();
      debugPrint(
        '[VisemeApply:$source] posMs=$posMs raw=${rawViseme ?? 'unknown'} mapped=$resolvedViseme asset=${visemeFileMap[resolvedViseme]}',
      );
      setState(() {
        _currentVisemeId = resolvedViseme;
      });
    }
  }

  void _startPositionPoller(AudioPlayer player) {
    _cancelPositionPoller();
    _positionPollTimer =
        Timer.periodic(const Duration(milliseconds: 40), (Timer timer) {
      player.getCurrentPosition().then((position) {
        if (!mounted || position == null) {
          return;
        }
        _processVisemeQueue(position.inMilliseconds, source: 'poller');
      }).catchError((error) {
        debugPrint('[VisemePoller] getCurrentPosition error=$error');
      });
    });
  }

  void _attachPositionListener(AudioPlayer player) {
    _ttsPositionSubscription?.cancel();
    debugPrint('[VisemePosition] attaching position listener');
    _ttsPositionSubscription =
        player.onPositionChanged.listen((Duration position) {
      if (!mounted) {
        return;
      }
      final posMs = position.inMilliseconds;
      _processVisemeQueue(posMs, source: 'stream');
    });
    _startPositionPoller(player);
    player.getDuration().then((duration) {
      if (duration == null) {
        return;
      }
      if (duration.inMilliseconds > 0 && !_emotionSegmentsScheduled) {
        _scheduleEmotionSegments(duration);
      }
    }).catchError((error) {
      debugPrint('[EmotionSchedule] getDuration error=$error');
    });
  }

  void _handleEyeBlinkingGender(String gender) {
    final normalized = gender.toLowerCase();
    if (_activeEyeGender == normalized) {
      return;
    }
    _activeEyeGender = normalized;
    if (normalized == 'male') {
      _startEyeBlinkLoop();
    } else {
      _stopEyeBlinkLoop();
      if (mounted) {
        setState(() {
          _currentEyeAsset = null;
        });
      } else {
        _currentEyeAsset = null;
      }
    }
  }

  void _startEyeBlinkLoop() {
    _stopEyeBlinkLoop();
    _currentEyeAsset = _mhEyeNatural;
    if (mounted) {
      setState(() {});
    }
    _eyeBlinkInitialTimer = Timer(const Duration(milliseconds: 4400), () {
      if (!mounted) {
        return;
      }
      _runEyeBlinkCycle();
      _eyeBlinkTimer =
          Timer.periodic(const Duration(seconds: 5), (Timer _) {
        if (!mounted) {
          return;
        }
        _runEyeBlinkCycle();
      });
    });
  }

  void _runEyeBlinkCycle() {
    if (_isEmotionActive) {
      return;
    }
    _isEyeBlinking = true;
    _setEyeAsset(_mhEyeHalf);
    _scheduleEyeFrame(const Duration(milliseconds: 200), _mhEyeClosed);
    _scheduleEyeFrame(const Duration(milliseconds: 400), _mhEyeHalf);
    _scheduleEyeFrame(
      const Duration(milliseconds: 600),
      _mhEyeNatural,
      onComplete: _handleBlinkCompleted,
    );
  }

  void _scheduleEyeFrame(Duration delay, String assetPath,
      {VoidCallback? onComplete}) {
    final timer = Timer(delay, () {
      if (!mounted) {
        return;
      }
      _setEyeAsset(assetPath);
      onComplete?.call();
    });
    _eyeFrameTimers.add(timer);
  }

  void _handleBlinkCompleted() {
    _isEyeBlinking = false;
    _updateEmotionState(_lastKnownAudioPositionMs);
  }

  void _setEyeAsset(String assetPath) {
    if (!_canRenderEyeAsset) {
      if (_currentEyeAsset != null) {
        if (mounted) {
          setState(() {
            _currentEyeAsset = null;
          });
        } else {
          _currentEyeAsset = null;
        }
      }
      return;
    }
    if (_currentEyeAsset == assetPath) {
      return;
    }
    if (mounted) {
      setState(() {
        _currentEyeAsset = assetPath;
      });
    } else {
      _currentEyeAsset = assetPath;
    }
  }

  void _stopEyeBlinkLoop() {
    for (final timer in _eyeFrameTimers) {
      timer.cancel();
    }
    _eyeFrameTimers.clear();
    _eyeBlinkInitialTimer?.cancel();
    _eyeBlinkInitialTimer = null;
    _eyeBlinkTimer?.cancel();
    _eyeBlinkTimer = null;
    _isEyeBlinking = false;
  }

  void _clearEmotionScheduling() {
    _emotionPlans = [];
    _pendingEmotionSegments = [];
    _emotionSegmentsScheduled = false;
    _isEmotionActive = false;
    _currentEmotionSegment = null;
    _delayedEmotionSegment = null;
    _lastKnownAudioPositionMs = 0;
    _showEndingOverlay = false;
    if (_canRenderEyeAsset) {
      _setEyeAsset(_mhEyeNatural);
    }
  }

  List<_EmotionPlan> _buildEmotionPlans(List<String> sentences) {
    final plans = <_EmotionPlan>[];
    if (sentences.isEmpty) {
      return plans;
    }
    final normalized = sentences
        .map((sentence) => sentence.trim())
        .where((sentence) => sentence.isNotEmpty)
        .toList();
    if (normalized.isEmpty) {
      return plans;
    }

    final totalChars = normalized.fold<int>(
      0,
      (previousValue, sentence) => previousValue + sentence.runes.length,
    );
    if (totalChars == 0) {
      return plans;
    }

    int processedChars = 0;
    for (final sentence in normalized) {
      final sentenceChars = sentence.runes.length;
      final emotion = _emotionAnalysisService.analyze(sentence);
      final double startRatio =
          (processedChars / totalChars).clamp(0.0, 1.0).toDouble();
      final double endRatio =
          ((processedChars + sentenceChars) / totalChars)
              .clamp(0.0, 1.0)
              .toDouble();
      if (emotion != null && sentenceChars > 0) {
        plans.add(
          _EmotionPlan(
            type: emotion,
            startRatio: startRatio,
            endRatio: endRatio,
          ),
        );
      }
      processedChars += sentenceChars;
    }
    return plans;
  }

  void _scheduleEmotionSegments(Duration duration) {
    if (_emotionPlans.isEmpty) {
      _emotionSegmentsScheduled = true;
      return;
    }
    final totalMs = duration.inMilliseconds;
    if (totalMs <= 0) {
      return;
    }

    final segments = <_EmotionSegment>[];
    for (final plan in _emotionPlans) {
      final startMs = (plan.startRatio * totalMs).round();
      final endMs = math.min(totalMs, startMs + _emotionDisplayDurationMs);
      if (endMs <= startMs) {
        continue;
      }
      final asset = _emotionAssetForType(plan.type);
      if (asset == null) {
        continue;
      }
      segments.add(
        _EmotionSegment(
          type: plan.type,
          asset: asset,
          startMs: startMs,
          endMs: endMs,
        ),
      );
    }

    if (segments.isEmpty) {
      _pendingEmotionSegments = [];
      _emotionSegmentsScheduled = true;
      return;
    }

    segments.sort((a, b) => a.startMs.compareTo(b.startMs));
    _pendingEmotionSegments = segments;
    _emotionSegmentsScheduled = true;
    _updateEmotionState(_lastKnownAudioPositionMs);
  }

  void _updateEmotionState(int posMs) {
    if (!_emotionSegmentsScheduled) {
      return;
    }

    if (_currentEmotionSegment != null &&
        posMs >= _currentEmotionSegment!.endMs) {
      _completeActiveEmotionSegment();
    }

    if (_isEmotionActive) {
      return;
    }

    if (_pendingEmotionSegments.isEmpty) {
      return;
    }

    for (final segment in _pendingEmotionSegments) {
      if (segment.completed || segment.inProgress) {
        continue;
      }
      if (posMs > segment.endMs + _emotionGraceMs) {
        segment.completed = true;
      }
    }

    if (_delayedEmotionSegment != null) {
      final delayed = _delayedEmotionSegment!;
      if (delayed.completed) {
        _delayedEmotionSegment = null;
      } else if (posMs > delayed.endMs + _emotionGraceMs) {
        delayed.completed = true;
        _delayedEmotionSegment = null;
      } else if (!_isEyeBlinking) {
        _delayedEmotionSegment = null;
        _activateEmotionSegment(delayed);
        return;
      } else {
        return;
      }
    }

    for (final segment in _pendingEmotionSegments) {
      if (segment.completed || segment.inProgress) {
        continue;
      }
      if (posMs < segment.startMs) {
        break;
      }
      if (posMs > segment.endMs + _emotionGraceMs) {
        segment.completed = true;
        continue;
      }
      if (_isEyeBlinking) {
        _delayedEmotionSegment = segment;
        return;
      }
      _activateEmotionSegment(segment);
      return;
    }
  }

  void _activateEmotionSegment(_EmotionSegment segment) {
    if (!_canRenderEyeAsset) {
      segment.completed = true;
      return;
    }
    _isEmotionActive = true;
    segment.inProgress = true;
    _currentEmotionSegment = segment;
    _setEyeAsset(segment.asset);
  }

  void _completeActiveEmotionSegment() {
    final segment = _currentEmotionSegment;
    if (segment == null) {
      return;
    }
    segment.inProgress = false;
    segment.completed = true;
    _currentEmotionSegment = null;
    _isEmotionActive = false;
    if (_canRenderEyeAsset) {
      _setEyeAsset(_mhEyeNatural);
    }
  }

  String? _emotionAssetForType(EmotionType type) {
    switch (type) {
      case EmotionType.worry:
        return _mhEyeWorry;
      case EmotionType.surprise:
        return _mhEyeSurprised;
      case EmotionType.moved:
        return _mhEyeMoved;
    }
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
    _visemeStreamSubscription?.cancel();
    _ttsCompletionSubscription?.cancel();
    _ttsStateSubscription?.cancel();
    _ttsPositionSubscription?.cancel();
    _ttsDurationSubscription?.cancel();
    _cancelPositionPoller();
    _ttsAudioPlayer?.dispose();
    _visemeService?.dispose();
    _stopEyeBlinkLoop();
    _clearEmotionScheduling();
    super.dispose();
  }

/*
  void sendTTSRequest(String text, String voice) {
    print('sendTTSRequest called: text=$text, voice=$voice');
    // ...existing code...
  }
*/
}

class _EmotionPlan {
  const _EmotionPlan({
    required this.type,
    required this.startRatio,
    required this.endRatio,
  });

  final EmotionType type;
  final double startRatio;
  final double endRatio;
}

class _EmotionSegment {
  _EmotionSegment({
    required this.type,
    required this.asset,
    required this.startMs,
    required this.endMs,
  });

  final EmotionType type;
  final String asset;
  final int startMs;
  final int endMs;
  bool inProgress = false;
  bool completed = false;
}
