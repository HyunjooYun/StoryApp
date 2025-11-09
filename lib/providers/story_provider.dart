import 'package:flutter/material.dart';
import '../models/story.dart';
import '../models/story_settings.dart';
import '../services/story_service.dart';
import '../services/tts_service.dart';
import '../services/translation_service.dart';
import '../services/settings_service.dart';
import '../services/openai_service.dart';
import '../services/azure_tts_service.dart';

class StoryProvider extends ChangeNotifier {
  final StoryService _storyService = StoryService();
  final TTSService _ttsService = TTSService();
  final TranslationService _translationService = TranslationService();
  final SettingsService _settingsService = SettingsService();
  final OpenAIService _openAIService = OpenAIService();
  final AzureTTSService _azureTTSService = AzureTTSService();
  
  List<Story> _stories = [];
  Story? _currentStory;
  StorySettings _settings = StorySettings(
    language: '한국어',
    age: 7,
    gender: 'female',
  );
  
  String _translatedContent = '';
  bool _isLoading = false;
  bool _isPlaying = false;
  int _currentParagraphIndex = 0;
  List<String> _paragraphs = [];
  
  List<Story> get stories => _stories;
  Story? get currentStory => _currentStory;
  StorySettings get settings => _settings;
  String get translatedContent => _translatedContent;
  bool get isLoading => _isLoading;
  bool get isPlaying => _isPlaying;
  int get currentParagraphIndex => _currentParagraphIndex;
  List<String> get paragraphs => _paragraphs;
  
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    
    await _storyService.loadStories();
    await _ttsService.initialize();
    await _settingsService.initialize();
    
    _stories = _storyService.getAllStories();
    _settings = await _settingsService.loadSettings();
    
