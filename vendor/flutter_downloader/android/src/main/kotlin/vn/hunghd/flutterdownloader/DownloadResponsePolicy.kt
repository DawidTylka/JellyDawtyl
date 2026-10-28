package vn.hunghd.flutterdownloader

import java.io.IOException
import java.io.File

internal object DownloadResponsePolicy {
    fun outputFile(directory: File, filename: String): File {
        if (!directory.exists() && !directory.mkdirs() && !directory.exists()) {
            throw IOException("Cannot create download directory")
        }
        val output = File(directory, filename)
        if (!output.exists() && !output.createNewFile()) throw IOException("Cannot create temporary download")
        if (!output.isFile) throw IOException("Download path is not a file")
        return output
    }

    /** A 200 response to Range replaces the partial file; only a valid 206 appends. */
    fun offset(resume: Boolean, responseCode: Int, downloaded: Long, contentRange: String?): Long {
        if (!resume || responseCode != 206) return 0
        val match = Regex("bytes (\\d+)-(\\d+)/(\\d+)").matchEntire(contentRange ?: "")
            ?: throw IOException("Missing or invalid Content-Range")
        val (start, end, total) = match.destructured
        if (start.toLong() != downloaded || end.toLong() + 1 != total.toLong() || end.toLong() < start.toLong()) {
            throw IOException("Incomplete or mismatched Content-Range")
        }
        return downloaded
    }

    fun verify(received: Long, contentLength: Long) {
        if (received <= 0 || (contentLength >= 0 && received != contentLength)) {
            throw IOException("Incomplete HTTP response")
        }
    }
}
