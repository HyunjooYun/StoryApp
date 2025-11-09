import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/story_settings.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();
  
  SharedPreferences? _prefs;
  
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
  
  Future<void> saveSettings(StorySettings settings) async {
    await initialize();
    final jsonString = json.encode(settings.toJson());
    await _prefs?.setString('story_settings', jsonString);
  }
  
  Future<StorySettings> loadSettings() async {
    await initialize();
    final jsonString = _prefs?.getString('story_settings');
    
    if (jsonString != null) {
      try {
        final jsonMap = json.decode(jsonString);
        return StorySettings.fromJson(jsonMap);
      } catch (e) {
        print('Error loading settings: $e');
      }
    }
    
    // Return default settings
    return StorySettings(
      language: '한국어',
      age: 7,
      gender: 'female',
      speechRate: 0.5,
      pitch: 1.0,
    );
  }
  
  Future<void> clearSettings() async {
    await initialize();
    await _prefs?.remove('story_settings');
  }
}
