import 'dart:async';

import 'package:async_state_view/async_state_view.dart';
import 'package:flutter/material.dart';

import 'user_page.dart';

// The README's examples of refreshing a user, with its two AsyncStateBuilders
// side by side in build to show the error with and without errorWithValue.

// #region user-view
Widget userView(BuildContext context, User user) => Text('Hello, ${user.name}');
// #endregion

class UserRefreshPage extends StatefulWidget {
  const UserRefreshPage({super.key});

  @override
  State<UserRefreshPage> createState() => _UserRefreshPageState();
}

class _UserRefreshPageState extends State<UserRefreshPage> {
  AsyncState<User> _state = const AsyncLoading();

  // The README's statements assign _user, so each assignment rebuilds.
  AsyncState<User> get _user => _state;
  set _user(AsyncState<User> user) => setState(() => _state = user);

  @override
  void initState() {
    super.initState();
    unawaited(refresh());
  }

  Future<void> refresh() async {
    // #region to-loading
    _user = _user.toLoading();
    // #endregion
    // #region to-error
    try {
      final user = await userRepository.fetchCurrentUser();
      _user = AsyncData(user);
    } catch (error, stackTrace) {
      _user = _user.toError(error, stackTrace);
    }
    // #endregion
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // #region user-view
        AsyncStateBuilder<User>(
          state: _user,
          loading: (_) => const CircularProgressIndicator(),
          loadingWithValue: userView,
          data: userView,
          error: (_, error, stackTrace) => Text('Failed: $error'),
        ),
        // #endregion
        // #region error-with-value
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
        ),
        // #endregion
        ElevatedButton(onPressed: refresh, child: const Text('Refresh')),
      ],
    );
  }
}
