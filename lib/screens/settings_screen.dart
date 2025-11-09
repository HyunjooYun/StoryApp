import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/story_provider.dart';
import '../models/story_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _selectedLanguage;
  late int _selectedAge;
  late String _selectedGender;
  late double _volume;
  
  final List<Map<String, String>> _languages = [
    {'code': '한국어', 'label': '한국어 Korean'},
    {'code': '일본어', 'label': '일본어 日本語'},
    {'code': '중국어', 'label': '중국어 中文'},
    {'code': '베트남어', 'label': '베트남어 Tiếng Việt'},
    {'code': '영어', 'label': '영어 English'},
    {'code': '독일어', 'label': '독일어 Deutsch'},
  ];
  
  @override
  void initState() {
    super.initState();
    final provider = Provider.of<StoryProvider>(context, listen: false);
    _selectedLanguage = provider.settings.language;
    _selectedAge = provider.settings.age;
    _selectedGender = provider.settings.gender;
  _volume = provider.settings.volume;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
              // Close button
              Positioned(
                top: 20,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              
              // Main content
              Column(
                children: [
                  const SizedBox(height: 30),
                  
                  // Title
                  const Column(
                    children: [
                      Text(
                        '설정 Settings',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Divider(color: Colors.white, thickness: 2),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Language selection
                          const Text(
                            '언어 Language',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildLanguageGrid(),
                          
                          const SizedBox(height: 30),
                          
                          // Age selection
                          Row(
                            children: [
                              const Text(
                                '연령 Age',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 30),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _selectedAge,
                                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF7C4DFF)),
                                    items: List.generate(8, (index) => index + 3).map((int age) {
                                      return DropdownMenuItem<int>(
                                        value: age,
                                        child: Text(
                                          '$age 세',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF7C4DFF),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (int? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _selectedAge = newValue;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 30),
                          
                          // Character selection
                          const Text(
                            '캐릭터 Character',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildCharacterCard('male', 'assets/images/MH.png', '민호')),
                              const SizedBox(width: 20),
                              Expanded(child: _buildCharacterCard('female', 'assets/images/SY.png', '수영')),
                            ],
                          ),
                          
                          const SizedBox(height: 30),
                          
                          // Volume slider
                          _buildSlider(
                            '소리크기 Sound Volume',
                            _volume,
                            (value) => setState(() => _volume = value),
                          ),

                          const SizedBox(height: 30),
                          
                          // Action buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildActionButton('완 료', () => _saveSettings(context)),
                              const SizedBox(width: 20),
                              _buildActionButton('취 소', () => Navigator.pop(context)),
                            ],
                          ),
                          
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // Home button
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton(
                    onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                    backgroundColor: const Color(0xFF5E35B1),
                    child: const Icon(Icons.home, color: Colors.white, size: 32),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLanguageGrid() {
    // 2개씩 3행으로 배치
    final rows = [
      [_languages[0], _languages[1]], // 한국어, 일본어
      [_languages[2], _languages[3]], // 중국어, 베트남어
      [_languages[4], _languages[5]], // 영어, 독일어
    ];
    return Column(
      children: rows.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((lang) {
            final isSelected = _selectedLanguage == lang['code'];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: SizedBox(
                width: (MediaQuery.of(context).size.width - 104) / 2.2,
                height: 60,
                child: ElevatedButton(
                  onPressed: () => setState(() => _selectedLanguage = lang['code']!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? const Color(0xFF5E35B1) : const Color(0xFF8E6BB8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: isSelected ? 6 : 2,
                  ),
                  child: Text(
                    lang['label']!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
  
  Widget _buildCharacterCard(String gender, String imagePath, String name) {
    final isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = gender),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5E6D3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF5E35B1) : Colors.transparent,
            width: 4,
          ),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                imagePath,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Icon(Icons.person, size: 60),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5E35B1),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSlider(String label, double value, Function(double) onChanged) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF9575CD),
              inactiveTrackColor: Colors.white38,
              thumbColor: const Color(0xFF5E35B1),
              overlayColor: const Color(0xFF5E35B1).withOpacity(0.3),
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            ),
            child: Slider(
              value: value,
              min: 0.3,
              max: 1.0,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 50,
          child: Text(
            '${(value * 100).toInt()}%',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: 200,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5E35B1),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 4,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  void _saveSettings(BuildContext context) {
    final newSettings = StorySettings(
      language: _selectedLanguage,
      age: _selectedAge,
      gender: _selectedGender,
      volume: _volume,
    );
    Provider.of<StoryProvider>(context, listen: false).updateSettings(newSettings);
    Navigator.pop(context);
  }
}
