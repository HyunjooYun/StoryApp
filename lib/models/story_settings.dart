class StorySettings {
  final String language;
  final int age;
  final String gender;
  final double speechRate;
  final double pitch;
  final double volume;
  
  StorySettings({
    required this.language,
    required this.age,
    required this.gender,
    this.speechRate = 0.6,
    this.pitch = 1.0,
    this.volume = 0.9,
  });
  
  String getCharacterImage() {
    return gender == 'male' 
        ? 'assets/images/MH.png' 
        : 'assets/images/SY.png';
  }
  
  String getCharacterName() {
    return gender == 'male' ? '민호' : '수영';
  }
  
  StorySettings copyWith({
    String? language,
    int? age,
    String? gender,
    double? speechRate,
    double? pitch,
    double? volume,
  }) {
    return StorySettings(
      language: language ?? this.language,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'language': language,
      'age': age,
      'gender': gender,
      'speechRate': speechRate,
      'pitch': pitch,
      'volume': volume,
    };
  }
  
  factory StorySettings.fromJson(Map<String, dynamic> json) {
    return StorySettings(
      language: json['language'] ?? '한국어',
      age: json['age'] ?? 4,
      gender: json['gender'] ?? 'male',
      speechRate: json['speechRate'] ?? 0.6,
      pitch: json['pitch'] ?? 1.0,
      volume: json['volume'] ?? 0.9,
    );
  }
}
