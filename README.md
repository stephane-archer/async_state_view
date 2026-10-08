# async_state_view

Render controller-owned asynchronous state without giving a widget ownership of
the Future.

`AsyncStateBuilder` is a small view layer for retained async state. Your
controller, notifier, or `State` object decides when work starts, which result
wins, and how long the result lives. The widget only renders `AsyncLoading`,
`AsyncData`, or `AsyncError`.

## Why use it?

Future-driven builders are convenient when one Future belongs to one widget.
They become less natural when the result belongs to a feature or controller.
`AsyncStateBuilder` keeps that ownership boundary explicit.

It works especially well when:

- Several widgets render different parts of the same result.
- An action must refresh data after changing something.
- The previous result should stay visible while it refreshes or after a refresh
  fails.
- Data must survive individual widget rebuilds or moves.
- A controller must reject stale results or ignore completions after disposal.
- Tests need to publish loading, data, and error states without completing real
  Futures.
- You want an exhaustive, non-nullable sealed state instead of inspecting an
  `AsyncSnapshot`.

The package is deliberately small. It depends only on Flutter, does not impose
a state-management framework, and works with `setState`, `ChangeNotifier`, Bloc,
Riverpod, or a custom controller.

## Installation

Add the package to your application:

```sh
flutter pub add async_state_view
```

Then import its public library:

```dart
import 'package:async_state_view/async_state_view.dart';
```

## Complete example

Most asynchronous work still starts as a `Future`. Await that Future in your
state owner, translate its progress into an `AsyncState`, and rebuild when the
state changes.

This example loads a user when the widget starts and lets the user retry after
an error:

<!-- excerpt: test/readme/user_page.dart#user-page -->
```dart
import 'dart:async';

import 'package:async_state_view/async_state_view.dart';
import 'package:flutter/material.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  AsyncState<User> _user = const AsyncLoading();
  var _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadUser());
  }

  Future<void> _loadUser() async {
    final generation = ++_requestGeneration;
    setState(() => _user = const AsyncLoading());

    try {
      // This is the Future your repository, API client, or service returns.
      final user = await userRepository.fetchCurrentUser();

      // Ignore a result if the widget was removed or a newer load was started.
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _user = AsyncData(user));
    } catch (error, stackTrace) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _user = AsyncError(error, stackTrace));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncStateBuilder<User>(
      state: _user,
      loading: (_) => const Center(child: CircularProgressIndicator()),
      data: (_, user) => Text('Hello, ${user.name}'),
      error: (context, error, stackTrace) => Column(
        children: [
          Text(
            'Could not load the user: $error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          ElevatedButton(
            onPressed: _loadUser,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
```

`User` and `userRepository` represent your own model and data source.

## Updating the state

Publish the state that matches the current outcome and notify the UI using your
existing state-management mechanism:

- Before starting or restarting work: `const AsyncLoading()`, or
  `state.toLoading()` to keep the current value during a refresh
