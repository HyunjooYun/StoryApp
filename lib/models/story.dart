class Story {
  final String id;
  final String title;
  final String content;
  final String imagePath;
  final int recommendedAge;
  double progress; // 0.0 ~ 1.0
  String status; // 'pending', 'processing', 'completed'
  String? adaptedScript; // OpenAI로 각색된 스크립트
  List<String>? audioPaths; // Azure TTS로 생성된 오디오 파일 경로 리스트

  Story({
    required this.id,
    required this.title,
    required this.content,
    required this.imagePath,
    required this.recommendedAge,
    this.progress = 0.0,
    this.status = 'pending',
    this.adaptedScript,
    this.audioPaths,
  });
  
  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      imagePath: json['imagePath'],
      recommendedAge: json['recommendedAge'],
      progress: json['progress'] ?? 0.0,
      status: json['status'] ?? 'pending',
      adaptedScript: json['adaptedScript'],
      audioPaths: json['audioPaths'] != null
          ? List<String>.from(json['audioPaths'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'imagePath': imagePath,
      'recommendedAge': recommendedAge,
      'progress': progress,
      'status': status,
      'adaptedScript': adaptedScript,
      'audioPaths': audioPaths,
    };
  }
}
