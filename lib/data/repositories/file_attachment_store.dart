import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/utils/id_generator.dart';
import '../../domain/entities/memory.dart';
import '../../domain/repositories/attachment_store.dart';

/// Keeps attachments as files in a private app folder, named by id so
/// user-chosen file names never leak into storage paths.
final class FileAttachmentStore implements AttachmentStore {
  FileAttachmentStore(this._directory, this._ids);

  final Directory _directory;
  final IdGenerator _ids;

  @override
  Future<Attachment> keep(String sourcePath, AttachmentKind kind, {bool move = false}) async {
    await _directory.create(recursive: true);
    final extension = p.extension(sourcePath).toLowerCase();
    final target = p.join(_directory.path, '${_ids.next()}$extension');
    final source = File(sourcePath);
    if (move) {
      try {
        await source.rename(target);
      } on FileSystemException {
        // Different file systems: copy, then remove the temporary file.
        await source.copy(target);
        await source.delete();
      }
    } else {
      await source.copy(target);
    }
    return Attachment(path: target, kind: kind);
  }

  @override
  Future<void> delete(Attachment attachment) async {
    // Only ever delete inside our own folder.
    if (!p.isWithin(_directory.path, attachment.path)) return;
    final file = File(attachment.path);
    if (file.existsSync()) await file.delete();
  }

  @override
  Future<void> clear() async {
    if (_directory.existsSync()) await _directory.delete(recursive: true);
  }
}
