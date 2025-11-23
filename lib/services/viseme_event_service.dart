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
        _controller.add({
          'viseme_id': data['viseme_id'],
          'audio_offset': data['audio_offset'],
        });
      } else if (data['type'] == 'audio') {
        _controller.add({'audio_path': data['path']});
      } else if (data['type'] == 'error') {
        _controller.add({'error': data['message']});
      }
    });
  }

  void sendTTSRequest(String text, String voice) {
    print(
        '[VisemeEventService] sendTTSRequest called: text=$text, voice=$voice');
    channel.sink.add(jsonEncode({"text": text, "voice": voice}));
  }

  Stream<Map<String, dynamic>> get events => _controller.stream;

  void dispose() {
    channel.sink.close();
    _controller.close();
  }
}