    _isLoading = false;
    notifyListeners();
  }
  
  void selectStory(Story story) {
    _currentStory = story;
    // Use adapted script if available, otherwise use original content
    _translatedContent = story.adaptedScript ?? story.content;
    _currentParagraphIndex = 0;
    // Split into paragraphs/sentences
    _paragraphs = _translatedContent
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();
    
    print('📖 Story selected: ${story.title}');
    print('   Has adapted script: ${story.adaptedScript != null}');
    print('   Content length: ${_translatedContent.length} characters');
    print('   First 100 chars: ${_translatedContent.substring(0, _translatedContent.length > 100 ? 100 : _translatedContent.length)}');
    
    notifyListeners();
  }
  
  void updateSettings(StorySettings newSettings) {
    // Check if age or language changed
    final bool ageChanged = _settings.age != newSettings.age;
    final bool languageChanged = _settings.language != newSettings.language;
    final bool genderChanged = _settings.gender != newSettings.gender;
    
    _settings = newSettings;
    _settingsService.saveSettings(newSettings);
    
    // If age or language changed, reset all completed stories
    if (ageChanged || languageChanged || genderChanged) {
      print('⚙️ Settings changed - resetting all stories');
      print('   Age: ${ageChanged ? "Changed" : "Same"}');
      print('   Language: ${languageChanged ? "Changed" : "Same"}');
      print('   Gender: ${genderChanged ? "Changed" : "Same"}');
      
      for (var story in _stories) {
        if (story.status == 'completed') {
          story.status = 'pending';
          story.progress = 0.0;
          story.adaptedScript = null; // Clear old adapted script
          print('   Reset: ${story.title}');
        }
      }
    }
    
    notifyListeners();
  }
  
  Future<void> prepareStory(String storyId) async {
    // Find the story by ID
    final storyIndex = _stories.indexWhere((s) => s.id == storyId);
    if (storyIndex == -1) return;
    
    // Update story status to processing
    _stories[storyIndex].status = 'processing';
    _stories[storyIndex].progress = 0.0;
    notifyListeners();
    
    try {
      // Get original story content
      final originalStory = _stories[storyIndex];
      
      // Step 1: Generate age-appropriate script with OpenAI (0-40%)
      _stories[storyIndex].progress = 0.1;
      notifyListeners();
      
      final ageAppropriateScript = await _openAIService.generateAgeAppropriateScript(
        storyContent: originalStory.content,
        age: _settings.age,
        language: _settings.language,
      );
      
      _stories[storyIndex].progress = 0.4;
      notifyListeners();
      
      // Store the generated script in Story model
      _stories[storyIndex].adaptedScript = ageAppropriateScript;
      _translatedContent = ageAppropriateScript;
      
      // Step 2: Split into sentences (40-50%)
      // Each sentence is on a new line as requested by OpenAI
      _paragraphs = ageAppropriateScript
          .split('\n')
          .where((p) => p.trim().isNotEmpty)
          .toList();
      
      _stories[storyIndex].progress = 0.5;
      notifyListeners();
      
      // Step 3: Generate audio with Azure TTS (50-100%)
      final audioPaths = await _azureTTSService.generateAudioSegments(
        textSegments: _paragraphs,
        language: _settings.language,
        characterGender: _settings.gender,
        speed: _settings.speechRate,
        pitch: _settings.pitch,
        onProgress: (current, total) {
          final progress = 0.5 + (0.5 * current / total);
          _stories[storyIndex].progress = progress;
          notifyListeners();
        },
      );

      // Store audio paths for playback in Story model
      _stories[storyIndex].audioPaths = audioPaths;

      // Mark as completed
      _stories[storyIndex].status = 'completed';
      _stories[storyIndex].progress = 1.0;
      notifyListeners();
      
      print('✅ Story prepared successfully!');
      print('   Script length: ${ageAppropriateScript.length} characters');
      print('   Sentences: ${_paragraphs.length}');
      print('   Audio files: ${audioPaths.length}');
      print('   First 200 chars: ${ageAppropriateScript.substring(0, ageAppropriateScript.length > 200 ? 200 : ageAppropriateScript.length)}');
      
    } catch (e) {
      print('❌ Error preparing story: $e');
      _stories[storyIndex].status = 'pending';
      _stories[storyIndex].progress = 0.0;
      notifyListeners();
      
      // Show error to user
      rethrow;
    }
  }
  
  Future<void> prepareCurrentStory() async {
    if (_currentStory == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // Configure TTS
      await _ttsService.configure(_settings);
      
      // Translate if needed
      if (_settings.language != '한국어') {
        _translatedContent = await _translationService.translate(
          _currentStory!.content,
          _settings.language,
        );
      } else {
        _translatedContent = _currentStory!.content;
      }
      
      // Split into paragraphs
      _paragraphs = _translatedContent
          .split('\n\n')
          .where((p) => p.trim().isNotEmpty)
          .toList();
      
      _currentParagraphIndex = 0;
    } catch (e) {
      print('Error preparing story: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> playStory() async {
    if (_paragraphs.isEmpty) {
      await prepareCurrentStory();
    }
    
    _isPlaying = true;
    notifyListeners();
    
    _ttsService.setCompletionHandler(() {
      if (_currentParagraphIndex < _paragraphs.length - 1) {
        _currentParagraphIndex++;
        notifyListeners();
        _ttsService.speak(_paragraphs[_currentParagraphIndex]);
      } else {
        _isPlaying = false;
        _currentParagraphIndex = 0;
        notifyListeners();
      }
    });
    
    await _ttsService.speak(_paragraphs[_currentParagraphIndex]);
  }
  
  Future<void> pauseStory() async {
    await _ttsService.pause();
    _isPlaying = false;
    notifyListeners();
  }
  
  Future<void> stopStory() async {
    await _ttsService.stop();
    _isPlaying = false;
    _currentParagraphIndex = 0;
    notifyListeners();
  }
  
  void nextParagraph() {
    if (_currentParagraphIndex < _paragraphs.length - 1) {
      _currentParagraphIndex++;
      if (_isPlaying) {
        _ttsService.speak(_paragraphs[_currentParagraphIndex]);
      }
      notifyListeners();
    }
  }
  
  void previousParagraph() {
    if (_currentParagraphIndex > 0) {
      _currentParagraphIndex--;
      if (_isPlaying) {
        _ttsService.speak(_paragraphs[_currentParagraphIndex]);
      }
      notifyListeners();
    }
  }
}
