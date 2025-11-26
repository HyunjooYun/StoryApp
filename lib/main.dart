import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/story_provider.dart';
import 'screens/home_screen.dart';
import 'services/openai_service.dart';
import 'services/azure_tts_service.dart';
import 'services/logging_service.dart';

// Used to prevent double-logging when forwarding debugPrint output through the
// original handler (which ultimately calls print() and hits the zone hook).
bool _forwardingDebugPrint = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LoggingService.instance.initialize();

  // Capture all print/debugPrint output so we keep a persistent log file even
  // for the packaged Windows build where stdout is not visible.
  final previousDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message == null) {
      return;
    }
    LoggingService.instance.log(message);
    _forwardingDebugPrint = true;
    try {
      previousDebugPrint(message, wrapWidth: wrapWidth);
    } finally {
      _forwardingDebugPrint = false;
    }
  };

  await dotenv.load(fileName: ".env");

  OpenAIService().initialize();
  await AzureTTSService().initialize();

  runZonedGuarded(() {
    runApp(const MyApp());
  }, (error, stackTrace) {
    LoggingService.instance
        .log('UNCAUGHT ERROR: $error\n$stackTrace');
  }, zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) {
    if (!_forwardingDebugPrint) {
      LoggingService.instance.log(line);
    }
    parent.print(zone, line);
  }));
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
