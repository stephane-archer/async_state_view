import 'package:async_state_view/src/async_state.dart';
import 'package:flutter/widgets.dart';

/// Builds a widget for an available value: a successful result, or the value
/// a loading state carries.
typedef AsyncStateDataBuilder<T> = Widget Function(
  BuildContext context,
  T value,
);

/// Builds a widget for a failed asynchronous result.
typedef AsyncStateErrorBuilder = Widget Function(
  BuildContext context,
  Object error,
  StackTrace stackTrace,
);

/// Builds a widget for a failed asynchronous result that keeps a value, such
/// as the previous result after a failed refresh.
typedef AsyncStateErrorWithValueBuilder<T> = Widget Function(
  BuildContext context,
  Object error,
  StackTrace stackTrace,
  T value,
);

/// Renders one branch of a retained [AsyncState].
///
/// Unlike a future builder, this widget does not start or own asynchronous
/// work. The state owner passes its latest retained state in.
class AsyncStateBuilder<T> extends StatelessWidget {
  /// The current retained state to render.
  final AsyncState<T> state;

  /// Builds the widget displayed while work is in progress.
  ///
  /// Also used for a loading state with a value when [loadingWithValue] is
  /// omitted.
  final WidgetBuilder loading;

  /// Builds the widget displayed while work is in progress and a value is
  /// available, such as partial progress or the previous result.
  ///
  /// When omitted, [loading] is used and the value is not shown. To keep a
  /// refreshing result visible, pass the same function as [data].
  final AsyncStateDataBuilder<T>? loadingWithValue;

  /// Builds the widget displayed when work completes successfully.
  final AsyncStateDataBuilder<T> data;

  /// Builds the widget displayed when work fails.
  ///
  /// Also used for an error with a value when [errorWithValue] is omitted.
  final AsyncStateErrorBuilder error;

  /// Builds the widget displayed when work fails and a value is available,
  /// such as the previous result after a failed refresh.
  final AsyncStateErrorWithValueBuilder<T>? errorWithValue;

  /// Creates a widget that renders exactly one branch of [state].
  const AsyncStateBuilder({
    required this.state,
    required this.loading,
    required this.data,
    required this.error,
    this.loadingWithValue,
    this.errorWithValue,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final loadingWithValue = this.loadingWithValue;
    final errorWithValue = this.errorWithValue;
    return switch (state) {
      AsyncLoading<T>(hasValue: true, requireValue: final value)
          when loadingWithValue != null =>
        loadingWithValue(context, value),
      AsyncLoading<T>() => loading(context),
      AsyncData<T>(:final value) => data(context, value),
      AsyncError<T>(
        hasValue: true,
        :final error,
        :final stackTrace,
        requireValue: final value,
      )
          when errorWithValue != null =>
        errorWithValue(context, error, stackTrace, value),
      AsyncError<T>(:final error, :final stackTrace) =>
        this.error(context, error, stackTrace),
    };
  }
}
