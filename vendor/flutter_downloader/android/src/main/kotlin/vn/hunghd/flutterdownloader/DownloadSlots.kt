package vn.hunghd.flutterdownloader

/** Process-wide admission control. Persisted limits are read for every attempt. */
internal object DownloadSlots {
    private var active = 0
    private var lastReleaseAt = 0L

    /**
     * WorkManager stops its foreground service when the last foreground worker
     * ends. Starting the next one in the same moment makes Android restart the
     * service while it is shutting down, and the system then kills the app with
     * ForegroundServiceDidNotStartInTimeException. A short gap avoids that.
     */
    const val FOREGROUND_RESTART_GAP_MS = 2000L

    @Synchronized fun millisUntilForegroundAllowed(): Long {
        if (active > 1) return 0 // another transfer keeps the service running
        val elapsed = System.currentTimeMillis() - lastReleaseAt
        return (FOREGROUND_RESTART_GAP_MS - elapsed).coerceAtLeast(0)
    }

    @Synchronized fun acquire(limit: Int): Boolean {
        if (active >= limit.coerceAtLeast(1)) return false
        active++
        return true
    }

    @Synchronized fun release() {
        active--
        lastReleaseAt = System.currentTimeMillis()
    }
}
