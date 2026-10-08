import 'package:async_state_view/async_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget subject(AsyncState<int> state) => MaterialApp(
        home: AsyncStateBuilder<int>(
          state: state,
          loading: (_) => const Text('loading'),
          data: (_, value) => Text('data: $value'),
          error: (_, error, stackTrace) => Text('error: $error\n$stackTrace'),
        ),
      );

  Widget withValueBuilders(AsyncState<int> state) => MaterialApp(
        home: AsyncStateBuilder<int>(
          state: state,
          loading: (_) => const Text('loading'),
          loadingWithValue: (_, value) => Text('progress: $value'),
          data: (_, value) => Text('data: $value'),
          error: (_, error, stackTrace) => Text('error: $error'),
          errorWithValue: (_, error, stackTrace, value) =>
              Text('kept: $value\n$error\n$stackTrace'),
        ),
      );

  testWidgets('renders loading state', (tester) async {
    await tester.pumpWidget(subject(const AsyncLoading()));

    expect(find.text('loading'), findsOneWidget);
    expect(find.textContaining('data:'), findsNothing);
    expect(find.textContaining('error:'), findsNothing);
  });

  testWidgets('falls back to loading for a loading value without its builder',
      (tester) async {
    await tester.pumpWidget(subject(const AsyncLoading.withValue(3)));

    expect(find.text('loading'), findsOneWidget);
    expect(find.textContaining('data:'), findsNothing);
  });

  testWidgets('passes a loading value to the loadingWithValue builder',
      (tester) async {
    await tester.pumpWidget(withValueBuilders(const AsyncLoading.withValue(3)));
    expect(find.text('progress: 3'), findsOneWidget);
    expect(find.text('loading'), findsNothing);

    await tester.pumpWidget(withValueBuilders(const AsyncLoading()));
    expect(find.text('loading'), findsOneWidget);
    expect(find.textContaining('progress:'), findsNothing);
  });

  testWidgets('passes a null loading value to the loadingWithValue builder',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AsyncStateBuilder<int?>(
        state: const AsyncLoading.withValue(null),
        loading: (_) => const Text('loading'),
        loadingWithValue: (_, value) => Text('progress: $value'),
        data: (_, value) => Text('data: $value'),
        error: (_, error, stackTrace) => Text('error: $error'),
      ),
    ));

    expect(find.text('progress: null'), findsOneWidget);
  });

  testWidgets('passes data to the data builder', (tester) async {
    await tester.pumpWidget(subject(const AsyncData(42)));

    expect(find.text('data: 42'), findsOneWidget);
    expect(find.text('loading'), findsNothing);
  });

  testWidgets('passes data to the data builder alongside loadingWithValue',
      (tester) async {
    await tester.pumpWidget(withValueBuilders(const AsyncData(42)));

    expect(find.text('data: 42'), findsOneWidget);
    expect(find.textContaining('progress:'), findsNothing);
  });

  testWidgets('passes the error and stack trace to the error builder',
      (tester) async {
    final stackTrace = StackTrace.fromString('test trace');

    await tester.pumpWidget(
      subject(AsyncError(StateError('failed'), stackTrace)),
    );

    expect(find.textContaining('Bad state: failed'), findsOneWidget);
    expect(find.textContaining('test trace'), findsOneWidget);
  });

  testWidgets('falls back to error for an error value without its builder',
      (tester) async {
    await tester.pumpWidget(subject(AsyncError.withValue(
        StateError('failed'), StackTrace.fromString('test trace'), 3)));

    expect(find.textContaining('Bad state: failed'), findsOneWidget);
    expect(find.textContaining('data:'), findsNothing);
  });

  testWidgets('passes an error and its value to the errorWithValue builder',
      (tester) async {
    final error = StateError('failed');
    final stackTrace = StackTrace.fromString('test trace');

    await tester.pumpWidget(
      withValueBuilders(AsyncError.withValue(error, stackTrace, 3)),
    );
    expect(find.text('kept: 3\nBad state: failed\ntest trace'), findsOneWidget);
    expect(find.textContaining('error:'), findsNothing);

    await tester.pumpWidget(withValueBuilders(AsyncError(error, stackTrace)));
    expect(find.text('error: Bad state: failed'), findsOneWidget);
    expect(find.textContaining('kept:'), findsNothing);
  });

  testWidgets('passes a null error value to the errorWithValue builder',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AsyncStateBuilder<int?>(
        state: AsyncError.withValue(
            StateError('failed'), StackTrace.fromString('test trace'), null),
        loading: (_) => const Text('loading'),
        data: (_, value) => Text('data: $value'),
        error: (_, error, stackTrace) => Text('error: $error'),
        errorWithValue: (_, error, stackTrace, value) => Text('kept: $value'),
      ),
    ));

    expect(find.text('kept: null'), findsOneWidget);
  });

  testWidgets('rebuilds when the retained state changes', (tester) async {
    AsyncState<int> state = const AsyncLoading();
    late StateSetter updateState;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateState = setState;
            return AsyncStateBuilder<int>(
              state: state,
              loading: (_) => const Text('loading'),
              data: (_, value) => Text('data: $value'),
              error: (_, error, stackTrace) => Text('error: $error'),
            );
          },
        ),
      ),
    );

    expect(find.text('loading'), findsOneWidget);

    updateState(() => state = const AsyncData(42));
    await tester.pump();

    expect(find.text('loading'), findsNothing);
    expect(find.text('data: 42'), findsOneWidget);

    updateState(
      () => state = AsyncError(
        StateError('failed'),
        StackTrace.fromString('test trace'),
      ),
    );
    await tester.pump();

    expect(find.text('data: 42'), findsNothing);
    expect(find.text('error: Bad state: failed'), findsOneWidget);
  });
}
