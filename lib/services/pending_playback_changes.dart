typedef PlaybackChangeSynchronizer =
    Future<bool> Function(Map<String, dynamic> change);

Future<bool> synchronizePlaybackChange({
  required Map<String, dynamic> change,
  required Future<bool> Function() reportProgress,
  required Future<bool> Function() markPlayed,
}) async {
  if (!await reportProgress()) return false;
  if (change['played'] == true) return markPlayed();
  return true;
}

/// Flushes persisted offline playback edits without discarding failed updates.
Future<void> flushPendingPlaybackChanges({
  required Map<String, Map<String, dynamic>> pending,
  required PlaybackChangeSynchronizer synchronize,
  required Future<void> Function() save,
}) async {
  for (final entry in pending.entries.toList()) {
    var synchronized = false;
    try {
      synchronized = await synchronize(entry.value);
    } catch (_) {
      // Keep this change queued and continue with other items.
    }
    if (!synchronized) continue;
    pending.remove(entry.key);
    await save();
  }
}
