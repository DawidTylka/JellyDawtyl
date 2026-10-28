package vn.hunghd.flutterdownloader

import android.Manifest
import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.provider.MediaStore
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.ForegroundInfo
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import org.json.JSONException
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.io.UnsupportedEncodingException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLDecoder
import java.security.SecureRandom
import java.security.cert.X509Certificate
import java.util.ArrayDeque
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean
import java.util.regex.Pattern
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

class DownloadWorker(context: Context, params: WorkerParameters) :
    Worker(context, params),
    MethodChannel.MethodCallHandler {
    private val charsetPattern = Pattern.compile("(?i)\\bcharset=\\s*\"?([^\\s;\"]*)")
    private val filenameStarPattern =
        Pattern.compile("(?i)\\bfilename\\*=([^']+)'([^']*)'\"?([^\"]+)\"?")
    private val filenamePattern = Pattern.compile("(?i)\\bfilename=\"?([^\"]+)\"?")
    private var backgroundChannel: MethodChannel? = null
    private var dbHelper: TaskDbHelper? = null
    private var taskDao: TaskDao? = null
    private var showNotification = false
    private var clickToOpenDownloadedFile = false
    private var debug = false
    private var lastProgress = 0
    private var primaryId = 0
    private var msgStarted: String? = null
    private var msgInProgress: String? = null
    private var msgCanceled: String? = null
    private var msgFailed: String? = null
    private var msgPaused: String? = null
    private var msgComplete: String? = null
    private var lastCallUpdateNotification: Long = 0
    private var step = 0
    private var saveInPublicStorage = false
    private fun startBackgroundIsolate(context: Context) {
        synchronized(isolateStarted) {
            if (backgroundFlutterEngine == null) {
                val pref: SharedPreferences = context.getSharedPreferences(
                    FlutterDownloaderPlugin.SHARED_PREFERENCES_KEY,
                    Context.MODE_PRIVATE
                )
                val callbackHandle: Long = pref.getLong(
                    FlutterDownloaderPlugin.CALLBACK_DISPATCHER_HANDLE_KEY,
                    0
                )
                backgroundFlutterEngine = FlutterEngine(applicationContext, null, false)

                // We need to create an instance of `FlutterEngine` before looking up the
                // callback. If we don't, the callback cache won't be initialized and the
                // lookup will fail.
                val flutterCallback: FlutterCallbackInformation? =
                    FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)
                if (flutterCallback == null) {
                    log("Fatal: failed to find callback")
                    return
                }
                val appBundlePath: String =
                    FlutterInjector.instance().flutterLoader().findAppBundlePath()
                val assets = applicationContext.assets
                backgroundFlutterEngine?.dartExecutor?.executeDartCallback(
                    DartExecutor.DartCallback(
                        assets,
                        appBundlePath,
                        flutterCallback
                    )
                )
            }
        }
        backgroundChannel = MethodChannel(
            backgroundFlutterEngine!!.dartExecutor,
            "vn.hunghd/downloader_background"
        )
        backgroundChannel?.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method.equals("didInitializeDispatcher")) {
            synchronized(isolateStarted) {
                while (!isolateQueue.isEmpty()) {
                    backgroundChannel?.invokeMethod("", isolateQueue.remove())
                }
                isolateStarted.set(true)
                result.success(null)
            }
        } else {
            result.notImplemented()
        }
    }

    override fun doWork(): Result {
        val preferences = applicationContext.getSharedPreferences("download_limits", Context.MODE_PRIVATE)
        // Waiting for a slot is not a failed transfer: avoid exponential backoff
        // that could delay queued episodes for hours after a long movie ends.
        while (!DownloadSlots.acquire(preferences.getInt("max_concurrent", 1))) {
            if (isStopped) return Result.retry()
            try { Thread.sleep(500) } catch (_: InterruptedException) { return Result.retry() }
        }
        if (isStopped) { DownloadSlots.release(); return Result.retry() }
        return try { performWork() } finally { DownloadSlots.release() }
    }

    private fun performWork(): Result {
        dbHelper = TaskDbHelper.getInstance(applicationContext)
        taskDao = TaskDao(dbHelper!!)
        val url: String =
            inputData.getString(ARG_URL) ?: throw IllegalArgumentException("Argument '$ARG_URL' should not be null")
        val filename: String? =
            inputData.getString(ARG_FILE_NAME) // ?: throw IllegalArgumentException("Argument '$ARG_FILE_NAME' should not be null")
        val savedDir: String = inputData.getString(ARG_SAVED_DIR)
            ?: throw IllegalArgumentException("Argument '$ARG_SAVED_DIR' should not be null")
        val headers: String = inputData.getString(ARG_HEADERS)
            ?: throw IllegalArgumentException("Argument '$ARG_HEADERS' should not be null")
        var isResume: Boolean = inputData.getBoolean(ARG_IS_RESUME, false)
        val timeout: Int = inputData.getInt(ARG_TIMEOUT, 15000)
        debug = inputData.getBoolean(ARG_DEBUG, false)
        step = inputData.getInt(ARG_STEP, 10)
        val res = applicationContext.resources
        msgStarted = res.getString(R.string.flutter_downloader_notification_started)
        msgInProgress = res.getString(R.string.flutter_downloader_notification_in_progress)
        msgCanceled = res.getString(R.string.flutter_downloader_notification_canceled)
        msgFailed = res.getString(R.string.flutter_downloader_notification_failed)
        msgPaused = res.getString(R.string.flutter_downloader_notification_paused)
        msgComplete = res.getString(R.string.flutter_downloader_notification_complete)
        val task = taskDao?.loadTask(id.toString())
        // Task has been deleted or cancelled
        if (task == null || task.status == DownloadStatus.CANCELED || task.status == DownloadStatus.COMPLETE) {
            return Result.success()
        }
        showNotification = inputData.getBoolean(ARG_SHOW_NOTIFICATION, false)
        clickToOpenDownloadedFile =
            inputData.getBoolean(ARG_OPEN_FILE_FROM_NOTIFICATION, false)
        saveInPublicStorage = inputData.getBoolean(ARG_SAVE_IN_PUBLIC_STORAGE, false)
        primaryId = task.primaryId
        setupNotification(applicationContext)
        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setContentTitle(filename ?: "Pobieranie")
            .setContentText(msgInProgress)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true).build()
        try {
            val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ForegroundInfo(primaryId, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else ForegroundInfo(primaryId, notification)
            setForegroundAsync(info).get()
        } catch (_: Exception) {
            taskDao?.updateTask(id.toString(), DownloadStatus.ENQUEUED, task.progress)
            return Result.retry()
        }
        updateNotification(
            applicationContext,
            filename ?: url,
            DownloadStatus.RUNNING,
            task.progress,
            null,
            false
        )
        taskDao?.updateTask(id.toString(), DownloadStatus.RUNNING, task.progress)

        // automatic resume for partial files. (if the workmanager unexpectedly quited in background)
        val saveFilePath = savedDir + File.separator + filename
        val partialFile = File(if (saveInPublicStorage) saveFilePath else "$saveFilePath.part")
        if (!saveInPublicStorage && File(saveFilePath).exists() && !partialFile.exists()) {
            File(saveFilePath).renameTo(partialFile)
        }
        if (Uri.parse(url).getQueryParameter("Static") == "false") isResume = false
        if (partialFile.exists() && partialFile.length() > 0 && Uri.parse(url).getQueryParameter("Static") != "false") {
            isResume = true
            log("exists file for " + filename + "automatic resuming...")
        }
        return try {
            downloadFile(applicationContext, url, savedDir, filename, headers, isResume, timeout)
            cleanUp()
            dbHelper = null
            taskDao = null
            Result.success()
        } catch (e: IOException) {
            val current = taskDao?.loadTask(id.toString())
            if (current?.status == DownloadStatus.CANCELED || current?.resumable == true) return Result.success()
            taskDao?.updateTask(id.toString(), DownloadStatus.ENQUEUED, lastProgress)
            updateNotification(applicationContext, filename ?: url, DownloadStatus.ENQUEUED, lastProgress, null, false)
            Result.retry()
        } catch (e: Exception) {
            updateNotification(applicationContext, filename ?: url, DownloadStatus.FAILED, -1, null, true)
            taskDao?.updateTask(id.toString(), DownloadStatus.FAILED, lastProgress)
            dbHelper = null
            taskDao = null
            Result.failure()
        }
    }

    private fun setupHeaders(conn: HttpURLConnection, headers: String) {
        if (headers.isNotEmpty()) {
            log("Applying download headers")
            try {
                val json = JSONObject(headers)
                val it: Iterator<String> = json.keys()
                while (it.hasNext()) {
                    val key = it.next()
                    conn.setRequestProperty(key, json.getString(key))
                }
                conn.doInput = true
            } catch (e: JSONException) {
                e.printStackTrace()
            }
        }
    }

    private fun setupPartialDownloadedDataHeader(
        conn: HttpURLConnection,
        filename: String?,
        savedDir: String
    ): Long {
        val saveFilePath = savedDir + File.separator + filename
        val partialFile = File(if (saveInPublicStorage) saveFilePath else "$saveFilePath.part")
        val downloadedBytes: Long = partialFile.length()
        log("Resume download: Range: bytes=$downloadedBytes-")
        conn.setRequestProperty("Accept-Encoding", "identity")
        conn.setRequestProperty("Range", "bytes=$downloadedBytes-")
        conn.doInput = true
        return downloadedBytes
    }

    private fun downloadFile(
        context: Context,
        fileURL: String,
        savedDir: String,
        filename: String?,
        headers: String,
        isResume: Boolean,
        timeout: Int
    ) {
        var actualFilename = filename
        var url = fileURL
        var resourceUrl: URL
        var base: URL?
        var next: URL
        val visited: MutableMap<String, Int>
        var httpConn: HttpURLConnection? = null
        var inputStream: InputStream? = null
        var outputStream: OutputStream? = null
        var location: String
        var downloadedBytes: Long = 0
        var responseCode: Int
        var times: Int
        visited = HashMap()
        try {
            val task = taskDao?.loadTask(id.toString())
            if (task != null) {
                lastProgress = task.progress
            }

            // handle redirection logic
            while (true) {
                if (!visited.containsKey(url)) {
                    times = 1
                    visited[url] = times
                } else {
                    times = visited[url]!! + 1
                }
                if (times > 3) throw IOException("Stuck in redirect loop")
                resourceUrl = URL(url)
                httpConn = if (resourceUrl.protocol.lowercase(Locale.US) == "https") {
                    (resourceUrl.openConnection() as HttpsURLConnection).also { https ->
                        if (isTrustedHttpsHost(resourceUrl.host)) {
                            https.sslSocketFactory = createTrustHostCertificateSocketFactory()
                        }
                    }
                } else {
                    resourceUrl.openConnection() as HttpURLConnection
                }
                log("Open connection to $url")
                httpConn.connectTimeout = timeout
                httpConn.readTimeout = timeout
                httpConn.instanceFollowRedirects = false // Make the logic below easier to detect redirections
                httpConn.setRequestProperty("User-Agent", "Mozilla/5.0...")
                httpConn.setRequestProperty("Accept-Encoding", "identity")

                // setup request headers if it is set
                setupHeaders(httpConn, headers)
                // try to continue downloading a file from its partial downloaded data.
                if (isResume) {
                    downloadedBytes = setupPartialDownloadedDataHeader(httpConn, actualFilename, savedDir)
                }
                responseCode = httpConn.responseCode
                when (responseCode) {
                    HttpURLConnection.HTTP_MOVED_PERM,
                    HttpURLConnection.HTTP_SEE_OTHER,
                    HttpURLConnection.HTTP_MOVED_TEMP,
                    307,
                    308 -> {
                        log("Response with redirection code")
                        location = httpConn.getHeaderField("Location")
                        log("Location = $location")
                        base = URL(url)
                        next = URL(base, location) // Deal with relative URLs
                        url = next.toExternalForm()
                        log("New url: $url")
                        continue
                    }
                }
                break
            }
            httpConn!!.connect()
            val contentType: String?
            if ((responseCode == HttpURLConnection.HTTP_OK || isResume && responseCode == HttpURLConnection.HTTP_PARTIAL) && !isStopped) {
                val append = isResume && responseCode == HttpURLConnection.HTTP_PARTIAL
                downloadedBytes = DownloadResponsePolicy.offset(isResume, responseCode, downloadedBytes, httpConn.getHeaderField("Content-Range"))
                contentType = httpConn.contentType
                val contentLength: Long =
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) httpConn.contentLengthLong else httpConn.contentLength.toLong()
                if (contentType != null) {
                    log("Content-Type = $contentType")
                }
                log("Content-Length = $contentLength")
                val charset = getCharsetFromContentType(contentType)
                log("Charset = $charset")
                if (!isResume) {
                    // try to extract filename from HTTP headers if it is not given by user
                    if (actualFilename == null) {
                        val disposition: String? = httpConn.getHeaderField("Content-Disposition")
                        log("Content-Disposition = $disposition")
                        if (!disposition.isNullOrEmpty()) {
                            actualFilename = getFileNameFromContentDisposition(disposition, charset)
                        }
                        if (actualFilename.isNullOrEmpty()) {
                            actualFilename = url.substring(url.lastIndexOf("/") + 1)
                            try {
                                actualFilename = URLDecoder.decode(actualFilename, "UTF-8")
                            } catch (e: IllegalArgumentException) {
                                /* ok, just let filename be not encoded */
                                e.printStackTrace()
                            }
                        }
                    }
                }
                log("fileName = $actualFilename")
                taskDao?.updateTask(id.toString(), actualFilename, contentType)

                // opens input stream from the HTTP connection
                inputStream = httpConn.inputStream
                var savedFilePath: String?
                // opens an output stream to save into file
                // there are two case:
                if (append) {
                    // 1. continue downloading (append data to partial downloaded file)
                    savedFilePath = savedDir + File.separator + actualFilename + if (saveInPublicStorage) "" else ".part"
                    outputStream = FileOutputStream(savedFilePath, true)
                } else {
                    // 2. new download, create new file
                    // there are two case according to Android SDK version and save path
                    // From Android 11 onwards, file is only downloaded to app-specific directory (internal storage)
                    // or public shared download directory (external storage).
                    // The second option will ignore `savedDir` parameter.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && saveInPublicStorage) {
                        val uri = createFileInPublicDownloadsDir(actualFilename, contentType)
                        savedFilePath = getMediaStoreEntryPathApi29(uri!!)
                        outputStream = context.contentResolver.openOutputStream(uri, "w")
                    } else {
                        val file = createFileInAppSpecificDir(actualFilename!! + if (saveInPublicStorage) "" else ".part", savedDir)
                        savedFilePath = file!!.path
                        outputStream = FileOutputStream(file, false)
                    }
                }
                var count = downloadedBytes
                var bytesRead: Int
                val buffer = ByteArray(BUFFER_SIZE)
                // using isStopped to monitor canceling task
                while (inputStream.read(buffer).also { bytesRead = it } != -1 && !isStopped) {
                    count += bytesRead.toLong()
                    val totalBytes = contentLength + downloadedBytes
                    val progress = if (contentLength <= 0L || totalBytes <= 0L) {
                        // Jellyfin transcodes may use chunked transfer encoding and
                        // report Content-Length = -1. Never divide by that sentinel:
                        // it produces negative/overflowed percentages.
                        -1
                    } else {
                        ((count.toDouble() * 100.0 / totalBytes.toDouble()).toInt())
                            .coerceIn(0, 100)
                    }
                    outputStream?.write(buffer, 0, bytesRead)
                    if ((lastProgress == 0 || progress > lastProgress + step || progress == 100) &&
                        progress != lastProgress
                    ) {
                        lastProgress = progress

                        // This line possibly causes system overloaded because of accessing to DB too many ?!!!
                        // but commenting this line causes tasks loaded from DB missing current downloading progress,
                        // however, this missing data should be temporary and it will be updated as soon as
                        // a new bunch of data fetched and a notification sent
                        taskDao!!.updateTask(id.toString(), DownloadStatus.RUNNING, progress)
                        updateNotification(
                            context,
                            actualFilename,
                            DownloadStatus.RUNNING,
                            progress,
                            null,
                            false
                        )
                    }
                }
                if (!isStopped) {
                    DownloadResponsePolicy.verify(count - downloadedBytes, contentLength)
                    outputStream?.flush()
                    outputStream?.close()
                    outputStream = null
                    if (!saveInPublicStorage) {
                        val completed = File(savedDir, actualFilename!!)
                        if (!File(savedFilePath!!).renameTo(completed)) throw IOException("Cannot publish completed download")
                        savedFilePath = completed.path
                    }
                }
                val loadedTask = taskDao?.loadTask(id.toString())
                val progress = if (isStopped && loadedTask!!.resumable) lastProgress else 100
                val status =
                    if (isStopped) if (loadedTask!!.resumable) DownloadStatus.PAUSED else if (loadedTask.status == DownloadStatus.CANCELED) DownloadStatus.CANCELED else DownloadStatus.ENQUEUED else DownloadStatus.COMPLETE
                val storage: Int = ContextCompat.checkSelfPermission(
                    applicationContext,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE
                )
                var pendingIntent: PendingIntent? = null
                if (status == DownloadStatus.COMPLETE) {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                        if (isImageOrVideoFile(contentType) && isExternalStoragePath(savedFilePath)) {
                            addImageOrVideoToGallery(
                                actualFilename,
                                savedFilePath,
                                getContentTypeWithoutCharset(contentType)
                            )
                        }
                    }
                    if (clickToOpenDownloadedFile) {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q && storage != PackageManager.PERMISSION_GRANTED) return
                        val intent = IntentUtils.validatedFileIntent(
                            applicationContext,
                            savedFilePath!!,
                            contentType
                        )
                        if (intent != null) {
                            log("Setting an intent to open the file $savedFilePath")
                            val flags: Int =
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_CANCEL_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_CANCEL_CURRENT
                            pendingIntent =
                                PendingIntent.getActivity(applicationContext, 0, intent, flags)
                        } else {
                            log("There's no application that can open the file $savedFilePath")
                        }
                    }
                }
                taskDao!!.updateTask(id.toString(), status, progress)
                updateNotification(context, actualFilename, status, progress, pendingIntent, true)
                log(if (isStopped) "Download canceled" else "File downloaded")
            } else {
                if (!isStopped && (responseCode == 408 || responseCode == 429 || responseCode >= 500 || responseCode == 416)) {
                    if (responseCode == 416) File(savedDir, "$actualFilename.part").delete()
                    throw IOException("Temporary HTTP failure: $responseCode")
                }
                val loadedTask = taskDao!!.loadTask(id.toString())
                val status =
                    if (isStopped) if (loadedTask!!.resumable) DownloadStatus.PAUSED else if (loadedTask.status == DownloadStatus.CANCELED) DownloadStatus.CANCELED else DownloadStatus.ENQUEUED else DownloadStatus.FAILED
                taskDao!!.updateTask(id.toString(), status, lastProgress)
                updateNotification(context, actualFilename ?: fileURL, status, -1, null, true)
                log(if (isStopped) "Download canceled" else "Server replied HTTP code: $responseCode")
            }
        } finally {
            if (outputStream != null) {
                outputStream.flush()
                try {
                    outputStream.close()
                } catch (e: IOException) {
                    e.printStackTrace()
                }
            }
            if (inputStream != null) {
                try {
                    inputStream.close()
                } catch (e: IOException) {
                    e.printStackTrace()
                }
            }
            httpConn?.disconnect()
        }
    }

    /**
     * Create a file using java.io API
     */
    private fun createFileInAppSpecificDir(filename: String, savedDir: String): File =
        DownloadResponsePolicy.outputFile(File(savedDir), filename)

    /**
     * Create a file inside the Download folder using MediaStore API
     */
    @RequiresApi(Build.VERSION_CODES.Q)
    private fun createFileInPublicDownloadsDir(filename: String?, mimeType: String?): Uri? {
        val collection: Uri = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        val values = ContentValues()
        values.put(MediaStore.Downloads.DISPLAY_NAME, filename)
        values.put(MediaStore.Downloads.MIME_TYPE, mimeType)
        values.put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
        val contentResolver = applicationContext.contentResolver
        try {
            return contentResolver.insert(collection, values)
        } catch (e: Exception) {
            e.printStackTrace()
            logError("Create a file using MediaStore API failed.")
        }
        return null
    }

    /**
     * Get a path for a MediaStore entry as it's needed when calling MediaScanner
     */
    private fun getMediaStoreEntryPathApi29(uri: Uri): String? {
        try {
            applicationContext.contentResolver.query(
                uri,
                arrayOf(MediaStore.Files.FileColumns.DATA),
                null,
                null,
                null
            ).use { cursor ->
                if (cursor == null) return null
                return if (!cursor.moveToFirst()) {
                    null
                } else {
                    cursor.getString(
                        cursor.getColumnIndexOrThrow(
                            MediaStore.Files.FileColumns.DATA
                        )
                    )
                }
            }
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
            logError("Get a path for a MediaStore failed")
            return null
        }
    }

    private fun cleanUp() {
        val task = taskDao!!.loadTask(id.toString())
        if (task != null && task.status != DownloadStatus.COMPLETE && !task.resumable) {
            var filename = task.filename
            if (filename == null) {
                filename = task.url.substring(task.url.lastIndexOf("/") + 1, task.url.length)
            }

            // check and delete uncompleted file
            val saveFilePath = task.savedDir + File.separator + filename
            val tempFile = File(saveFilePath)
            if (tempFile.exists()) {
                tempFile.delete()
            }
        }
    }

    private val notificationIconRes: Int
        get() {
            try {
                val applicationInfo: ApplicationInfo = applicationContext.packageManager
                    .getApplicationInfo(
                        applicationContext.packageName,
                        PackageManager.GET_META_DATA
                    )
                val appIconResId: Int = applicationInfo.icon
                return applicationInfo.metaData.getInt(
                    "vn.hunghd.flutterdownloader.NOTIFICATION_ICON",
                    appIconResId
                )
            } catch (e: PackageManager.NameNotFoundException) {
                e.printStackTrace()
            }
            return 0
        }

    private fun setupNotification(context: Context) {
        // Make a channel if necessary
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Create the NotificationChannel
            val res = applicationContext.resources
            val channelName: String = res.getString(R.string.flutter_downloader_notification_channel_name)
            val channelDescription: String = res.getString(R.string.flutter_downloader_notification_channel_description)
            val importance: Int = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, channelName, importance)
            channel.description = channelDescription
            channel.setSound(null, null)

            // Add the channel
            val notificationManager: NotificationManagerCompat = NotificationManagerCompat.from(context)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun updateNotification(
        context: Context,
        title: String?,
        status: DownloadStatus,
        progress: Int,
        intent: PendingIntent?,
        finalize: Boolean
    ) {
        sendUpdateProcessEvent(status, progress)

        // Show the notification
        if (showNotification) {
            // Create the notification
            val builder = NotificationCompat.Builder(context, CHANNEL_ID).setContentTitle(title)
                .setContentIntent(intent)
                .setOnlyAlertOnce(true)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
            when (status) {
                DownloadStatus.RUNNING -> {
                    if (progress < 0) {
                        builder.setContentText(msgInProgress)
                            .setProgress(0, 0, true)
                        builder.setOngoing(true)
                            .setSmallIcon(android.R.drawable.stat_sys_download)
                    } else if (progress == 0) {
                        builder.setContentText(msgStarted)
                            .setProgress(0, 0, false)
                        builder.setOngoing(false)
                            .setSmallIcon(notificationIconRes)
                    } else if (progress < 100) {
                        builder.setContentText(msgInProgress)
                            .setProgress(100, progress, false)
                        builder.setOngoing(true)
                            .setSmallIcon(android.R.drawable.stat_sys_download)
                    } else {
                        builder.setContentText(msgComplete).setProgress(0, 0, false)
                        builder.setOngoing(false)
                            .setSmallIcon(android.R.drawable.stat_sys_download_done)
                    }
                }

                DownloadStatus.CANCELED -> {
                    builder.setContentText(msgCanceled).setProgress(0, 0, false)
                    builder.setOngoing(false)
                        .setSmallIcon(android.R.drawable.stat_sys_download_done)
                }

                DownloadStatus.FAILED -> {
                    builder.setContentText(msgFailed).setProgress(0, 0, false)
                    builder.setOngoing(false)
                        .setSmallIcon(android.R.drawable.stat_sys_download_done)
                }

                DownloadStatus.PAUSED -> {
                    builder.setContentText(msgPaused).setProgress(0, 0, false)
                    builder.setOngoing(false)
                        .setSmallIcon(android.R.drawable.stat_sys_download_done)
                }

                DownloadStatus.COMPLETE -> {
                    builder.setContentText(msgComplete).setProgress(0, 0, false)
                    builder.setOngoing(false)
                        .setSmallIcon(android.R.drawable.stat_sys_download_done)
                }

                else -> {
                    builder.setProgress(0, 0, false)
                    builder.setOngoing(false).setSmallIcon(notificationIconRes)
                }
            }

            // Note: Android applies a rate limit when updating a notification.
            // If you post updates to a notification too frequently (many in less than one second),
            // the system might drop some updates. (https://developer.android.com/training/notify-user/build-notification#Updating)
            //
            // If this is progress update, it's not much important if it is dropped because there're still incoming updates later
            // If this is the final update, it must be success otherwise the notification will be stuck at the processing state
            // In order to ensure the final one is success, we check and sleep a second if need.
            if (System.currentTimeMillis() - lastCallUpdateNotification < 1000) {
                if (finalize) {
                    log("Update too frequently!!!!, but it is the final update, we should sleep a second to ensure the update call can be processed")
                    try {
                        Thread.sleep(1000)
                    } catch (e: InterruptedException) {
                        e.printStackTrace()
                    }
                } else {
                    log("Update too frequently!!!!, this should be dropped")
                    return
                }
            }
            log("Update notification: {notificationId: $primaryId, title: $title, status: $status, progress: $progress}")
            NotificationManagerCompat.from(context).notify(primaryId, builder.build())
            lastCallUpdateNotification = System.currentTimeMillis()
        }
    }

    private fun sendUpdateProcessEvent(status: DownloadStatus, progress: Int) {
        val args: MutableList<Any> = ArrayList()
        val callbackHandle: Long = inputData.getLong(ARG_CALLBACK_HANDLE, 0)
        args.add(callbackHandle)
        args.add(id.toString())
        args.add(status.ordinal)
        args.add(progress)
        synchronized(isolateStarted) {
            if (!isolateStarted.get()) {
                isolateQueue.add(args)
            } else {
                Handler(applicationContext.mainLooper).post {
                    backgroundChannel?.invokeMethod("", args)
                }
            }
        }
    }

    private fun getCharsetFromContentType(contentType: String?): String? {
        if (contentType == null) return null
        val m = charsetPattern.matcher(contentType)
        return if (m.find()) {
            m.group(1)?.trim { it <= ' ' }?.uppercase(Locale.US)
        } else {
            null
        }
    }

    @Throws(UnsupportedEncodingException::class)
    private fun getFileNameFromContentDisposition(
        disposition: String?,
        contentCharset: String?
    ): String? {
        if (disposition == null) return null
        var name: String? = null
        var charset = contentCharset

        // first, match plain filename, and then replace it with star filename, to follow the spec
        val plainMatcher = filenamePattern.matcher(disposition)
        if (plainMatcher.find()) name = plainMatcher.group(1)
        val starMatcher = filenameStarPattern.matcher(disposition)
        if (starMatcher.find()) {
            name = starMatcher.group(3)
            charset = starMatcher.group(1)?.uppercase(Locale.US)
        }
        return if (name == null) {
            null
        } else {
            URLDecoder.decode(
                name,
                charset ?: "ISO-8859-1"
            )
        }
    }

    private fun getContentTypeWithoutCharset(contentType: String?): String? {
        return contentType?.split(";")?.toTypedArray()?.get(0)?.trim { it <= ' ' }
    }

    private fun isImageOrVideoFile(contentType: String?): Boolean {
        val newContentType = getContentTypeWithoutCharset(contentType)
        return newContentType != null && (newContentType.startsWith("image/") || newContentType.startsWith("video"))
    }

    private fun isExternalStoragePath(filePath: String?): Boolean {
        val externalStorageDir: File = Environment.getExternalStorageDirectory()
        return filePath != null && filePath.startsWith(
            externalStorageDir.path
        )
    }

    private fun addImageOrVideoToGallery(
        fileName: String?,
        filePath: String?,
        contentType: String?
    ) {
        if (contentType != null && filePath != null && fileName != null) {
            if (contentType.startsWith("image/")) {
                val values = ContentValues()
                values.put(MediaStore.Images.Media.TITLE, fileName)
                values.put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                values.put(MediaStore.Images.Media.DESCRIPTION, "")
                values.put(MediaStore.Images.Media.MIME_TYPE, contentType)
                values.put(MediaStore.Images.Media.DATE_ADDED, System.currentTimeMillis())
                values.put(MediaStore.Images.Media.DATE_TAKEN, System.currentTimeMillis())
                values.put(MediaStore.Images.Media.DATA, filePath)
                log("insert $values to MediaStore")
                val contentResolver = applicationContext.contentResolver
                contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            } else if (contentType.startsWith("video")) {
                val values = ContentValues()
                values.put(MediaStore.Video.Media.TITLE, fileName)
                values.put(MediaStore.Video.Media.DISPLAY_NAME, fileName)
                values.put(MediaStore.Video.Media.DESCRIPTION, "")
                values.put(MediaStore.Video.Media.MIME_TYPE, contentType)
                values.put(MediaStore.Video.Media.DATE_ADDED, System.currentTimeMillis())
                values.put(MediaStore.Video.Media.DATE_TAKEN, System.currentTimeMillis())
                values.put(MediaStore.Video.Media.DATA, filePath)
                log("insert $values to MediaStore")
                val contentResolver = applicationContext.contentResolver
                contentResolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
            }
        }
    }

    private fun log(message: String) {
        if (debug) {
            Log.d(TAG, message)
        }
    }

    private fun logError(message: String) {
        if (debug) {
            Log.e(TAG, message)
        }
    }

    private fun isTrustedHttpsHost(host: String): Boolean {
        val pref = applicationContext.getSharedPreferences(
            FlutterDownloaderPlugin.SHARED_PREFERENCES_KEY,
            Context.MODE_PRIVATE
        )
        return pref.getStringSet(
            FlutterDownloaderPlugin.TRUSTED_HTTPS_HOSTS_KEY,
            emptySet()
        )?.any { it.equals(host, ignoreCase = true) } == true
    }

    private fun createTrustHostCertificateSocketFactory(): javax.net.ssl.SSLSocketFactory {
        val trustManagers: Array<TrustManager> = arrayOf(
            @SuppressLint("CustomX509TrustManager")
            object : X509TrustManager {
                override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) = Unit
                override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) = Unit
                override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
            }
        )
        return SSLContext.getInstance("TLS").apply {
            init(null, trustManagers, SecureRandom())
        }.socketFactory
    }

    companion object {
        const val ARG_URL = "url"
        const val ARG_FILE_NAME = "file_name"
        const val ARG_SAVED_DIR = "saved_file"
        const val ARG_HEADERS = "headers"
        const val ARG_IS_RESUME = "is_resume"
        const val ARG_TIMEOUT = "timeout"
        const val ARG_SHOW_NOTIFICATION = "show_notification"
        const val ARG_OPEN_FILE_FROM_NOTIFICATION = "open_file_from_notification"
        const val ARG_CALLBACK_HANDLE = "callback_handle"
        const val ARG_DEBUG = "debug"
        const val ARG_STEP = "step"
        const val ARG_SAVE_IN_PUBLIC_STORAGE = "save_in_public_storage"
        const val ARG_IGNORESSL = "ignoreSsl"
        private val TAG = DownloadWorker::class.java.simpleName
        private const val BUFFER_SIZE = 4096
        private const val CHANNEL_ID = "FLUTTER_DOWNLOADER_NOTIFICATION"
        private val isolateStarted = AtomicBoolean(false)
        private val isolateQueue = ArrayDeque<List<Any>>()
        private var backgroundFlutterEngine: FlutterEngine? = null
    }

    init {
        Handler(context.mainLooper).post { startBackgroundIsolate(context) }
    }
}
