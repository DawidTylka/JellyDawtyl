package vn.hunghd.flutterdownloader

import java.io.IOException
import java.io.File
import java.io.FileOutputStream
import java.nio.file.Files
import org.junit.Assert.*
import org.junit.Test

class DownloadResponsePolicyTest {
    @Test fun restartingTransferCanTruncateAnExistingTemporaryFile() {
        val directory = Files.createTempDirectory("download-restart").toFile()
        try {
            File(directory, "video.part").writeBytes(byteArrayOf(1, 2, 3, 4))
            val output = DownloadResponsePolicy.outputFile(directory, "video.part")
            FileOutputStream(output, false).use { it.write(byteArrayOf(9)) }
            assertArrayEquals(byteArrayOf(9), output.readBytes())
        } finally { directory.deleteRecursively() }
    }
    @Test fun transferCreatesMissingOutputDirectory() {
        val directory = Files.createTempDirectory("download-directory").toFile()
        try {
            assertTrue(DownloadResponsePolicy.outputFile(File(directory, "nested"), "video.part").isFile)
        } finally { directory.deleteRecursively() }
    }

    @Test fun ignoredRangeRestartsInsteadOfAppending() {
        assertEquals(0L, DownloadResponsePolicy.offset(true, 200, 500, null))
    }
    @Test fun validRangeResumesAtExactOffset() {
        assertEquals(500L, DownloadResponsePolicy.offset(true, 206, 500, "bytes 500-999/1000"))
    }
    @Test(expected = IOException::class) fun wrongOffsetIsRejected() {
        DownloadResponsePolicy.offset(true, 206, 500, "bytes 0-999/1000")
    }
    @Test(expected = IOException::class) fun incompleteRangeIsRejected() {
        DownloadResponsePolicy.offset(true, 206, 500, "bytes 500-599/1000")
    }
    @Test(expected = IOException::class) fun truncatedBodyIsRejected() {
        DownloadResponsePolicy.verify(500, 1000)
    }
    @Test(expected = IOException::class) fun emptyUnknownLengthBodyIsRejected() {
        DownloadResponsePolicy.verify(0, -1)
    }
    @Test fun completeAndChunkedBodiesAreAccepted() {
        DownloadResponsePolicy.verify(1000, 1000)
        DownloadResponsePolicy.verify(1000, -1)
    }
}
