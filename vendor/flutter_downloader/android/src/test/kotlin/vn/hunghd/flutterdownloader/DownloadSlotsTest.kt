package vn.hunghd.flutterdownloader

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

class DownloadSlotsTest {
    @Test fun limitOneBlocksAllOtherWorkersUntilRelease() {
        assertTrue(DownloadSlots.acquire(1))
        try { repeat(20) { assertFalse(DownloadSlots.acquire(1)) } }
        finally { DownloadSlots.release() }
        assertTrue(DownloadSlots.acquire(1))
        DownloadSlots.release()
    }

    @Test fun loweringLimitWaitsForExistingTransfers() {
        repeat(3) { assertTrue(DownloadSlots.acquire(3)) }
        assertFalse(DownloadSlots.acquire(1))
        repeat(2) { DownloadSlots.release(); assertFalse(DownloadSlots.acquire(1)) }
        DownloadSlots.release()
        assertTrue(DownloadSlots.acquire(0))
        DownloadSlots.release()
    }

    @Test fun simultaneousWorkersCannotExceedLimit() {
        val pool = Executors.newFixedThreadPool(16)
        val start = CountDownLatch(1)
        val admitted = AtomicInteger()
        val futures = (1..100).map {
            pool.submit { start.await(); if (DownloadSlots.acquire(1)) admitted.incrementAndGet() }
        }
        start.countDown()
        futures.forEach { it.get() }
        try { assertEquals(1, admitted.get()) }
        finally { DownloadSlots.release(); pool.shutdownNow() }
    }
}
