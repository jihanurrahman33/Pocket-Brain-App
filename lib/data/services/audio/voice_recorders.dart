import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:record/record.dart' as rec;

import '../../../core/utils/id_generator.dart';
import '../../../domain/services/ai_services.dart';

/// Records 16 kHz mono WAV — what the on-device model listens to best.
const _sampleRate = 16000;

/// Linux desktop recorder using the system's PipeWire (`pw-record`) or ALSA
/// (`arecord`) tool, so no extra packages are needed on a standard desktop.
final class CommandLineVoiceRecorder implements VoiceRecorder {
  CommandLineVoiceRecorder(this._directory, this._ids);

  final Directory _directory;
  final IdGenerator _ids;
  Process? _process;
  String? _path;

  static const _tools = ['pw-record', 'arecord'];

  Future<String?> _availableTool() async {
    for (final tool in _tools) {
      final which = await Process.run('which', [tool]);
      if (which.exitCode == 0) return tool;
    }
    return null;
  }

  @override
  Future<bool> isSupported() async => await _availableTool() != null;

  @override
  Future<void> start() async {
    if (_process != null) return;
    final tool = await _availableTool();
    if (tool == null) {
      throw const FileSystemException('No recorder found (install pipewire or alsa-utils).');
    }
    await _directory.create(recursive: true);
    final path = p.join(_directory.path, '${_ids.next()}.wav');
    _process = await Process.start(tool, switch (tool) {
      'pw-record' => ['--rate', '$_sampleRate', '--channels', '1', '--format', 's16', path],
      _ => ['-q', '-f', 'S16_LE', '-r', '$_sampleRate', '-c', '1', '-t', 'wav', path],
    });
    _path = path;
  }

  @override
  Future<String> stop() async {
    final process = _process;
    final path = _path;
    if (process == null || path == null) throw StateError('Not recording');
    _process = null;
    _path = null;
    // SIGINT lets the tool finish the WAV header properly.
    process.kill(ProcessSignal.sigint);
    await process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        process.kill();
        return -1;
      },
    );
    return path;
  }

  @override
  Future<void> cancel() async {
    try {
      final path = await stop();
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on StateError {
      // Not recording.
    }
  }
}

/// Mobile recorder (Android/iOS) using the `record` plugin.
final class PluginVoiceRecorder implements VoiceRecorder {
  PluginVoiceRecorder(this._directory, this._ids, [rec.AudioRecorder? recorder])
    : _recorder = recorder ?? rec.AudioRecorder();

  final Directory _directory;
  final IdGenerator _ids;
  final rec.AudioRecorder _recorder;

  @override
  Future<bool> isSupported() => _recorder.hasPermission(request: false);

  @override
  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw const FileSystemException('Microphone permission was not granted.');
    }
    await _directory.create(recursive: true);
    await _recorder.start(
      const rec.RecordConfig(
        encoder: rec.AudioEncoder.wav,
        sampleRate: _sampleRate,
        numChannels: 1,
      ),
      path: p.join(_directory.path, '${_ids.next()}.wav'),
    );
  }

  @override
  Future<String> stop() async {
    final path = await _recorder.stop();
    if (path == null) throw StateError('Not recording');
    return path;
  }

  @override
  Future<void> cancel() => _recorder.cancel();
}
