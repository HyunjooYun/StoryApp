import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import '../models/voice_config.dart';
import 'package:flutter/services.dart' show rootBundle;

class AzureTTSService {
  static final AzureTTSService _instance = AzureTTSService._internal();
  factory AzureTTSService() => _instance;
  AzureTTSService._internal();

  late final String _apiKey;
  late final String _region;
  late final String _endpoint;

  VoiceConfig? _voiceConfig;

  Future<void> initialize() async {
    _apiKey = dotenv.env['AZURE_TTS_KEY'] ?? '';
    _region = dotenv.env['AZURE_TTS_REGION'] ?? 'koreacentral';
    _endpoint = dotenv.env['AZURE_TTS_ENDPOINT'] ??
        'https://$_region.tts.speech.microsoft.com/cognitiveservices/v1';
    if (_apiKey.isEmpty) {
      throw Exception('AZURE_TTS_KEY not found in .env file');
    }
    // voice_config.json 로드
    _voiceConfig = await VoiceConfigLoader.loadFromAsset();
  }

  /// 특수문자 이스케이프
  String _xmlEscape(String input) => input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  /// voiceName에서 언어코드 추출 (예: "ko-KR-SeoHyeonNeural" -> "ko-KR")
  String _langFromVoice(String voiceName) {
    final i = voiceName.indexOf('-');
    if (i > 0) {
      final j = voiceName.indexOf('-', i + 1);
      if (j > 0) return voiceName.substring(0, j);
    }
    // 실패 시 한국어 기본
    return 'ko-KR';
  }

  Future<String> generateAudio({
    required String text,
    required String language,
    String? characterGender,
    double? speed,
    double? pitch,
    int? age,
  }) async {
    try {
      // voice_config에서 값 가져오기
      String finalRate = '1.0';
      String finalPitch = '0%';
      if (_voiceConfig != null) {
        final langConfig = _voiceConfig!.languages[language] ?? _voiceConfig!.languages['한국어'];
        AgeRule? rule;
        if (langConfig != null && age != null) {
          rule = langConfig.getAgeRule(age);
        }
        finalRate = rule?.rate ?? _voiceConfig!.defaultConfig.rate;
        finalPitch = rule?.pitch ?? _voiceConfig!.defaultConfig.pitch;
      }
      // 파라미터 우선순위: 직접 전달 > config
      final usedRate = speed != null ? speed.toString() : finalRate;
      final usedPitch = pitch != null ? pitch.toString() : finalPitch;
      final voiceName = _getVoiceName(language, characterGender);
      print('AzureTTS generateAudio params:');
      print('  voiceName: $voiceName');
      print('  text: $text');
  print('  rate: $usedRate');
  print('  pitch: $usedPitch');
  final ssml = _createSSML_raw(text, voiceName, usedRate, usedPitch);
      print('AzureTTS SSML: $ssml');
      final uri = Uri.parse(_endpoint);
      final req = http.Request('POST', uri)
        ..headers.addAll({
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-24khz-48kbitrate-mono-mp3',
          'Ocp-Apim-Subscription-Key': _apiKey,
          'Ocp-Apim-Subscription-Region': _region,
          'Accept': '*/*',
          'User-Agent': 'StoryApp',
        })
        ..body = ssml;
      final streamed = await http.Client().send(req);
      print('Azure TTS status: \x1B[32m[32m[0m${streamed.statusCode}\x1B[0m');
      if (streamed.statusCode != 200) {
        final errText = await streamed.stream.bytesToString();
        print('Azure TTS Error Body: $errText');
        throw Exception('Azure TTS Error: ${streamed.statusCode} - $errText');
      }
      final bytes = await streamed.stream.toBytes();
      print('Azure TTS received bytes: ${bytes.length}');
      if (bytes.isEmpty) {
        throw Exception('Azure TTS returned empty audio bytes');
      }
      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/audio');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${audioDir.path}/tts_$timestamp.mp3';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      final len = await file.length();
      if (len == 0) {
        throw Exception('Saved audio is empty');
      }
      return filePath;
    } catch (e) {
      throw Exception('Failed to generate audio: $e');
    }
  }

  /// Get voice name based on language and gender
  String _getVoiceName(String language, String? gender) {
    final isFemale = gender?.toLowerCase() == 'female' || gender == '여자';
    switch (language.toLowerCase()) {
      case 'korean':
      case '한국어':
        return isFemale ? 'ko-KR-SeoHyeonNeural' : 'ko-KR-HyunsuNeural';
      case 'english':
      case '영어':
        return isFemale ? 'en-US-AnaNeural' : 'en-US-JasonNeural';
      case 'chinese':
      case '중국어':
        return isFemale ? 'zh-CN-XiaoyouNeural' : 'zh-CN-YunxiaNeural';
      case 'japanese':
      case '일본어':
        return 'ja-JP-AoiNeural';
      case 'spanish':
      case '스페인어':
        return isFemale ? 'es-ES-ElviraNeural' : 'es-ES-AlvaroNeural';
      case 'german':
      case '독일어':
        return isFemale ? 'de-DE-GiselaNeural' : 'de-DE-ConradNeural';
      default:
        return 'ko-KR-SunHiNeural'; // Default to Korean female
    }
  }

  /// Create SSML for Azure TTS
  String _createSSML_raw(
      String text, String voiceName, String rate, String pitch) {
    final safeText = _xmlEscape(text);
    final lang = _langFromVoice(voiceName);
    return '''<speak version='1.0' xml:lang='$lang'>
  <voice name='$voiceName'>
    <prosody rate='$rate' pitch='$pitch'>
      $text
    </prosody>
  </voice>
</speak>''';
  }

  /// Save audio file to local storage
  Future<String> _saveAudioFile(List<int> audioBytes) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${directory.path}/audio');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${audioDir.path}/tts_$timestamp.mp3';
      final file = File(filePath);
      await file.writeAsBytes(audioBytes);
      return filePath;
    } catch (e) {
      throw Exception('Failed to save audio file: $e');
    }
  }

  /// Generate audio for multiple text segments
  Future<List<String>> generateAudioSegments({
    required List<String> textSegments,
    required String language,
    String? characterGender,
    double speed = 1.0,
    double pitch = 1.0,
    Function(int current, int total)? onProgress,
  }) async {
    final audioPaths = <String>[];
    for (int i = 0; i < textSegments.length; i++) {
      if (textSegments[i].trim().isEmpty) continue;
      try {
        final audioPath = await generateAudio(
          text: textSegments[i],
          language: language,
          characterGender: characterGender,
          speed: speed,
          pitch: pitch,
        );
        audioPaths.add(audioPath);
        onProgress?.call(i + 1, textSegments.length);
      } catch (e) {
        print('Error generating audio for segment $i: $e');
        // Continue with other segments even if one fails
      }
    }
    return audioPaths;
  }
}
