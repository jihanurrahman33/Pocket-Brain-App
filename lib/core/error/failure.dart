import 'package:equatable/equatable.dart';

/// An expected, user-presentable error. Use cases return failures inside a
/// [Result] instead of throwing, so the presentation layer never needs to
/// know about infrastructure exceptions.
sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Reading or writing local storage failed.
final class StorageFailure extends Failure {
  const StorageFailure([super.message = 'Could not access local storage.']);
}

/// A network request (model download, link fetch) failed.
final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network error. Check your connection and try again.']);
}

/// The on-device model could not be installed, loaded or run.
final class ModelFailure extends Failure {
  const ModelFailure(super.message);
}

/// The requested item no longer exists.
final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'That item no longer exists.']);
}

/// The user cancelled a long-running operation.
final class CancelledFailure extends Failure {
  const CancelledFailure([super.message = 'Cancelled.']);
}

/// The input did not satisfy a business rule.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Anything unforeseen. Logged with full detail; shown with a short message.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Something went wrong.']);
}
