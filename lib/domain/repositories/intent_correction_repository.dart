import '../entities/user_intent.dart';
import 'change_notifier.dart';

/// Corrections the user made with "Not what I meant", kept on the device.
abstract interface class IntentCorrectionRepository implements Clearable {
  /// Newest first.
  Future<List<IntentExample>> recent({int limit = 8});

  Future<void> add(IntentExample example);
}
