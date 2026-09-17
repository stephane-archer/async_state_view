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

  @override
  void initState() {
    super.initState();
    _loadMessage();
  }

  Future<void> _loadMessage() async {
    setState(() => _message = const AsyncLoading());

    try {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _message = const AsyncData('The result is ready.'));
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() => _message = AsyncError(error, stackTrace));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Async state view')),
        body: Center(
          child: AsyncStateBuilder<String>(
            state: _message,
            loading: (_) => const CircularProgressIndicator(),
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
          ),
        ),
      );
}
