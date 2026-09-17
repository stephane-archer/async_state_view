import 'package:async_state_view/src/async_state.dart';
import 'package:flutter/widgets.dart';

/// Builds a widget for a successful asynchronous result.
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

/// Renders one branch of a retained [AsyncState].
///
/// Unlike a future builder, this widget does not start or own asynchronous
/// work. The state owner passes its latest retained state in.
class AsyncStateBuilder<T> extends StatelessWidget {
  /// The current retained state to render.
  final AsyncState<T> state;

  /// Builds the widget displayed while work is in progress.
  final WidgetBuilder loading;

  /// Builds the widget displayed when work completes successfully.
  final AsyncStateDataBuilder<T> data;

  /// Builds the widget displayed when work fails.
  final AsyncStateErrorBuilder error;

  /// Creates a widget that renders exactly one branch of [state].
  const AsyncStateBuilder({
    required this.state,
    required this.loading,
    required this.data,
    required this.error,
    super.key,
  });

  @override
  Widget build(BuildContext context) => switch (state) {
        AsyncLoading<T>() => loading(context),
        AsyncData<T>(:final value) => data(context, value),
        AsyncError<T>(:final error, :final stackTrace) =>
          this.error(context, error, stackTrace),
      };
}
