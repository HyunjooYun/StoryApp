import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:story_app/services/azure_tts_service.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  final tts = AzureTTSService();
  tts.initialize();

  final text = '안녕하세요. 이것은 Azure TTS 테스트입니다.';
  final language = 'korean';
  final gender = 'female';
  final speed = 1.0;
  final pitch = 1.0;

  try {
    final filePath = await tts.generateAudio(
      text: text,
      language: language,
      characterGender: gender,
      speed: speed,
      pitch: pitch,
    );
    print('TTS 파일 생성 완료: $filePath');
  } catch (e) {
    print('TTS 생성 실패: $e');
  }
}
