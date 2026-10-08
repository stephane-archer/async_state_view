import 'package:async_state_view/async_state_view.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(home: ExamplePage());
}

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  AsyncState<String> _message = const AsyncLoading();
  var _loads = 0;
  var _failLoads = false;
  var _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadMessage();
  }

  Future<void> _loadMessage() async {
    final generation = ++_requestGeneration;
    // Keep showing the previous message, if any, while reloading.
    setState(() => _message = _message.toLoading());

    try {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (_failLoads) throw Exception('The server is unreachable.');
      // Ignore a result if the widget was removed or a newer load was started.
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _message = AsyncData('Result #${++_loads} is ready.'));
    } catch (error, stackTrace) {
      if (!mounted || generation != _requestGeneration) return;
      // Keep showing the previous message, if any, after a failed reload.
      setState(() => _message = _message.toError(error, stackTrace));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Async state view'),
          actions: [
            Tooltip(
              message: 'Make loads fail',
              child: Switch(
                value: _failLoads,
                onChanged: (value) => setState(() => _failLoads = value),
              ),
            ),
            IconButton(
              onPressed: _loadMessage,
              tooltip: 'Reload',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Center(
          child: AsyncStateBuilder<String>(
            state: _message,
            loading: (_) => const CircularProgressIndicator(),
            loadingWithValue: (_, message) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(opacity: 0.5, child: Text(message)),
                const SizedBox(height: 8),
                const SizedBox(width: 160, child: LinearProgressIndicator()),
              ],
            ),
            data: (_, message) => Text(message),
            error: (context, error, stackTrace) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not load: $error'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loadMessage,
                  child: const Text('Try again'),
                ),
              ],
            ),
            errorWithValue: (context, error, stackTrace, message) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message),
                const SizedBox(height: 8),
                Text('Could not reload: $error'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loadMessage,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
}
