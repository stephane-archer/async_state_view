// #region scan-controller
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
// #endregion

// Stand-ins for the model and data source that the README leaves to the app.

final class Totals {
  const Totals(this.count);

  static const empty = Totals(0);

  final int count;

  @override
  int get hashCode => count.hashCode;

  @override
  bool operator ==(Object other) => other is Totals && count == other.count;
}

abstract interface class Scanner {
  Stream<Totals> scan();
}
