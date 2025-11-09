import 'package:audioplayers/audioplayers.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> play(String filePath, {void Function()? onComplete}) async {
    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(filePath));
    if (onComplete != null) {
      _audioPlayer.onPlayerComplete.listen((event) {
        onComplete();
      });
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
