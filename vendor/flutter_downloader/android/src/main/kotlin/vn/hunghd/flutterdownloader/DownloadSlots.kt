package vn.hunghd.flutterdownloader

/** Process-wide admission control. Persisted limits are read for every attempt. */
internal object DownloadSlots {
    private var active = 0

    @Synchronized fun acquire(limit: Int): Boolean {
        if (active >= limit.coerceAtLeast(1)) return false
        active++
        return true
    }

    @Synchronized fun release() { active-- }
}
