import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Lightweight logging utility that persists log lines to a session file.
class LoggingService {
  LoggingService._internal();

  static final LoggingService instance = LoggingService._internal();

  File? _logFile;
  bool _initialized = false;
  Future<void>? _pendingWrite;

  /// Initializes the logging sink and creates/rotates the log file.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    final supportDir = await getApplicationSupportDirectory();
    final logDir = Directory('${supportDir.path}/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    final now = DateTime.now();
    final fileName = 'story_app_${_yyyyMmDd(now)}.log';
    _logFile = File('${logDir.path}/$fileName');
    final header =
        '--- Session started ${now.toIso8601String()} ---${Platform.lineTerminator}';
    await _logFile!.writeAsString(header, mode: FileMode.append, flush: true);
    _initialized = true;
  }

  /// Write a log entry. Appends a timestamp automatically.
  void log(String message) {
    if (_logFile == null) {
      return;
    }
    final timestamp = DateTime.now().toIso8601String();
    final line = '[$timestamp] $message${Platform.lineTerminator}';
    _pendingWrite = (_pendingWrite ?? Future.value()).then((_) async {
      await _logFile!.writeAsString(line, mode: FileMode.append, flush: false);
    });
  }

  /// Flush all pending writes to disk.
  Future<void> flush() async {
    await _pendingWrite;
  }

  /// Returns the resolved log file path after initialization.
  String? get logFilePath => _logFile?.path;

  String _yyyyMmDd(DateTime dateTime) {
    final y = dateTime.year.toString().padLeft(4, '0');
    final m = dateTime.month.toString().padLeft(2, '0');
    final d = dateTime.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}
