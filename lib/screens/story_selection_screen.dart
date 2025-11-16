
// 전체 복구된 코드 (StatelessWidget, build, 위젯 트리, 카드, 업로드 버튼, 상태/색상 함수, 준비 다이얼로그 등)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../providers/story_provider.dart';
import '../models/story.dart';
import 'story_reading_screen.dart';
import 'settings_screen.dart';

class StorySelectionScreen extends StatelessWidget {
  const StorySelectionScreen({super.key});

  String _getStoryIcon(String title) {
    if (title.contains('콩쥐팥쥐')) {
      return 'assets/images/kongji_icon.png';
    } else if (title.contains('흥부') || title.contains('놀부')) {
      return 'assets/images/heung_icon.png';
    } else if (title.contains('형제')) {
      return 'assets/images/brother_icon.png';
    }
    return 'assets/images/MH.png'; // default
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF7C4DFF),
              Color(0xFF536DFE),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Settings button
              Positioned(
                top: 20,
                left: 20,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 18, decoration: TextDecoration.underline),
                  ),
                  child: const Text('설정 Setting'),
                ),
              ),
              // Close button
              Positioned(
                top: 20,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              // Main content
              Positioned.fill(
                child: Consumer<StoryProvider>(
                  builder: (context, provider, child) {
                    return Column(
                      children: [
                        const SizedBox(height: 80),
                        // Title
                        Column(
                          children: [
                            const Text(
                              '동화 선택 Select Story',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40),
                              child: Divider(color: Colors.white, thickness: 2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Column(
                              children: [
                                // Story cards
                                ...provider.stories.map((story) => Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: _buildStoryCard(context, story, provider),
                                )),
                                // Upload card (if any)
                                if (_uploadCardData != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: _buildUploadCard(context, _uploadCardData!),
                                  ),
                                const SizedBox(height: 20),
                                // File upload button
                                _buildFileUploadButton(context),
                                const SizedBox(height: 80),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // Home button
              Positioned(
                bottom: 20,
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
      ),
    );
  }

  Widget _buildStoryCard(BuildContext context, Story story, StoryProvider provider) {
    final storyIcon = _getStoryIcon(story.title);
    return GestureDetector(
      onTap: () async {
        if (story.status == 'pending') {
          _showPreparationDialog(context, story, provider);
        } else if (story.status == 'completed') {
          provider.selectStory(story);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StoryReadingScreen(story: story),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFDCE3FF),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Story icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  storyIcon,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.book, size: 40, color: Color(0xFF7C4DFF));
                  },
                ),
              ),
            ),
            const SizedBox(width: 20),
            // Story info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5E35B1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _getStatusText(story.status),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF7C4DFF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${(story.progress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF7C4DFF),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: story.progress,
                          minHeight: 12,
                          backgroundColor: const Color(0xFFE0E0E0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getProgressColor(story.progress),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return '준비 필요';
      case 'processing':
        return '준비 중...';
      case 'completed':
        return '준비 완료';
      default:
        return '상태 확인';
    }
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.3) {
      return const Color(0xFFFF6B6B); // Red for script generation
    } else if (progress < 0.6) {
      return const Color(0xFFFFD93D); // Yellow for translation
    } else {
      return const Color(0xFF6BCF7F); // Green for TTS
    }
  }

  // Upload card state (in-memory, only one at a time)
  static _UploadCardData? _uploadCardData;

  Widget _buildFileUploadButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF5E17EB),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextButton(
        onPressed: () async {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['txt'],
          );
          if (result != null && result.files.single.path != null) {
            final file = File(result.files.single.path!);
            final content = await file.readAsString();
            final fileName = result.files.single.name;
            // Only one upload card at a time
            _uploadCardData = _UploadCardData(
              fileName: fileName,
              progress: 0.0,
              status: 'processing',
              message: '스크립트 생성 중...'
            );
            // Rebuild UI
            (context as Element).markNeedsBuild();
            // Run pipeline: script -> translation -> TTS
            try {
              // 1. Generate script (OpenAI)
              final provider = Provider.of<StoryProvider>(context, listen: false);
              final settings = provider.settings;
              final openai = provider.openAIService;
              final azureTTS = provider.azureTTSService;
              final translationService = provider.translationService;
              String script = await openai.generateAgeAppropriateScript(
                storyContent: content,
                age: settings.age,
                language: settings.language,
              );
              _uploadCardData = _uploadCardData!.copyWith(
                progress: 0.4,
                message: '번역 중...'
              );
              (context as Element).markNeedsBuild(); // Remove unnecessary cast
              // 2. Translate if needed
              String translated = script;
              if (settings.language != '한국어') {
                translated = await translationService.translate(
                  script,
                  settings.language,
                );
              }
              _uploadCardData = _uploadCardData!.copyWith(
                progress: 0.6,
                message: 'TTS 생성 중...'
              );
              (context as Element).markNeedsBuild(); // Remove unnecessary cast
              // 3. TTS (Azure)
              final lines = translated.split('\n').where((p) => p.trim().isNotEmpty).toList();
              final audioPaths = await azureTTS.generateAudioSegments(
                textSegments: lines,
                language: settings.language,
                characterGender: settings.gender,
                speed: settings.speechRate,
                pitch: settings.pitch,
                onProgress: (current, total) {
                  _uploadCardData = _uploadCardData!.copyWith(
                    progress: 0.6 + 0.4 * (current / total),
                    message: 'TTS 생성 중... ($current/$total)'
                  );
                  (context as Element).markNeedsBuild();
                },
              );
              _uploadCardData = _uploadCardData!.copyWith(
                progress: 1.0,
                status: 'completed',
                message: '완료!'
              );
              (context as Element).markNeedsBuild();
              // Add as a new story (top)
              final newStory = Story(
                id: 'uploaded_${DateTime.now().millisecondsSinceEpoch}',
                title: fileName,
                content: content,
                imagePath: settings.getCharacterImage(),
                recommendedAge: settings.age,
                progress: 1.0,
                status: 'completed',
                adaptedScript: translated,
                audioPaths: audioPaths,
              );
              provider.addStory(newStory);
              // Remove upload card after short delay
              await Future.delayed(const Duration(seconds: 2));
              _uploadCardData = null;
              (context as Element).markNeedsBuild();
            } catch (e) {
              _uploadCardData = _uploadCardData!.copyWith(
                status: 'error',
                message: '에러: $e'
              );
              (context as Element).markNeedsBuild();
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('파일 선택이 취소되었습니다'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_file, size: 40, color: Colors.white),
            SizedBox(height: 8),
            Text(
              '파일 업로드',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard(BuildContext context, _UploadCardData data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFDCE3FF),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.upload_file, size: 40, color: Color(0xFF7C4DFF)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.fileName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5E35B1),
                  ),
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getStatusText(data.status),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF7C4DFF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${(data.progress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF7C4DFF),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: data.progress,
                        minHeight: 12,
                        backgroundColor: const Color(0xFFE0E0E0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getProgressColor(data.progress),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.message,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// End of file



  void _showPreparationDialog(BuildContext context, Story story, StoryProvider provider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            '동화 준비',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${story.title}를 준비하시겠습니까?',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                '스크립트 생성, 번역, TTS 변환이 진행됩니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                provider.prepareStory(story.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${story.title} 준비가 시작되었습니다'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF),
              ),
              child: const Text('시작', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
// Upload card state holder (top-level)
class _UploadCardData {
  final String fileName;
  final double progress;
  final String status;
  final String message;
  _UploadCardData({
    required this.fileName,
    required this.progress,
    required this.status,
    required this.message,
  });
  _UploadCardData copyWith({
    String? fileName,
    double? progress,
    String? status,
    String? message,
  }) {
    return _UploadCardData(
      fileName: fileName ?? this.fileName,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }
}
