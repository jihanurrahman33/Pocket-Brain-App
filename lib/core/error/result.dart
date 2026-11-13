import 'failure.dart';

/// The outcome of an operation that can fail in an expected way.
///
/// ```dart
/// final result = await saveCapture(request);
/// switch (result) {
///   case Success(:final value): ...
///   case Err(:final failure): ...
/// }
/// ```
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;

  /// The value, or null on failure.
  T? get valueOrNull => switch (this) {
    Success(:final value) => value,
    Err() => null,
  };

  /// The failure, or null on success.
  Failure? get failureOrNull => switch (this) {
    Success() => null,
    Err(:final failure) => failure,
  };

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) => switch (this) {
    Success(:final value) => onSuccess(value),
    Err(:final failure) => onFailure(failure),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;
}
