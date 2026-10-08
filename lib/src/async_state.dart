/// The retained outcome of asynchronous work, independent of UI subscriptions.
///
/// States compare by value, so a listener that selects one part of a larger
/// state with [mapValue] can skip rebuilds while that part is unchanged. Call
/// [withoutCarriedValue] first to also skip them on progress updates.
/// Equality ignores the type argument, so `const AsyncLoading()` equals an
/// `AsyncLoading<User>()`.
sealed class AsyncState<T> {
  const AsyncState._();

  /// Whether a value is available: an [AsyncData], or an [AsyncLoading] or
  /// [AsyncError] created with `withValue`.
  ///
  /// Distinguishes a missing value from a null value when [T] is nullable.
  bool get hasValue;

  /// The available value (see [hasValue]).
  ///
  /// When there is no value, a loading state throws a [StateError], and an
  /// error rethrows its [AsyncError.error] with its [AsyncError.stackTrace].
  T get requireValue;

  /// The available value (see [hasValue]), otherwise null.
  T? get valueOrNull;

  /// Transforms the value, keeping the kind of state.
  ///
  /// Loading and error states carry the transformed value if they had one, and
  /// an error keeps its error and stack trace.
  ///
  /// An exception thrown by [transform] propagates to the caller instead of
  /// becoming an [AsyncError].
  AsyncState<R> mapValue<R>(R Function(T value) transform);

  /// A failed state that keeps the current value, for reporting a failure.
  ///
  /// The result carries the current value if there is one, such as the
  /// previous result after a failed refresh.
  AsyncError<T> toError(Object error, StackTrace stackTrace) => hasValue
      ? AsyncError<T>.withValue(error, stackTrace, requireValue)
      : AsyncError<T>(error, stackTrace);

  /// A loading state that keeps the current value, for refreshing a result
  /// while it stays visible.
  ///
  /// The result carries the current value if there is one, and a loading
  /// state is returned as is. An error's error and stack trace are not kept.
  ///
  /// To start or restart work that publishes partial progress, use
  /// `const AsyncLoading()` instead. Otherwise the kept value, such as the
  /// progress of a previous or abandoned run, appears as progress of the new
  /// run until its first update.
  AsyncLoading<T> toLoading() =>
      hasValue ? AsyncLoading<T>.withValue(requireValue) : AsyncLoading<T>();

  /// This state without the value a loading or error state carries.
  ///
  /// The result of a loading state or an error has no value, and an error
  /// keeps its error and stack trace; data is returned as is. Afterwards, only
  /// an [AsyncData] has a value.
  ///
  /// The dropped value can be partial progress, or a previous result kept
  /// while refreshing or after a failed refresh.
  ///
  /// A selector that compares by `==` can call it before [mapValue] to skip
  /// rebuilds on progress updates. Called first, it also keeps the transform
  /// from running on partial progress.
  AsyncState<T> withoutCarriedValue();
}

/// An asynchronous operation whose result is not yet available.
///
/// It may carry a value in the meantime, such as partial progress or the
/// previous result while refreshing.
final class AsyncLoading<T> extends AsyncState<T> {
  final T? _value;

  @override
  final bool hasValue;

  /// Creates a loading state without a value.
  const AsyncLoading()
      : _value = null,
        hasValue = false,
        super._();

  /// Creates a loading state that carries [value] until the work completes.
  const AsyncLoading.withValue(T value)
      : _value = value,
        hasValue = true,
        super._();

  @override
  int get hashCode => Object.hash(hasValue, _value);

  @override
  T get requireValue =>
      hasValue ? _value as T : throw StateError('$this has no value.');

  @override
  T? get valueOrNull => _value;

  @override
  bool operator ==(Object other) =>
      identical(other, this) ||
      other is AsyncLoading<Object?> &&
          hasValue == other.hasValue &&
          _value == other._value;

  @override
  AsyncLoading<R> mapValue<R>(R Function(T value) transform) => hasValue
      ? AsyncLoading<R>.withValue(transform(requireValue))
      : AsyncLoading<R>();

  @override
  AsyncLoading<T> toLoading() => this;

  @override
  String toString() =>
      hasValue ? 'AsyncLoading<$T>.withValue($_value)' : 'AsyncLoading<$T>()';

  @override
  AsyncLoading<T> withoutCarriedValue() => hasValue ? AsyncLoading<T>() : this;
}

/// An asynchronous operation that completed with [value].
final class AsyncData<T> extends AsyncState<T> {
  /// The value produced by the asynchronous operation.
  final T value;

  /// Creates a successful state containing [value].
  const AsyncData(this.value) : super._();

  @override
  int get hashCode => value.hashCode;

  @override
  bool get hasValue => true;

  @override
  T get requireValue => value;

  @override
  T? get valueOrNull => value;

  @override
  bool operator ==(Object other) =>
      identical(other, this) ||
      other is AsyncData<Object?> && value == other.value;

  @override
  AsyncData<R> mapValue<R>(R Function(T value) transform) =>
      AsyncData<R>(transform(value));

  @override
  String toString() => 'AsyncData<$T>($value)';

  @override
  AsyncData<T> withoutCarriedValue() => this;
}

/// An asynchronous operation that failed with [error] and [stackTrace].
///
/// It may keep a value, such as the previous result after a failed refresh.
final class AsyncError<T> extends AsyncState<T> {
  /// The error produced by the asynchronous operation.
  final Object error;

  /// The stack trace associated with [error].
  final StackTrace stackTrace;

  final T? _value;

  @override
  final bool hasValue;

  /// Creates a failed state containing [error] and [stackTrace], without a
  /// value.
  const AsyncError(this.error, this.stackTrace)
      : _value = null,
        hasValue = false,
        super._();

  /// Creates a failed state containing [error] and [stackTrace] that keeps
  /// [value].
  const AsyncError.withValue(this.error, this.stackTrace, T value)
      : _value = value,
        hasValue = true,
        super._();

  @override
  int get hashCode => Object.hash(error, stackTrace, hasValue, _value);

  @override
  T get requireValue =>
      hasValue ? _value as T : Error.throwWithStackTrace(error, stackTrace);

  @override
  T? get valueOrNull => _value;

  @override
  bool operator ==(Object other) =>
      identical(other, this) ||
      other is AsyncError<Object?> &&
          error == other.error &&
          stackTrace == other.stackTrace &&
          hasValue == other.hasValue &&
          _value == other._value;

  @override
  AsyncError<R> mapValue<R>(R Function(T value) transform) => hasValue
      ? AsyncError<R>.withValue(error, stackTrace, transform(requireValue))
      : AsyncError<R>(error, stackTrace);

  @override
  String toString() => hasValue
      ? 'AsyncError<$T>.withValue($error, $_value)'
      : 'AsyncError<$T>($error)';

  @override
  AsyncError<T> withoutCarriedValue() =>
      hasValue ? AsyncError<T>(error, stackTrace) : this;
}
