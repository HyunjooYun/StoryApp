import 'package:translator/translator.dart';

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();
  
  final GoogleTranslator _translator = GoogleTranslator();
  
  final Map<String, String> _languageCodes = {
    '한국어': 'ko',
    '영어': 'en',
    '일본어': 'ja',
    '중국어': 'zh-cn',
    '베트남어': 'vi',
  };
  
  Future<String> translate(String text, String targetLanguage) async {
    try {
      final langCode = _languageCodes[targetLanguage];
      if (langCode == null || langCode == 'ko') {
        return text; // Return original text if Korean or invalid language
      }
      
      final translation = await _translator.translate(
        text,
        from: 'ko',
        to: langCode,
      );
      
      return translation.text;
    } catch (e) {
      print('Translation error: $e');
      return text; // Return original text on error
    }
  }
  
  Future<List<String>> translateParagraphs(String text, String targetLanguage) async {
    final paragraphs = text.split('\n\n');
    final translations = <String>[];
    
    for (var paragraph in paragraphs) {
      if (paragraph.trim().isNotEmpty) {
        final translated = await translate(paragraph, targetLanguage);
        translations.add(translated);
      }
    }
    
    return translations;
  }
}
