import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/story_provider.dart';
import 'story_selection_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<StoryProvider>(
        builder: (context, provider, child) {
          final characterImage = provider.settings.getCharacterImage();
          
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF7C4DFF),
                  Color(0xFF536DFE),
                ],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  // Close button (X)
                  Positioned(
                    top: 20,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 32),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  
                  // Main content
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),
                        
                        // Title
                        const Column(
                          children: [
                            Text(
                              '동화 친구',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Story Whisperer',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w300,
                                color: Color(0xFFE6FF00),
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 50),
                        
                        // Character Image
                        Container(
                          width: 400,
                          height: 400,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5E6D3),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              characterImage,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(Icons.person, size: 100, color: Colors.grey),
                                );
                              },
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 60),
                        
                        // Play now button
                        SizedBox(
                          width: 500,
                          height: 70,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const StorySelectionScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF7C4DFF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(35),
                              ),
                              elevation: 4,
                            ),
                            child: const Text(
                              '동화 듣기 Play now',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Settings button
                        SizedBox(
                          width: 500,
                          height: 70,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SettingsScreen(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(35),
                              ),
                            ),
                            child: const Text(
                              '설정 Settings',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        
                        const Spacer(flex: 3),
                      ],
                    ),
                  ),
                  
                  // Version text
                  const Positioned(
                    bottom: 20,
                    right: 30,
                    child: Text(
                      'ver 1.0',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
