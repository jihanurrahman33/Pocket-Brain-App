/// Something whose data can change, observed by presentation (Observer).
abstract interface class ChangeSource {
  /// Emits after every visible write.
  Stream<void> get changes;
}

/// A store that can be wiped (used by "Delete all local data").
abstract interface class Clearable {
  Future<void> clear();
}
