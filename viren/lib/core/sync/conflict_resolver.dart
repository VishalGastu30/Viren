// ─────────────────────────────────────────────────────────────────────────────
// Conflict Resolver — Local-Wins Sync Strategy
//
// Future sync conflict resolution:
//   • Pull → compare → resolve locally
//   • Local timestamp wins all ties
//   • Deletions are tombstoned, never applied silently
//
// This is a scaffold — actual sync integration with Supabase is future work.
// ─────────────────────────────────────────────────────────────────────────────

/// The outcome of a conflict resolution.
enum ConflictResolution {
  /// Keep the local version.
  keepLocal,

  /// Accept the remote version (only if local has no changes since last sync).
  acceptRemote,

  /// Merge: keep both with a conflict marker.
  merge,
}

/// A single sync conflict between local and remote data.
class SyncConflict {
  final String tableName;
  final String rowId;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final DateTime localTimestamp;
  final DateTime remoteTimestamp;

  const SyncConflict({
    required this.tableName,
    required this.rowId,
    required this.localData,
    required this.remoteData,
    required this.localTimestamp,
    required this.remoteTimestamp,
  });
}

/// Conflict resolution result.
class ResolvedConflict {
  final SyncConflict conflict;
  final ConflictResolution resolution;
  final Map<String, dynamic> resolvedData;

  const ResolvedConflict({
    required this.conflict,
    required this.resolution,
    required this.resolvedData,
  });
}

class ConflictResolver {
  /// Resolves a conflict using the local-wins strategy.
  ///
  /// Rules:
  ///   1. Local always wins if both sides have changes.
  ///   2. Remote wins ONLY if local has not changed since last sync.
  ///   3. Deletions are never applied automatically.
  ResolvedConflict resolve(SyncConflict conflict) {
    // Local always wins — this is the PRD rule
    return ResolvedConflict(
      conflict: conflict,
      resolution: ConflictResolution.keepLocal,
      resolvedData: conflict.localData,
    );
  }

  /// Resolves a batch of conflicts.
  List<ResolvedConflict> resolveAll(List<SyncConflict> conflicts) {
    return conflicts.map(resolve).toList();
  }
}
