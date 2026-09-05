import 'package:flutter/foundation.dart';

/// UI-facing state. A network transport is only a hint; [apiReachable] turns
/// true after a real Laravel request succeeds.
class SyncStatus extends ChangeNotifier {
  bool hasNetworkTransport = true;
  bool apiReachable = false;
  bool isSyncing = false;
  int pendingCount = 0;
  String? lastError;
  DateTime? lastSuccessfulSyncAt;

  void update({
    bool? hasNetworkTransport,
    bool? apiReachable,
    bool? isSyncing,
    int? pendingCount,
    String? lastError,
    bool clearError = false,
    DateTime? lastSuccessfulSyncAt,
  }) {
    var changed = false;
    void assign<T>(T current, T? next, void Function(T value) set) {
      if (next != null && next != current) {
        set(next);
        changed = true;
      }
    }

    assign(
      this.hasNetworkTransport,
      hasNetworkTransport,
      (value) => this.hasNetworkTransport = value,
    );
    assign(
      this.apiReachable,
      apiReachable,
      (value) => this.apiReachable = value,
    );
    assign(this.isSyncing, isSyncing, (value) => this.isSyncing = value);
    assign(
      this.pendingCount,
      pendingCount,
      (value) => this.pendingCount = value,
    );
    assign(
      this.lastSuccessfulSyncAt,
      lastSuccessfulSyncAt,
      (value) => this.lastSuccessfulSyncAt = value,
    );
    if (clearError && this.lastError != null) {
      this.lastError = null;
      changed = true;
    } else if (lastError != null && lastError != this.lastError) {
      this.lastError = lastError;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}
