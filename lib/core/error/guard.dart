import '../logging/app_logger.dart';
import 'failure.dart';
import 'result.dart';

/// Thrown by infrastructure to report a specific, expected [Failure].
final class FailureException implements Exception {
  const FailureException(this.failure);

  final Failure failure;

  @override
  String toString() => 'FailureException(${failure.message})';
}

/// Runs [body] and converts any exception into an [Err], logging the
/// unexpected ones. Use cases wrap their work in this so presentation only
/// ever sees [Result]s.
Future<Result<T>> guard<T>(AppLogger logger, String operation, Future<T> Function() body) async {
  try {
    return Success(await body());
  } on FailureException catch (e) {
    return Err(e.failure);
  } on Object catch (e, s) {
    logger.error('$operation failed', e, s);
    return const Err(UnexpectedFailure());
  }
}
