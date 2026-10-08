// #region scan-view
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
// #endregion
