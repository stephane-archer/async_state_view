## 0.2.0

- **Breaking:** States compare by value instead of by identity, so a selector
  can skip rebuilds while the part of a state it maps to is unchanged.
  - Owners that skip equal states, such as `ValueNotifier`, Bloc and Riverpod 3
    notifiers, no longer notify when a state is published again with an equal
    value. This also applies to objects that compare a state as one of their
    fields, such as Equatable or freezed Bloc states.
  - After changing a list in place, `AsyncData(items)` equals the current
    state; publish a new list instead.
  - A state can no longer be a key of a constant map or an element of a
    constant set; drop `const` from the collection.
  - A constant pattern such as `case const AsyncLoading():` matches every
    equal state, including one created without `const`, instead of only the
    identical constant.
  - Equality ignores the type argument, so `const AsyncLoading()` equals an
    `AsyncLoading<User>()`.
- **Breaking:** `AsyncState` has new members. They take precedence over
  extension members with the same names, so an extension you wrote for 0.1.0
  is no longer called, or no longer compiles if its signature differs. Remove
  it or rename its members. The new members are:
  - `toLoading` to refresh, and `toError` to report a failure, while keeping
    the current value.
  - `mapValue` to transform a state's value while keeping its kind.
  - `withoutCarriedValue` to drop the value a loading or error state carries,
    such as to skip rebuilds on progress updates.
  - The `hasValue`, `valueOrNull` and `requireValue` accessors. Without a
    value, `requireValue` rethrows an error with its stack trace.
- Add `AsyncLoading.withValue` and `AsyncError.withValue` to carry a value:
  partial progress or the previous result while refreshing, and the previous
  result after a failed refresh. Existing states are unaffected; code that
  switches on states created elsewhere should check `hasValue` if it can
  receive one.
- Add `AsyncStateBuilder.loadingWithValue` and `AsyncStateBuilder.errorWithValue`
  to render a carried value. Without them, a loading state with a value uses the
  `loading` builder and an error with a value uses the `error` builder, so a
  builder renders exactly as in 0.1.0 until it opts in.
- Add the `AsyncStateErrorWithValueBuilder` typedef for `errorWithValue`.
- States describe themselves in `toString`.
- Document reporting progress from a stream, with a complete `ChangeNotifier`
  example.

## 0.1.0

- initial release 
