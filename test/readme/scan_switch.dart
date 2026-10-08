import 'package:async_state_view/async_state_view.dart';

import 'scan_controller.dart';

// The README's switch example, in scanLabel, and its case for a nullable
// value, in nullableLabel.

String scanLabel(ScanController controller) {
  // #region switch
  final label = switch (controller.scan) {
    AsyncLoading(valueOrNull: final totals?) => '${totals.count} so far…',
    AsyncLoading() => 'Starting…',
    AsyncData(:final value) => '${value.count} in total',
    AsyncError(:final error) => 'Failed: $error',
  };
  // #endregion
  return label;
}

String nullableLabel(AsyncState<int?> state) {
  return switch (state) {
    // #region nullable-case
    AsyncLoading(hasValue: true, :final valueOrNull) => 'So far: $valueOrNull',
    // #endregion
    AsyncLoading() => 'Starting…',
    AsyncData(:final value) => '$value in total',
    AsyncError(:final error) => 'Failed: $error',
  };
}
