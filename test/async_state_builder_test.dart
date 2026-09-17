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

  testWidgets('renders loading state', (tester) async {
    await tester.pumpWidget(subject(const AsyncLoading()));

    expect(find.text('loading'), findsOneWidget);
    expect(find.textContaining('data:'), findsNothing);
    expect(find.textContaining('error:'), findsNothing);
  });

  testWidgets('passes data to the data builder', (tester) async {
    await tester.pumpWidget(subject(const AsyncData(42)));

    expect(find.text('data: 42'), findsOneWidget);
    expect(find.text('loading'), findsNothing);
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
