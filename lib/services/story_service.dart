import 'package:flutter/services.dart' show rootBundle;
import '../models/story.dart';

class StoryService {
  static final StoryService _instance = StoryService._internal();
  factory StoryService() => _instance;
  StoryService._internal();

  final List<Story> _stories = [];

  Future<void> loadStories() async {
    if (_stories.isNotEmpty) return;

    // Load predefined stories from assets
    _stories.addAll([
      Story(
        id: 'story_001',
        title: '의좋은 형제',
        content: await rootBundle.loadString('assets/txt/의좋은형제.txt'),
        imagePath: 'assets/images/MH.png',
        recommendedAge: 7,
      ),
      Story(
        id: 'story_002',
        title: '콩쥐팥쥐',
        content: await rootBundle.loadString('assets/txt/콩쥐팥쥐.txt'),
        imagePath: 'assets/images/SY.png',
        recommendedAge: 8,
      ),
      Story(
        id: 'story_003',
        title: '흥부와 놀부',
        content: await rootBundle.loadString('assets/txt/흥부와 놀부.txt'),
        imagePath: 'assets/images/MH.png',
        recommendedAge: 9,
      ),
    ]);
  }

  List<Story> getAllStories() {
    return List.unmodifiable(_stories);
  }

  Story? getStoryById(String id) {
    try {
      return _stories.firstWhere((story) => story.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<String> getStoryContent(String storyId) async {
    final story = getStoryById(storyId);
    return story?.content ?? '';
  }
}
