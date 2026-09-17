/// The retained outcome of asynchronous work, independent of UI subscriptions.
sealed class AsyncState<T> {
  const AsyncState._();
}

/// An asynchronous operation whose result is not yet available.
final class AsyncLoading<T> extends AsyncState<T> {
  /// Creates a loading state.
  const AsyncLoading() : super._();
}

/// An asynchronous operation that completed with [value].
final class AsyncData<T> extends AsyncState<T> {
  /// The value produced by the asynchronous operation.
  final T value;

  /// Creates a successful state containing [value].
  const AsyncData(this.value) : super._();
}

/// An asynchronous operation that failed with [error] and [stackTrace].
final class AsyncError<T> extends AsyncState<T> {
  /// The error produced by the asynchronous operation.
  final Object error;

  /// The stack trace associated with [error].
  final StackTrace stackTrace;

  /// Creates a failed state containing [error] and [stackTrace].
  const AsyncError(this.error, this.stackTrace) : super._();
}
