import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';

class AzureTTSService {
  static final AzureTTSService _instance = AzureTTSService._internal();
  factory AzureTTSService() => _instance;
  AzureTTSService._internal();

  late final String _apiKey;
  late final String _region;
  late final String _endpoint;

  void initialize() {
    _apiKey = dotenv.env['AZURE_TTS_KEY'] ?? '';
    _region = dotenv.env['AZURE_TTS_REGION'] ?? 'koreacentral';
    _endpoint = dotenv.env['AZURE_TTS_ENDPOINT'] ??
        'https://$_region.tts.speech.microsoft.com/cognitiveservices/v1';
    if (_apiKey.isEmpty) {
      throw Exception('AZURE_TTS_KEY not found in .env file');
    }
  }

  /// Generate audio file from text using Azure TTS
  Future<String> generateAudio({
    required String text,
    required String language,
    String? characterGender,
    double speed = 1.0,
    double pitch = 1.0,
  }) async {
    try {
      // Select voice based on language and gender
      final voiceName = _getVoiceName(language, characterGender);
      // 로그: voiceName, text, speed, pitch
      print('AzureTTS generateAudio params:');
      print('  voiceName: $voiceName');
      print('  text: $text');
      print('  speed: $speed');
      print('  pitch: $pitch');

      // Create SSML
      final ssml = _createSSML(text, voiceName, speed, pitch);
      print('AzureTTS SSML: $ssml');

      // Call Azure TTS API
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Ocp-Apim-Subscription-Key': _apiKey,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'riff-16khz-16bit-mono-pcm',
          'User-Agent': 'StoryApp',
        },
        body: utf8.encode(ssml),
      );

      if (response.statusCode == 200) {
        print('Azure TTS status: [32m${response.statusCode}[0m');
        print('Azure TTS bodyBytes length: ${response.bodyBytes.length}');
        print('Azure TTS body (as text): ${utf8.decode(response.bodyBytes, allowMalformed: true)}');
        // Save audio file
        final audioPath = await _saveAudioFile(response.bodyBytes);
        return audioPath;
      } else {
        print('Azure TTS Error: [31m${response.statusCode}[0m - ${response.body}');
        throw Exception('Azure TTS Error: ${response.statusCode} - ${response.body}');
      }
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
      default:
        return 'ko-KR-SunHiNeural'; // Default to Korean female
    }
  }

  /// Create SSML for Azure TTS
  String _createSSML(String text, String voiceName, double speed, double pitch) {
    // Convert speed (0.5 - 2.0) to percentage (-50% to +100%)
    final speedPercent = ((speed - 1.0) * 100).toStringAsFixed(0);
    final speedStr = speedPercent.startsWith('-') ? speedPercent : '+$speedPercent';
    // Convert pitch to semitones (-50% to +50%)
    final pitchPercent = ((pitch - 1.0) * 50).toStringAsFixed(0);
    final pitchStr = pitchPercent.startsWith('-') ? pitchPercent : '+$pitchPercent';
    return '''<speak version='1.0' xml:lang='ko-KR'>
  <voice name='$voiceName'>
    <prosody rate='${speedStr}%' pitch='${pitchStr}%'>
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
  final filePath = '${audioDir.path}/tts_$timestamp.wav';
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
