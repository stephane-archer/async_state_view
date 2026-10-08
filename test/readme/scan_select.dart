import 'package:async_state_view/async_state_view.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'scan_controller.dart';

// The README's context.select examples, in scanFound and scanCount.

AsyncState<bool> scanFound(BuildContext context) {
  // #region found
  // Rebuilds when `found` flips or the scan ends, not on every progress update.
  final found = context.select(
    (ScanController controller) =>
        controller.scan.mapValue((totals) => totals.count > 0),
  );
  // #endregion
  return found;
}

AsyncState<int> scanCount(BuildContext context) {
  // #region count
  // Rebuilds when the scan starts, ends or fails, not on progress updates.
  final count = context.select(
    (ScanController controller) => controller.scan
        .withoutCarriedValue()
        .mapValue((totals) => totals.count),
  );
  // #endregion
  return count;
}
