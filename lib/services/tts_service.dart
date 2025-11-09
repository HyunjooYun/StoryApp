import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/voice_config.dart';
import '../models/story_settings.dart';

class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();
  
  final FlutterTts _flutterTts = FlutterTts();
  VoiceConfig? _voiceConfig;
  bool _isInitialized = false;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Load voice config
    final configString = await rootBundle.loadString('assets/voice_config.json');
    final configJson = json.decode(configString);
    _voiceConfig = VoiceConfig.fromJson(configJson);
    
    // Set default TTS settings
    await _flutterTts.setLanguage('ko-KR');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    _isInitialized = true;
  }
  
  Future<void> configure(StorySettings settings) async {
    if (!_isInitialized) await initialize();
    
    final langConfig = _voiceConfig?.languages[settings.language];
    if (langConfig == null) return;
    
    final ageRule = langConfig.getAgeRule(settings.age);
    if (ageRule == null) return;
    
    // Set language
    await _flutterTts.setLanguage(langConfig.xmlLang);
    
    // Set speech rate and pitch
    await _flutterTts.setSpeechRate(ageRule.flutterTts.rate);
    await _flutterTts.setPitch(ageRule.flutterTts.pitch);
  }
  
  Future<void> speak(String text) async {
    if (!_isInitialized) await initialize();
    await _flutterTts.speak(text);
  }
  
  Future<void> stop() async {
    await _flutterTts.stop();
  }
  
  Future<void> pause() async {
    await _flutterTts.pause();
  }
  
  void setCompletionHandler(void Function()? handler) {
    if (handler != null) {
      _flutterTts.setCompletionHandler(handler);
    }
  }
  
  void setProgressHandler(void Function(String text, int start, int end, String word)? handler) {
    if (handler != null) {
      _flutterTts.setProgressHandler(handler);
    }
  }
  
  void setErrorHandler(void Function(dynamic message)? handler) {
    if (handler != null) {
      _flutterTts.setErrorHandler(handler);
    }
  }
}
