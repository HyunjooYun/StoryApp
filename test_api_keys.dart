import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'lib/services/openai_service.dart';
import 'lib/services/azure_tts_service.dart';

Future<void> main() async {
  print('🔍 Testing API Keys...\n');
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Test OpenAI API
  print('📝 Testing OpenAI API...');
  try {
    final openAI = OpenAIService();
    openAI.initialize();
    
    // Simple test: translate a short text
    final result = await openAI.translateText(
      text: '안녕하세요',
      targetLanguage: 'English',
    );
    
    print('✅ OpenAI API is working!');
    print('   Test translation: 안녕하세요 → $result\n');
  } catch (e) {
    print('❌ OpenAI API Error: $e\n');
  }
  
  // Test Azure TTS API
  print('🔊 Testing Azure TTS API...');
  try {
    final azureTTS = AzureTTSService();
    azureTTS.initialize();
    
    // Simple test: generate short audio
    final audioPath = await azureTTS.generateAudio(
      text: '안녕하세요',
      language: 'Korean',
      characterGender: 'female',
    );
    
    print('✅ Azure TTS API is working!');
    print('   Audio saved at: $audioPath\n');
  } catch (e) {
    print('❌ Azure TTS API Error: $e\n');
  }
  
  print('✨ Test completed!');
}
