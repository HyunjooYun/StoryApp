import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');
  final apiKey = dotenv.env['AZURE_TTS_KEY'] ?? '';
  final region = dotenv.env['AZURE_TTS_REGION'] ?? 'koreacentral';
  final endpoint = dotenv.env['AZURE_TTS_ENDPOINT'] ??
      'https://$region.tts.speech.microsoft.com/cognitiveservices/v1';

  if (apiKey.isEmpty) {
    print('AZURE_TTS_KEY not found in .env file');
    return;
  }

  final text = '안녕하세요, Azure TTS 테스트입니다.';
  final voiceName = 'ko-KR-SeoHyeonNeural';
  final ssml = '''<speak version='1.0' xml:lang='ko-KR'>
  <voice name='$voiceName'>
    <prosody rate='+0%' pitch='+0%'>$text</prosody>
  </voice>
</speak>''';

  try {
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Ocp-Apim-Subscription-Key': apiKey,
        'Content-Type': 'application/ssml+xml',
        'X-Microsoft-OutputFormat': 'audio-24khz-48kbitrate-mono-mp3',
        'User-Agent': 'AzureTTS-Sample',
        'Ocp-Apim-Subscription-Region': region,
      },
      body: utf8.encode(ssml),
    );

    print('Status: [32m${response.statusCode}[0m');
    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      final file = File('azure_tts_sample.mp3');
      await file.writeAsBytes(response.bodyBytes);
      print('Audio saved: azure_tts_sample.mp3');
    } else {
      print('Error: ${response.statusCode}');
      print('Body: ${response.body}');
    }
  } catch (e) {
    print('Exception: $e');
  }
}
