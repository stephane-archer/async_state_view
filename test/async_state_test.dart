import 'package:async_state_view/async_state_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final stackTrace = StackTrace.fromString('test trace');
  final error = StateError('failed');

  group('accessors', () {
    test('loading without a value', () {
      const AsyncState<int> state = AsyncLoading();
      expect(state.hasValue, isFalse);
      expect(state.valueOrNull, isNull);
      expect(() => state.requireValue, throwsStateError);
    });

    test('loading with a value', () {
      const AsyncState<int> state = AsyncLoading.withValue(3);
      expect(state.hasValue, isTrue);
      expect(state.valueOrNull, 3);
      expect(state.requireValue, 3);
    });

    test('data', () {
      const AsyncState<int> state = AsyncData(42);
      expect(state.hasValue, isTrue);
      expect(state.valueOrNull, 42);
      expect(state.requireValue, 42);
    });

    test('error without a value', () {
      final AsyncState<int> state = AsyncError(error, stackTrace);
      expect(state.hasValue, isFalse);
      expect(state.valueOrNull, isNull);
    });

    test('error with a value', () {
      final AsyncState<int> state = AsyncError.withValue(error, stackTrace, 3);
      expect(state.hasValue, isTrue);
      expect(state.valueOrNull, 3);
      expect(state.requireValue, 3);
    });

    test('requireValue rethrows an error without a value', () {
      try {
        AsyncError<int>(error, stackTrace).requireValue;
        fail('requireValue returned instead of throwing.');
      } on StateError catch (thrown, thrownStackTrace) {
        expect(thrown, same(error));
        expect(thrownStackTrace, same(stackTrace));
      }
    });

    test('hasValue distinguishes a null value from no value', () {
      expect(const AsyncLoading<int?>.withValue(null).hasValue, isTrue);
      expect(const AsyncLoading<int?>().hasValue, isFalse);
      expect(const AsyncData<int?>(null).hasValue, isTrue);
      expect(
          AsyncError<int?>.withValue(error, stackTrace, null).hasValue, isTrue);
      expect(AsyncError<int?>(error, stackTrace).hasValue, isFalse);
    });

    test('requireValue returns a carried null value', () {
      expect(const AsyncLoading<int?>.withValue(null).requireValue, isNull);
      expect(const AsyncData<int?>(null).requireValue, isNull);
      expect(AsyncError<int?>.withValue(error, stackTrace, null).requireValue,
          isNull);
    });

    test('requireValue throws without a value when the type is nullable', () {
      expect(() => const AsyncLoading<int?>().requireValue, throwsStateError);
      expect(() => AsyncError<int?>(error, stackTrace).requireValue,
          throwsA(same(error)));
    });

    test('a nullable value matches hasValue with valueOrNull', () {
      String describe(AsyncState<int?> state) => switch (state) {
            AsyncLoading(hasValue: true, :final valueOrNull) =>
              'so far: $valueOrNull',
            AsyncLoading() => 'starting',
            AsyncData(:final value) => 'done: $value',
            AsyncError(:final error) => 'failed: $error',
          };

      expect(describe(const AsyncLoading.withValue(null)), 'so far: null');
      expect(describe(const AsyncLoading()), 'starting');
    });
  });

  group('mapValue', () {
    String describe(int value) => 'value $value';

    test('keeps loading without a value', () {
      final AsyncLoading<String> mapped =
          const AsyncLoading<int>().mapValue(describe);
      expect(mapped.hasValue, isFalse);
    });

    test('transforms the value a loading state carries', () {
      final AsyncLoading<String> mapped =
          const AsyncLoading<int>.withValue(3).mapValue(describe);
      expect(mapped.valueOrNull, 'value 3');
    });

    test('transforms data', () {
      final AsyncData<String> mapped = const AsyncData(42).mapValue(describe);
      expect(mapped.value, 'value 42');
    });

    test('keeps the error and stack trace', () {
      final AsyncError<String> mapped =
          AsyncError<int>(error, stackTrace).mapValue(describe);
      expect(mapped.error, same(error));
      expect(mapped.stackTrace, same(stackTrace));
      expect(mapped.hasValue, isFalse);
    });

    test('transforms the value an error keeps', () {
      final AsyncError<String> mapped =
          AsyncError<int>.withValue(error, stackTrace, 3).mapValue(describe);
      expect(mapped.error, same(error));
      expect(mapped.stackTrace, same(stackTrace));
      expect(mapped.valueOrNull, 'value 3');
    });

    test('passes a carried null value to the transform', () {
      final mapped = const AsyncLoading<int?>.withValue(null)
          .mapValue((value) => '$value');
      expect(mapped.valueOrNull, 'null');
    });

    test('lets an exception from the transform propagate', () {
      expect(
        () => const AsyncData(42).mapValue<String>((_) => throw error),
        throwsA(same(error)),
      );
    });
  });

  group('equality', () {
    test('compares loading states by value', () {
      expect(const AsyncLoading<int>(), const AsyncLoading<int>());
      expect(AsyncLoading<int>.withValue(int.parse('3')),
          const AsyncLoading<int>.withValue(3));
      expect(const AsyncLoading<int>.withValue(3),
          isNot(const AsyncLoading<int>.withValue(4)));
      expect(const AsyncLoading<int?>.withValue(null),
          isNot(const AsyncLoading<int?>()));
    });

    test('compares data by value', () {
      expect(AsyncData(int.parse('42')), const AsyncData(42));
      expect(const AsyncData(42), isNot(const AsyncData(43)));
      expect(const AsyncData(42), isNot(const AsyncLoading<int>.withValue(42)));
    });

    test('compares errors by error, stack trace and value', () {
      expect(AsyncError<int>(error, stackTrace),
          AsyncError<int>(error, stackTrace));
      expect(AsyncError<int>(error, stackTrace),
          isNot(AsyncError<int>(error, StackTrace.empty)));
      expect(AsyncError<int>.withValue(error, stackTrace, int.parse('3')),
          AsyncError<int>.withValue(error, stackTrace, 3));
      expect(AsyncError<int>.withValue(error, stackTrace, 3),
          isNot(AsyncError<int>.withValue(error, stackTrace, 4)));
      expect(AsyncError<int?>.withValue(error, stackTrace, null),
          isNot(AsyncError<int?>(error, stackTrace)));
    });

    test('ignores the type argument, whichever side compares', () {
      expect(const AsyncLoading<num>(), const AsyncLoading<int>());
      expect(const AsyncLoading<int>(), const AsyncLoading<num>());
      expect(const AsyncLoading<num>.withValue(1),
          const AsyncLoading<int>.withValue(1));
      expect(const AsyncLoading<int>.withValue(1),
          const AsyncLoading<num>.withValue(1));
      expect(const AsyncData<num>(1), const AsyncData<int>(1));
      expect(const AsyncData<int>(1), const AsyncData<num>(1));
      expect(AsyncError<num>(error, stackTrace),
          AsyncError<int>(error, stackTrace));
      expect(AsyncError<int>(error, stackTrace),
          AsyncError<num>(error, stackTrace));
    });

    test('states equal across type arguments have equal hash codes', () {
      expect(const AsyncLoading<num>.withValue(1).hashCode,
          const AsyncLoading<int>.withValue(1).hashCode);
      expect(
          const AsyncData<num>(1).hashCode, const AsyncData<int>(1).hashCode);
      expect(AsyncError<num>(error, stackTrace).hashCode,
          AsyncError<int>(error, stackTrace).hashCode);
    });

    test('equal states have equal hash codes', () {
      expect(AsyncLoading<int>.withValue(int.parse('3')).hashCode,
          const AsyncLoading<int>.withValue(3).hashCode);
      expect(AsyncData(int.parse('42')).hashCode, const AsyncData(42).hashCode);
      expect(AsyncError<int>(error, stackTrace).hashCode,
          AsyncError<int>(error, stackTrace).hashCode);
      expect(
          AsyncError<int>.withValue(error, stackTrace, int.parse('3')).hashCode,
          AsyncError<int>.withValue(error, stackTrace, 3).hashCode);
    });

    test('a state equals itself even if its value does not', () {
      const AsyncState<double> loading = AsyncLoading.withValue(double.nan);
      const AsyncState<double> data = AsyncData(double.nan);
      final AsyncState<double> failed =
          AsyncError.withValue(error, stackTrace, double.nan);
      for (final state in [loading, data, failed]) {
        expect(state == state, isTrue);
        expect({state}.contains(state), isTrue);
      }
      // Two constants holding NaN are one canonical instance, so parse one.
      expect(data, isNot(AsyncData(double.parse('NaN'))));
    });

    test('mapping an unchanged part gives an equal state', () {
      const before = AsyncLoading<(int, bool)>.withValue((1, true));
      const after = AsyncLoading<(int, bool)>.withValue((2, true));
      expect(after.mapValue((value) => value.$2),
          before.mapValue((value) => value.$2));
      expect(after.mapValue((value) => value.$1),
          isNot(before.mapValue((value) => value.$1)));
    });
  });

  group('toLoading', () {
    test('returns a loading state as is', () {
      const empty = AsyncLoading<int>();
      const withValue = AsyncLoading<int>.withValue(3);
      expect(empty.toLoading(), same(empty));
      expect(withValue.toLoading(), same(withValue));
    });

    test('keeps the value of data', () {
      expect(const AsyncData(42).toLoading(),
          const AsyncLoading<int>.withValue(42));
      expect(const AsyncData<int?>(null).toLoading(),
          const AsyncLoading<int?>.withValue(null));
    });

    test('keeps the value of an error', () {
      expect(AsyncError<int>.withValue(error, stackTrace, 3).toLoading(),
          const AsyncLoading<int>.withValue(3));
      expect(AsyncError<int>(error, stackTrace).toLoading(),
          const AsyncLoading<int>());
    });
  });

  group('toError', () {
    final newError = StateError('failed again');
    final newStackTrace = StackTrace.fromString('new trace');

    test('keeps the value of a loading state', () {
      expect(const AsyncLoading<int>.withValue(3).toError(error, stackTrace),
          AsyncError<int>.withValue(error, stackTrace, 3));
      expect(const AsyncLoading<int>().toError(error, stackTrace),
          AsyncError<int>(error, stackTrace));
    });

    test('keeps the value of data', () {
      expect(const AsyncData(42).toError(error, stackTrace),
          AsyncError<int>.withValue(error, stackTrace, 42));
      expect(const AsyncData<int?>(null).toError(error, stackTrace),
          AsyncError<int?>.withValue(error, stackTrace, null));
    });

    test('replaces the error and keeps the value of an error', () {
      expect(
          AsyncError<int>.withValue(error, stackTrace, 3)
              .toError(newError, newStackTrace),
          AsyncError<int>.withValue(newError, newStackTrace, 3));
      expect(
          AsyncError<int>(error, stackTrace).toError(newError, newStackTrace),
          AsyncError<int>(newError, newStackTrace));
    });

    test('keeps a value through a failed refresh and a retry', () {
      const AsyncState<int> loaded = AsyncData(42);
      final failed = loaded.toLoading().toError(error, stackTrace);
      expect(failed.toLoading(), const AsyncLoading<int>.withValue(42));
    });
  });

  group('withoutCarriedValue', () {
    test('drops the value of a loading state', () {
      const empty = AsyncLoading<int>();
      expect(const AsyncLoading<int>.withValue(3).withoutCarriedValue(), empty);
      expect(const AsyncLoading<int?>.withValue(null).withoutCarriedValue(),
          const AsyncLoading<int?>());
      expect(empty.withoutCarriedValue(), same(empty));
    });

    test('returns data as is', () {
      const data = AsyncData(42);
      expect(data.withoutCarriedValue(), same(data));
    });

    test('drops the value of an error and keeps the error', () {
      final failed = AsyncError<int>(error, stackTrace);
      final dropped =
          AsyncError<int>.withValue(error, stackTrace, 3).withoutCarriedValue();
      expect(dropped, failed);
      expect(dropped.hasValue, isFalse);
      expect(dropped.error, same(error));
      expect(dropped.stackTrace, same(stackTrace));
      expect(failed.withoutCarriedValue(), same(failed));
      expect(
          AsyncError<int?>.withValue(error, stackTrace, null)
              .withoutCarriedValue(),
          AsyncError<int?>(error, stackTrace));
    });

    test('keeps the type argument', () {
      const AsyncState<int> loading = AsyncLoading.withValue(3);
      final AsyncState<int> failed = AsyncError.withValue(error, stackTrace, 3);
      expect(loading.withoutCarriedValue().runtimeType, AsyncLoading<int>);
      expect(failed.withoutCarriedValue().runtimeType, AsyncError<int>);
    });

    test('makes progress updates equal', () {
      const AsyncState<int> before = AsyncLoading.withValue(1);
      const AsyncState<int> after = AsyncLoading.withValue(2);
      expect(after, isNot(before));
      expect(after.withoutCarriedValue(), before.withoutCarriedValue());
    });

    test('makes errors with different kept values equal', () {
      final AsyncState<int> before = AsyncError.withValue(error, stackTrace, 1);
      final AsyncState<int> after = AsyncError.withValue(error, stackTrace, 2);
      expect(after, isNot(before));
      expect(after.withoutCarriedValue(), before.withoutCarriedValue());
    });

    test('keeps mapValue from running on a carried value', () {
      final List<AsyncState<int>> carrying = [
        const AsyncLoading.withValue(1),
        AsyncError.withValue(error, stackTrace, 1),
      ];
      for (final state in carrying) {
        state
            .withoutCarriedValue()
            .mapValue<int>((_) => fail('transform ran on $state'));
      }
    });
  });

  test('describes each state', () {
    expect(const AsyncLoading<int>().toString(), 'AsyncLoading<int>()');
    expect(const AsyncLoading<int>.withValue(3).toString(),
        'AsyncLoading<int>.withValue(3)');
    expect(const AsyncData(42).toString(), 'AsyncData<int>(42)');
    expect(AsyncError<int>(error, stackTrace).toString(),
        'AsyncError<int>(Bad state: failed)');
    expect(AsyncError<int>.withValue(error, stackTrace, 3).toString(),
        'AsyncError<int>.withValue(Bad state: failed, 3)');
  });
}
