import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:async';

class VisemeEventService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _controller =
      StreamController.broadcast();
  bool _connecting = false;
  final String _url;

  VisemeEventService(String url) : _url = url {
    _connect();
  }

  void _connect() {
    if (_connecting) {
      return;
    }
    _connecting = true;
    debugPrint('[VisemeEventService] connecting to $_url');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_url));
      _channel!.stream.listen(
        (event) {
          debugPrint('[VisemeEventService] raw event: $event');
          final data = jsonDecode(event);
          final type = data['type'];
          switch (type) {
            case 'viseme':
              final audioOffset = data['audio_offset_ms'] ?? data['audio_offset'];
              debugPrint(
                  '[VisemeEventService] viseme id=${data['viseme_id']} offsetMs=$audioOffset');
              _controller.add({
                'type': 'viseme',
                'viseme_id': data['viseme_id'],
                'audio_offset_ms': audioOffset,
              });
              break;
            case 'audio':
              debugPrint('[VisemeEventService] audio payload path=${data['path']}');
              _controller.add({'type': 'audio', 'audio_path': data['path']});
              break;
            case 'error':
              debugPrint('[VisemeEventService] error=${data['message']}');
              _controller.add({
                'type': 'error',
                'error': data['message'],
                'message': data['message'],
              });
              break;
            case 'done':
              debugPrint('[VisemeEventService] synthesis done');
              _controller.add({'type': 'done'});
              break;
            default:
              debugPrint('[VisemeEventService] unknown event: $data');
              _controller.add({'type': 'unknown', 'payload': data});
          }
        },
        onDone: () {
          debugPrint('[VisemeEventService] connection closed. attempting reconnect');
          _connecting = false;
          Future.delayed(const Duration(milliseconds: 500), _connect);
        },
        onError: (error) {
          debugPrint('[VisemeEventService] stream error=$error');
          _controller.add({
            'type': 'error',
            'error': error.toString(),
            'message': error.toString(),
          });
          _connecting = false;
          Future.delayed(const Duration(milliseconds: 500), _connect);
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[VisemeEventService] connect failed: $e');
      _connecting = false;
      Future.delayed(const Duration(milliseconds: 500), _connect);
    }
  }

  void sendTTSRequest({
    required String text,
    required String voice,
    double? speakingRate,
  }) {
    debugPrint(
        '[VisemeEventService] sendTTSRequest called: text=$text, voice=$voice, speakingRate=$speakingRate');
    final Map<String, dynamic> payload = {
      'text': text,
      'voice': voice,
    };
    if (speakingRate != null) {
      payload['speaking_rate'] = speakingRate;
    }
    final sink = _channel?.sink;
    if (sink == null) {
      debugPrint('[VisemeEventService] WebSocket not connected; dropping TTS request');
      _controller.add({
        'type': 'error',
        'error': 'WebSocket not connected',
        'message': 'Viseme socket not ready. Please try again.',
      });
      _connect();
      return;
    }
    sink.add(jsonEncode(payload));
  }

  Stream<Map<String, dynamic>> get events => _controller.stream;

  void dispose() {
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _controller.close();
  }
}
