import 'dart:async';

/// Shared implementation of `ChangeSource` for repositories.
mixin ChangeBroadcaster {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get changes => _controller.stream;

  /// Call after every visible write.
  void notifyChanged() {
    if (!_controller.isClosed) _controller.add(null);
  }

  Future<void> disposeChanges() => _controller.close();
}
