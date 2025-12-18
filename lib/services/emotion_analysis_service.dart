import 'dart:core';

enum EmotionType { worry, surprise, moved }

class EmotionAnalysisService {
  EmotionType? analyze(String sentence) {
    final normalized = sentence.toLowerCase();

    if (_containsAny(normalized, _worryKeywords)) {
      return EmotionType.worry;
    }
    if (_containsAny(normalized, _surpriseKeywords)) {
      return EmotionType.surprise;
    }
    if (_containsAny(normalized, _movedKeywords)) {
      return EmotionType.moved;
    }
    return null;
  }

  bool _containsAny(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  static const List<String> _worryKeywords = [
    '걱정',
    '걱정하',
    '걱정이',
    '걱정스러',
    '걱정했',
    '불안',
    '두려',
    '근심',
    '걱정돼',
    '염려',
    '근심하',
    '생각',
    'worry',
    'afraid',
    'anxious',
  ];

  static const List<String> _surpriseKeywords = [
    '놀랐',
    '놀라',
    '깜짝',
    '헉',
    'wow',
    'surpris',
    'amaze',
  ];

  static const List<String> _movedKeywords = [
    '감동',
    '고마워',
    '감사',
    '눈물',
    '뭉클',
    'touch',
    'moving',
    'grateful',
  ];
}
