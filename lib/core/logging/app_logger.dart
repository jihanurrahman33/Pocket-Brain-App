import 'package:flutter/foundation.dart';

/// Minimal logging port so no layer calls `print` directly.
abstract interface class AppLogger {
  void info(String message);

  void error(String message, [Object? error, StackTrace? stackTrace]);
}

/// Logs to the debug console; silent in release builds.
final class DebugAppLogger implements AppLogger {
  const DebugAppLogger();

  @override
  void info(String message) {
    if (kDebugMode) debugPrint('[PocketBrain] $message');
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (!kDebugMode) return;
    debugPrint('[PocketBrain][ERROR] $message${error == null ? '' : ': $error'}');
    if (stackTrace != null) debugPrint(stackTrace.toString());
  }
}
