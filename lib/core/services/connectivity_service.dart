import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _statusController = StreamController<bool>.broadcast();

  bool _isOnline = false;
  bool get isOnline => _isOnline;
  Stream<bool> get onlineStream => _statusController.stream;

  /// Callback that gets called when the device comes back online
  void Function()? onReconnect;

  /// Callback that gets called periodically for background auto-sync
  void Function()? onSyncTick;

  Timer? _periodicTimer;

  Future<void> init() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = _checkResults(results);
    _statusController.add(_isOnline);

    if (_isOnline && onReconnect != null) {
      onReconnect!();
    }

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOffline = !_isOnline;
      _isOnline = _checkResults(results);
      _statusController.add(_isOnline);

      if (_isOnline && wasOffline && onReconnect != null) {
        onReconnect!();
      }
    });

    // Start background auto-sync timer (ticks every 15 seconds)
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_isOnline && onSyncTick != null) {
        onSyncTick!();
      }
    });
  }

  bool _checkResults(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }

  void dispose() {
    _periodicTimer?.cancel();
    _subscription?.cancel();
    _statusController.close();
  }
}
