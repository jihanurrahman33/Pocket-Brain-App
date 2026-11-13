/// A single application operation (Command pattern).
///
/// Every use case does exactly one thing and depends only on domain
/// abstractions, so it can be unit-tested with fakes.
abstract interface class UseCase<Output, Params> {
  Future<Output> call(Params params);
}

/// A use case that produces a stream of results over time.
abstract interface class StreamUseCase<Output, Params> {
  Stream<Output> call(Params params);
}

/// Parameter type for use cases that take no input.
final class NoParams {
  const NoParams();
}

const noParams = NoParams();
