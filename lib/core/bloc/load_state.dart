import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../error/failure.dart';
import '../error/result.dart';
import '../usecase/usecase.dart';

/// The state of a screen that loads one piece of data (sealed, so views
/// must handle every case).
sealed class LoadState<T> extends Equatable {
  const LoadState();

  @override
  List<Object?> get props => [];
}

final class Loading<T> extends LoadState<T> {
  const Loading();
}

final class Loaded<T> extends LoadState<T> {
  const Loaded(this.data);

  final T data;

  @override
  List<Object?> get props => [data];
}

final class LoadFailed<T> extends LoadState<T> {
  const LoadFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Loads data with a use case and reloads it whenever [changes] emits
/// (Template Method: subclasses provide [fetch]; Observer: [changes]).
abstract class AutoRefreshCubit<T> extends Cubit<LoadState<T>> {
  AutoRefreshCubit({required Stream<void> changes}) : super(Loading<T>()) {
    _subscription = changes.listen((_) => load());
  }

  late final StreamSubscription<void> _subscription;

  /// Reads the data; implemented by each screen's cubit.
  Future<Result<T>> fetch();

  /// The current data, if loaded.
  T? get data => switch (state) {
    Loaded(:final data) => data,
    _ => null,
  };

  /// Incremented per load so a slow, older load cannot overwrite a newer one.
  int _latestLoad = 0;

  Future<void> load() async {
    final ticket = ++_latestLoad;
    final result = await fetch();
    if (isClosed || ticket != _latestLoad) return;
    emit(result.fold(onSuccess: Loaded.new, onFailure: LoadFailed.new));
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}

/// Convenience for use cases that take no parameters.
extension RunNoParams<T> on UseCase<T, NoParams> {
  Future<T> run() => call(noParams);
}
