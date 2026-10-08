// #region user-page
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
// #endregion

// Stand-ins for the model and data source that the README leaves to the app.

final class User {
  const User(this.name);

  final String name;
}

abstract interface class UserRepository {
  Future<User> fetchCurrentUser();
}

// Tests assign a fake before building a widget that fetches the user.
late UserRepository userRepository;
