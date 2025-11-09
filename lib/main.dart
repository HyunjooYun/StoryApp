import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/story_provider.dart';
import 'screens/home_screen.dart';
import 'services/openai_service.dart';
import 'services/azure_tts_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize services
  OpenAIService().initialize();
  AzureTTSService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => StoryProvider()..initialize(),
      child: MaterialApp(
        title: '동화구연',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          fontFamily: 'KoPubWorldDotum',
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
