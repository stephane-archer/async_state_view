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

## How it compares

| Option | Who owns the asynchronous work? | Best fit |
| --- | --- | --- |
| `AsyncStateBuilder` | Your state owner | Controller-owned state shared across UI or refreshed by feature actions |
| [`FutureBuilder`][future-builder] | The widget subscribes to a `Future` | One widget displaying one already-created Future |
| [`async_builder`][async-builder] | The widget subscribes to a `Future` or `Stream` | A convenient `FutureBuilder`/`StreamBuilder` with separate callbacks and stream features |
| [`flutter_async_value`][flutter-async-value] | Your state owner | The closest state-first alternative, with initial state, typed errors, mapping helpers, and an `AsyncValueBuilder` |
| [Riverpod with `AsyncValue`][riverpod-async] | A provider | App state needing dependency tracking, caching, lifecycle management, and provider composition |
| [`flutter_async`][flutter-async] | The package/widget | Turnkey reload, polling, pagination, async buttons, and global loading or error presentation |

### Compared with FutureBuilder

Flutter's built-in `FutureBuilder` subscribes to a `Future` and exposes an
`AsyncSnapshot`. It is usually the best choice for a small, local UI concern.
The Future must be created before `build`; creating it alongside the builder can
restart the task whenever an ancestor rebuilds.

Choose `AsyncStateBuilder` when the result has a lifecycle beyond that widget.
The state owner decides exactly when loading begins, whether an old completion
is stale, and when to refresh. The builder simply renders the current state.

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

### Is state-first async handling unusual?

No. `flutter_async_value` has a very similar split between an `AsyncValue` and
an `AsyncValueBuilder`. Riverpod also exposes async work as a retained, sealed
`AsyncValue` that widgets consume. This package applies the same idea without
adopting a full state-management system.

Many packages accept a Future directly because that is the shortest path from
the value most applications already have to visible UI. The widget can manage
the subscription and disposal automatically, and users do not have to write a
state owner. That is a good default for local work, but it couples operation
lifecycle to widget lifecycle. This package chooses explicit state ownership
for cases where that coupling is undesirable.

## Complete example

Most asynchronous work still starts as a `Future`. Await that Future in your
state owner, translate its progress into an `AsyncState`, and rebuild when the
state changes.

This example loads a user when the widget starts and lets the user retry after
an error:

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

- Before starting or restarting work: `const AsyncLoading()`
- After the Future succeeds: `AsyncData(value)`
- After the Future fails: `AsyncError(error, stackTrace)`

The example uses `setState`, but the same states can be stored in a
`ChangeNotifier`, Bloc, Riverpod notifier, or another controller. Pass the
current `AsyncState<T>` to `AsyncStateBuilder` after that owner rebuilds its
listeners.

Avoid creating or starting the Future inside `build`. Start it from a lifecycle
method, event handler, or controller instead.

## When to use something else

Use `FutureBuilder` when the operation is local to one widget and Flutter's
built-in API is sufficient. Adding a retained state model would only create
extra code.

Use `async_builder` or another Future/Stream builder when you want the widget to
subscribe directly, especially for streams. `AsyncStateBuilder` has no Stream
support and does not listen for changes by itself.

Use `flutter_async_value` if you want this state-first approach plus an idle
state, typed errors, `map`/`maybeMap`, or result helpers.

Use Riverpod, Bloc, or another state-management solution when you also need
dependency injection, automatic disposal, caching, cross-feature coordination,
side-effect listeners, or developer tooling. This package can render state
owned by those tools, but it does not replace them.

Consider a more feature-rich async UI package such as `flutter_async` when you
need built-in reload, polling, pagination, async-button behavior, snackbars, or
globally configured loaders.

`AsyncState` models exactly three mutually exclusive states: loading, data, and
error. Use another model or extend your feature state when you need an idle
state, progress, pagination, cancellation, cached data while refreshing, or
simultaneous data-and-error information.

Regardless of the UI package, cancellation and stale-result handling belong to
the code that owns the operation. `AsyncStateBuilder` neither starts nor cancels
work.

[future-builder]: https://api.flutter.dev/flutter/widgets/FutureBuilder-class.html
[async-builder]: https://pub.dev/packages/async_builder
[flutter-async-value]: https://pub.dev/packages/flutter_async_value
[riverpod-async]: https://riverpod.dev/docs/whats_new#asyncvalue
[flutter-async]: https://pub.dev/packages/flutter_async
