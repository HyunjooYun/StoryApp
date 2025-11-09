import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  print('🔍 Testing API Keys...\n');

  // Read .env file manually
  final envFile = File('.env');
  if (!await envFile.exists()) {
    print('❌ .env file not found!');
    exit(1);
  }

  final envContent = await envFile.readAsString();
  final envLines = envContent.split('\n');
  
  String? openaiKey;
  String? azureKey;
  
  for (final line in envLines) {
    if (line.startsWith('OPENAI_API_KEY=')) {
      openaiKey = line.split('=')[1].trim();
    } else if (line.startsWith('AZURE_TTS_KEY=')) {
      azureKey = line.split('=')[1].trim();
    }
  }

  // Test OpenAI API
  print('📝 Testing OpenAI API...');
  if (openaiKey == null || openaiKey.isEmpty || openaiKey == 'your-openai-api-key-here') {
    print('❌ OpenAI API key not found or invalid in .env file\n');
  } else {
    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $openaiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'user', 'content': 'Say hello in Korean'}
          ],
          'max_tokens': 50,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'];
        print('✅ OpenAI API is working!');
        print('   Test response: $content\n');
      } else {
        print('❌ OpenAI API Error: ${response.statusCode}');
        print('   Response: ${response.body}\n');
      }
    } catch (e) {
      print('❌ OpenAI API Error: $e\n');
    }
  }

  // Test Azure TTS API
  print('🔊 Testing Azure TTS API...');
  if (azureKey == null || azureKey.isEmpty || azureKey == 'your-azure-tts-key-here') {
    print('❌ Azure TTS API key not found or invalid in .env file\n');
  } else {
    print('✅ Azure TTS key found: ${azureKey.substring(0, 8)}...\n');
  }

  print('✨ Test completed!');
}
