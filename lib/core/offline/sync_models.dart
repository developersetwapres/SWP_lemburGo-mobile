enum SyncOperationType { create, update, delete }

enum SyncOperationState {
  pending,
  syncing,
  retryWaiting,
  blockedValidation,
  blockedIdentity,
  awaitingAuthentication,
}

enum LocalSyncState {
  synced,
  pending,
  syncing,
  retryWaiting,
  blocked,
  awaitingAuthentication,
}

extension LocalSyncStateLabel on LocalSyncState {
  String get label => switch (this) {
    LocalSyncState.synced => 'Tersinkron',
    LocalSyncState.pending => 'Menunggu sinkronisasi',
    LocalSyncState.syncing => 'Menyinkronkan',
    LocalSyncState.retryWaiting => 'Akan dicoba lagi',
    LocalSyncState.blocked => 'Perlu diperbaiki',
    LocalSyncState.awaitingAuthentication => 'Masuk kembali untuk sinkronisasi',
  };
}

class PendingSyncOperation {
  const PendingSyncOperation({
    required this.id,
    required this.ownerId,
    required this.localId,
    required this.type,
    required this.state,
    required this.revision,
    required this.attemptCount,
    required this.createdAt,
    this.lastError,
    this.nextAttemptAt,
  });

  final String id;
  final String ownerId;
  final String localId;
  final SyncOperationType type;
  final SyncOperationState state;
  final int revision;
  final int attemptCount;
  final DateTime createdAt;
  final String? lastError;
  final DateTime? nextAttemptAt;
}
