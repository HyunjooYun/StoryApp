import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  static final OpenAIService _instance = OpenAIService._internal();
  factory OpenAIService() => _instance;
  OpenAIService._internal();

  late final String _apiKey;
  final String _baseUrl = 'https://api.openai.com/v1';

  void initialize() {
    _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      throw Exception('OPENAI_API_KEY not found in .env file');
    }
  }

  /// Generate age-appropriate script from story content
  Future<String> generateAgeAppropriateScript({
    required String storyContent,
    required int age,
    required String language,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': '''You are a warm and friendly children's storyteller who loves telling stories to kids.
You speak in a gentle, friendly tone using simple words that children can easily understand.
You make stories fun and exciting while teaching important lessons.
You are like a kind grandmother or grandfather reading bedtime stories.'''
            },
            {
              'role': 'user',
              'content': '''Please retell this Korean fairy tale for a $age-year-old child in a warm, friendly way.
Target language: $language

Original story:
$storyContent

How to tell the story:
1. Use very simple, friendly words that a $age-year-old can understand (like "예쁜", "착한", "기쁜" instead of formal words)
2. Use conversational endings like "~했어요", "~랍니다" to sound warm and friendly
3. Make the story exciting and fun to listen to
4. Keep the important lesson from the original story
5. Tell it in $language language
6. IMPORTANT FORMAT: Write each sentence on a separate line
   - After every sentence ending with ., !, or ?, press Enter to start a new line
   - Example format:
     옛날 옛날에 착한 소녀가 살았어요.
     소녀의 이름은 콩쥐였어요.
     콩쥐는 정말 예쁘고 착했답니다.
7. IMPORTANT LENGTH: The total length must be MAXIMUM ${_getRecommendedLength(age)} characters (including spaces and newlines)
8. Make sure the story does NOT exceed ${_getRecommendedLength(age)} characters

Return only the story text in a friendly tone, with each sentence on a new line, without any additional commentary.'''
            }
          ],
          'temperature': 0.7,
          'max_tokens': 2000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'] as String;
        return content.trim();
      } else {
        throw Exception('OpenAI API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to generate script: $e');
    }
  }

  /// Get recommended story length based on age (in characters)
  int _getRecommendedLength(int age) {
    if (age <= 4) return 700;   // 4살 이하: 700자 이하
    if (age <= 7) return 1000;  // 7살 이하: 1000자 이하
    if (age <= 10) return 1200; // 10살 이하: 1200자 이하
    return 1500;                // 그 이상: 1500자 이하
  }

  /// Translate text to target language
  Future<String> translateText({
    required String text,
    required String targetLanguage,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a professional translator. Translate the given text accurately while maintaining the tone and style.'
            },
            {
              'role': 'user',
              'content': 'Translate the following text to $targetLanguage:\n\n$text'
            }
          ],
          'temperature': 0.3,
          'max_tokens': 2000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'] as String;
        return content.trim();
      } else {
        throw Exception('OpenAI API Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to translate: $e');
    }
  }
}