- While work reports partial results: `AsyncLoading.withValue(value)`, as in
  [Reporting progress from a stream](#reporting-progress-from-a-stream)
- After the Future succeeds: `AsyncData(value)`
- After the Future fails: `AsyncError(error, stackTrace)`, or
  `state.toError(error, stackTrace)` to keep the current value

The example uses `setState`, but the same states can be stored in a
`ChangeNotifier`, Bloc, Riverpod notifier, or another controller. Pass the
current `AsyncState<T>` to `AsyncStateBuilder` after that owner rebuilds its
listeners.

States compare by value, and some owners skip a new state equal to the current
one: `ValueNotifier`, Bloc, and Riverpod 3 notifiers do. Publish a new value
rather than changing the current one in place. If the current state is
`AsyncData(items)`, calling `items.add(item)` and publishing `AsyncData(items)`
is ignored; publish `AsyncData([...items, item])` instead.

Equality ignores the type argument, so a test can compare an
`AsyncState<User>` with `const AsyncLoading()`.

Avoid creating or starting the Future inside `build`. Start it from a lifecycle
method, event handler, or controller instead.

## Showing a value while loading

A loading state can carry a value: partial progress from long-running work, or
the previous result while refreshing.

To refresh while keeping the current value visible, publish `toLoading()`. Data
becomes loading with its value, and so does an error that
[kept one](#keeping-a-value-after-an-error):

<!-- excerpt: test/readme/user_refresh.dart#to-loading -->
```dart
_user = _user.toLoading();
```

`AsyncStateBuilder` shows the carried value only when you give it a
`loadingWithValue` builder. Without one, it renders `loading`, as it does for a
loading state without a value. To keep a refreshing result visible as is, pass
the same function as `data`:

<!-- excerpt: test/readme/user_refresh.dart#user-view -->
```dart
Widget userView(BuildContext context, User user) => Text('Hello, ${user.name}');

AsyncStateBuilder<User>(
  state: _user,
  loading: (_) => const CircularProgressIndicator(),
  loadingWithValue: userView,
  data: userView,
  error: (_, error, stackTrace) => Text('Failed: $error'),
)
```

### Reporting progress from a stream

To report partial progress, publish each intermediate value as a loading state,
and the last one as data once the work is done. A stream signals its end with
`onDone` after its last event, so that is where the carried value becomes the
result.

Here `ScanController`, a `ChangeNotifier` in `scan_controller.dart`, publishes
the running totals that `scanner.scan()` emits:

<!-- excerpt: test/readme/scan_controller.dart#scan-controller -->
```dart
import 'dart:async';

import 'package:async_state_view/async_state_view.dart';
import 'package:flutter/foundation.dart';

class ScanController extends ChangeNotifier {
  ScanController(this.scanner);

  final Scanner scanner;
  AsyncState<Totals> _scan = const AsyncLoading();
  StreamSubscription<Totals>? _subscription;

  AsyncState<Totals> get scan => _scan;

  void startScan() {
    // Cancelling stops the previous run's callbacks, onDone included, so only
    // this run's events reach _scan.
    unawaited(_subscription?.cancel());
    // Not toLoading, which would keep the previous run's totals and show them
    // as progress of this run until its first event.
    _scan = const AsyncLoading();
    notifyListeners();
    _subscription = scanner.scan().listen(
      (totals) {
        _scan = AsyncLoading.withValue(totals);
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        // Not toError, which would keep the partial totals as if they were
        // a previous result.
        _scan = AsyncError(error, stackTrace);
        notifyListeners();
      },
      onDone: () {
        // A scan that ends without an event found nothing.
        _scan = AsyncData(_scan.valueOrNull ?? Totals.empty);
        notifyListeners();
      },
      // Ends the run at the first error, so neither a later event nor onDone
      // replaces it.
      cancelOnError: true,
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
```

`Totals` and `Scanner` represent your own model and data source. `scan` stays
loading until `startScan` runs, so call it when you create the controller or
from the action that starts a scan.

`ScanView` rebuilds through a `ListenableBuilder` when the controller notifies,
and shows the progress with its `loadingWithValue` builder:

<!-- excerpt: test/readme/scan_view.dart#scan-view -->
```dart
import 'package:async_state_view/async_state_view.dart';
import 'package:flutter/material.dart';

import 'scan_controller.dart';

class ScanView extends StatelessWidget {
  const ScanView({super.key, required this.controller});

  final ScanController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => AsyncStateBuilder<Totals>(
        state: controller.scan,
        loading: (_) => const CircularProgressIndicator(),
        loadingWithValue: (_, totals) => Text('${totals.count} so far…'),
        data: (_, totals) => Text('${totals.count} in total'),
        error: (_, error, stackTrace) => Text('Failed: $error'),
      ),
    );
  }
}
```

## Keeping a value after an error

An error can keep a value too, such as the previous result after a failed
refresh. Publish `toError` instead of `AsyncError` to keep the current value:

<!-- excerpt: test/readme/user_refresh.dart#to-error -->
```dart
try {
  final user = await userRepository.fetchCurrentUser();
  _user = AsyncData(user);
} catch (error, stackTrace) {
  _user = _user.toError(error, stackTrace);
}
```

Give `AsyncStateBuilder` an `errorWithValue` builder to show the value with the
error. Without one, the `error` builder is used.

<!-- excerpt: test/readme/user_refresh.dart#error-with-value -->
```dart
AsyncStateBuilder<User>(
  state: _user,
  loading: (_) => const CircularProgressIndicator(),
  loadingWithValue: userView,
  data: userView,
  error: (_, error, stackTrace) => Text('Failed: $error'),
  errorWithValue: (context, error, stackTrace, user) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Could not refresh: $error'),
      userView(context, user),
    ],
  ),
)
```

Retrying with `toLoading()` keeps the value, so with both builders it stays
visible through a failed refresh and the retry that follows. It does not keep
the error: to show it during the retry, store it separately in your owner.

## Deriving and reading states

`mapValue` transforms the value while keeping the kind of state: loading and
error states carry the transformed value if they had one, and an error keeps
its error and stack trace. An exception thrown by the transform propagates to
the caller.

States compare by value, so `mapValue` also selects the part of a larger state
a widget depends on. With a selector that compares by `==`, such as Provider's
`context.select`, the widget only rebuilds when that part changes. Here a
`ChangeNotifierProvider` above the widget provides the `ScanController` from
[Reporting progress from a stream](#reporting-progress-from-a-stream):

<!-- excerpt: test/readme/scan_select.dart#found -->
```dart
// Rebuilds when `found` flips or the scan ends, not on every progress update.
final found = context.select(
  (ScanController controller) =>
      controller.scan.mapValue((totals) => totals.count > 0),
);
```

The comparison is only as precise as the value's own `==`. A value type that
keeps identity equality makes every new state differ, so the widget rebuilds on
each update. Map to a value that compares by value, such as a `bool`, a number,
or a class that overrides `==`.

A widget that renders only final results does not need the value carried
while loading, which changes with each progress update. Drop it with
`withoutCarriedValue` before mapping, so progress updates give equal states:

<!-- excerpt: test/readme/scan_select.dart#count -->
```dart
// Rebuilds when the scan starts, ends or fails, not on progress updates.
final count = context.select(
  (ScanController controller) => controller.scan
      .withoutCarriedValue()
      .mapValue((totals) => totals.count),
);
```

`withoutCarriedValue` also drops a previous result kept by `toLoading` or
`toError`, so the widget no longer sees it while refreshing or after a failed
refresh.

Outside widgets, these accessors read the value of any kind of state:

| Accessor | Loading | Data | Error |
| --- | --- | --- | --- |
| `hasValue` | `true` if created `withValue` | `true` | `true` if created `withValue` |
| `valueOrNull` | the value, or `null` | the value | the value, or `null` |
| `requireValue` | the value, or throws a `StateError` | the value | the value, or rethrows the error |

Use `hasValue` rather than `valueOrNull != null` when the value type is
nullable.

To check the kind of state, test its type, such as `state is AsyncLoading`.
An `AsyncError` exposes its `error` and `stackTrace` fields.

In a `switch`, match a carried value with `valueOrNull` and a null-check
pattern:

<!-- excerpt: test/readme/scan_switch.dart#switch -->
```dart
final label = switch (controller.scan) {
  AsyncLoading(valueOrNull: final totals?) => '${totals.count} so far…',
  AsyncLoading() => 'Starting…',
  AsyncData(:final value) => '${value.count} in total',
  AsyncError(:final error) => 'Failed: $error',
};
```

When the value type is nullable, a null value does not match `final totals?`.
Match `hasValue: true` instead:

<!-- excerpt: test/readme/scan_switch.dart#nullable-case -->
```dart
AsyncLoading(hasValue: true, :final valueOrNull) => 'So far: $valueOrNull',
```

## Alternatives

| Option | Who owns the asynchronous work? | Best fit |
| --- | --- | --- |
| `AsyncStateBuilder` | Your state owner | Controller-owned state shared across UI or refreshed by feature actions |
| [`FutureBuilder`][future-builder] | The widget subscribes to a `Future` | One widget displaying one already-created Future |
| [`async_builder`][async-builder] | The widget subscribes to a `Future` or `Stream` | A convenient `FutureBuilder`/`StreamBuilder` with separate callbacks and stream features |
| [`AsyncSnapshot`][async-snapshot] stored by your owner | Your state owner | Zero dependencies, when an unsealed snapshot with nullable data and no exhaustive `switch` is acceptable |
| [`flutter_async_value`][flutter-async-value] | Your state owner | A state-first alternative with initial state, typed errors, cached data while refreshing or after an error, mapping helpers, and an `AsyncValueBuilder` |
| [Riverpod with `AsyncValue`][riverpod-async] | A provider | App state needing dependency tracking, caching, lifecycle management, and provider composition |
| [Signals with `AsyncState`][signals-async] | An async signal | Apps built on signals, where async signals and computed values produce the state |
| [`command_it`][command-it] | A command object | Wrapping actions as commands that expose running, result, and error listenables, with a `CommandBuilder` |
| [`flutter_async`][flutter-async] | The package/widget | Turnkey reload, polling, pagination, async buttons, and global loading or error presentation |

### Compared with FutureBuilder

Flutter's built-in `FutureBuilder` subscribes to a `Future` and exposes an
`AsyncSnapshot`. It is usually the best choice for a small, local UI concern.
The Future must be created before `build`; creating it alongside the builder can
restart the task whenever an ancestor rebuilds.

Choose `AsyncStateBuilder` when the result has a lifecycle beyond that widget.
The state owner decides exactly when loading begins, whether an old completion
is stale, and when to refresh. The builder simply renders the current state.

A state owner can also store an `AsyncSnapshot` itself and avoid a dependency.
`AsyncSnapshot.withData(ConnectionState.active, value)` even represents a value
while loading. The snapshot is not sealed, though: its data is nullable, a
`switch` over it cannot be exhaustive, and it has no `mapValue` equivalent.

### Compared with async_builder

The `async_builder` package is a higher-level replacement for `FutureBuilder`
and `StreamBuilder`. It directly accepts a Future or Stream and provides
separate callbacks for waiting, values, errors, and closed streams. It also has
options for initial values, retaining a value, pausing streams, reporting
errors, and initializing work with `InitBuilder`.

Choose `async_builder` when the widget should own the subscription and you want
those conveniences with less snapshot boilerplate. Choose `AsyncStateBuilder`
when a controller already owns the work and the widget should not subscribe to,
restart, pause, or otherwise manage it.

### Using it alongside Riverpod or Signals

Riverpod's `AsyncValue` and the Signals packages' `AsyncState` are also sealed
async states. This package reuses the names `AsyncLoading`, `AsyncData`, and
`AsyncError`, and Signals also names its type `AsyncState`, so the names clash
in a file that imports this package and one of those. Import one of the
packages with a prefix or `hide`.

### Is state-first async handling unusual?

No. `flutter_async_value` has a very similar split between an `AsyncValue` and
an `AsyncValueBuilder`. Riverpod and Signals also expose async work as a
retained, sealed state that widgets consume. This package applies the same idea
without adopting a full state-management system.

Many packages accept a Future directly because that is the shortest path from
the value most applications already have to visible UI. The widget can manage
the subscription and disposal automatically, and users do not have to write a
state owner. That is a good default for local work, but it couples operation
lifecycle to widget lifecycle. This package chooses explicit state ownership
for cases where that coupling is undesirable.

### When to use something else

Use `FutureBuilder` when the operation is local to one widget and Flutter's
built-in API is sufficient. Adding a retained state model would only create
extra code.

Use `async_builder` or another Future/Stream builder when you want the widget to
subscribe directly, especially for streams. `AsyncStateBuilder` has no Stream
support and does not listen for changes by itself. To render a stream with it,
listen to the stream in your state owner, as in
[Reporting progress from a stream](#reporting-progress-from-a-stream).

Use `flutter_async_value` if you want this state-first approach plus an idle
state, typed errors, per-state `map`/`maybeMap` callbacks, or result helpers.

Use Riverpod, Signals, Bloc, or another state-management solution when you
also need dependency injection, automatic disposal, caching, cross-feature
coordination, side-effect listeners, or developer tooling. This package can
render state owned by those tools, but it does not replace them.

Use `command_it` when you want command objects that run the work and track its
state for you, rather than writing that code in your owner.

Consider a more feature-rich async UI package such as `flutter_async` when you
need built-in reload, polling, pagination, async-button behavior, snackbars, or
globally configured loaders.

`AsyncState` models exactly three mutually exclusive states: loading, data, and
error, where loading and error can keep a value. Use another model or extend
your feature state when you need an idle state, a progress percentage without a
partial value, pagination, or cancellation.

Regardless of the UI package, cancellation and stale-result handling belong to
the code that owns the operation. `AsyncStateBuilder` neither starts nor cancels
work.

[future-builder]: https://api.flutter.dev/flutter/widgets/FutureBuilder-class.html
[async-snapshot]: https://api.flutter.dev/flutter/widgets/AsyncSnapshot-class.html
[async-builder]: https://pub.dev/packages/async_builder
[flutter-async-value]: https://pub.dev/packages/flutter_async_value
[riverpod-async]: https://riverpod.dev/docs/whats_new#asyncvalue
[signals-async]: https://pub.dev/documentation/signals_core/latest/signals_core/AsyncState-class.html
[command-it]: https://pub.dev/packages/command_it
[flutter-async]: https://pub.dev/packages/flutter_async
