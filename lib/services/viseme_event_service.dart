import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:async';

class VisemeEventService {
  final WebSocketChannel channel;
  StreamController<Map<String, dynamic>> _controller =
      StreamController.broadcast();

  VisemeEventService(String url)
      : channel = WebSocketChannel.connect(Uri.parse(url)) {
    channel.stream.listen((event) {
      final data = jsonDecode(event);
      if (data['type'] == 'viseme') {
        final audioOffset = data['audio_offset_ms'] ?? data['audio_offset'];
        _controller.add({
          'type': 'viseme',
          'viseme_id': data['viseme_id'],
          'audio_offset_ms': audioOffset,
        });
      } else if (data['type'] == 'audio') {
        _controller.add({'type': 'audio', 'audio_path': data['path']});
      } else if (data['type'] == 'error') {
        _controller.add({
          'type': 'error',
          'error': data['message'],
          'message': data['message'],
        });
      }
    });
  }

  void sendTTSRequest({
    required String text,
    required String voice,
    double? speakingRate,
  }) {
    print(
        '[VisemeEventService] sendTTSRequest called: text=$text, voice=$voice, speakingRate=$speakingRate');
    final Map<String, dynamic> payload = {
      'text': text,
      'voice': voice,
    };
    if (speakingRate != null) {
      payload['speaking_rate'] = speakingRate;
    }
    channel.sink.add(jsonEncode(payload));
  }

  Stream<Map<String, dynamic>> get events => _controller.stream;

  void dispose() {
    channel.sink.close();
    _controller.close();
  }
}
