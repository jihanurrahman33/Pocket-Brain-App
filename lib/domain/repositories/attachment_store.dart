import '../entities/memory.dart';
import 'change_notifier.dart';

/// Keeps images and recordings in the app's private storage.
abstract interface class AttachmentStore implements Clearable {
  /// Puts the file at [sourcePath] into app storage and returns the
  /// attachment pointing at it. [move] is for temporary files the app owns
  /// (recordings); the user's own files (picked images) are always copied.
  Future<Attachment> keep(String sourcePath, AttachmentKind kind, {bool move = false});

  /// Deletes a kept file; missing files are ignored.
  Future<void> delete(Attachment attachment);
}
