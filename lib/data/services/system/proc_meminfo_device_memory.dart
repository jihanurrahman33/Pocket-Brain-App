import 'dart:io';

import '../../../domain/services/device_memory.dart';

/// Reads `MemTotal` from `/proc/meminfo` (Linux and Android). Elsewhere, or
/// if the file cannot be read, the size is unknown.
final class ProcMeminfoDeviceMemory implements DeviceMemory {
  const ProcMeminfoDeviceMemory([this._path = '/proc/meminfo']);

  final String _path;

  static final _memTotal = RegExp(r'^MemTotal:\s+(\d+)\s*kB', multiLine: true);

  @override
  Future<int?> totalBytes() async {
    try {
      final file = File(_path);
      if (!file.existsSync()) return null;
      final kilobytes = _memTotal.firstMatch(await file.readAsString())?[1];
      return kilobytes == null ? null : int.parse(kilobytes) * 1024;
    } on FileSystemException {
      return null;
    }
  }
}
