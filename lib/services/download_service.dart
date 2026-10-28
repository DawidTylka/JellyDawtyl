import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';

import '../models/jellyfin_item.dart';
import 'jellyfin_api.dart';
import 'storage_service.dart';

import 'downloaders/base_downloader.dart';
import 'downloaders/dio_downloader.dart';
import 'downloaders/native_downloader.dart';
import 'android_download_task_matcher.dart';
import 'download_task_queue.dart';

import 'dart:async';

class DownloadStatus {
  final double progressValue;
  final String progressText;
  final bool isDownloaded;
  final bool isQueued;
  final String? filePath;

  DownloadStatus({
    this.progressValue = 0.0,
    this.progressText = "",
    this.isDownloaded = false,
    this.isQueued = false,
    this.filePath,
  });
}

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  static Timer? _debounceTimer;
  static Timer? _backgroundSyncTimer;
  final StorageService _storage = StorageService();
  late final DownloadTaskQueue _downloadQueue = DownloadTaskQueue(
    onError: (itemId, error, _) {
      _updateProgress(
        itemId,
        progressText: 'Przygotowanie pobierania nie powiodło się',
      );
      debugPrint(
        'Zadanie kolejki pobierania nie powiodło się (${error.runtimeType}).',
      );
    },
  );
  final ValueNotifier<Map<String, DownloadStatus>> activeDownloads =
      ValueNotifier({});
  final ValueNotifier<List<Map<String, dynamic>>> failedDownloads =
      ValueNotifier([]);

  bool _backgroundInitialized = false;
  bool _isSyncingBackgroundDownloads = false;
  Map<String, Map<String, dynamic>> _backgroundTasks = {};
  Map<String, Map<String, dynamic>> _pendingMetadataPreparations = {};
  bool _failuresInitialized = false;
  final Set<String> _enqueueingItemIds = {};
  final Set<String> _preparingMetadataItemIds = {};

  Future<void> initialize() async {
    if (_failuresInitialized) return;
    _failuresInitialized = true;
    try {
      final encoded = await _storage.getString('failed_downloads_v1');
      if (encoded != null && encoded.isNotEmpty) {
        final decoded = jsonDecode(encoded) as List<dynamic>;
        failedDownloads.value = decoded
            .map((entry) => Map<String, dynamic>.from(entry as Map))
            .toList();
      }
    } catch (error) {
      debugPrint('Nie udało się odczytać nieudanych pobrań: $error');
    }
  }

  Future<void> _saveFailedDownloads() =>
      _persist('failed_downloads_v1', jsonEncode(failedDownloads.value));

  Future<void> _registerFailedDownload(
    String itemId,
    Map<String, dynamic> record,
  ) async {
    final failure = {...record, 'itemId': itemId};
    final updated = failedDownloads.value
        .where((entry) => entry['itemId'] != itemId)
        .toList();
    updated.add(failure);
    failedDownloads.value = updated;
    await _saveFailedDownloads();
  }

  Future<void> dismissFailedDownloads(Iterable<String> itemIds) async {
    final ids = itemIds.toSet();
    failedDownloads.value = failedDownloads.value
        .where((entry) => !ids.contains(entry['itemId']))
        .toList();
    await _saveFailedDownloads();
  }

  Future<void> retryFailedDownloads(Iterable<String> itemIds) async {
    await initialize();
    if (Platform.isAndroid) await initializeBackgroundDownloads();
    await updateConcurrencyLimit();
    final ids = itemIds.toSet();
    final selected = failedDownloads.value
        .where((entry) => ids.contains(entry['itemId']))
        .toList();
    await dismissFailedDownloads(ids);
    for (final record in selected) {
      final itemId = record['itemId'] as String;
      _updateProgress(itemId, progressText: 'Ponawianie pobierania...');
      try {
        if (Platform.isAndroid) {
          _enqueueingItemIds.add(itemId);
          _backgroundTasks[itemId] = {...record, 'taskId': null, 'attempts': 0};
          await _saveBackgroundTasks();
          final taskId = await FlutterDownloader.enqueue(
            url: record['url'] as String,
            headers: {'X-Emby-Token': record['token'] as String},
            savedDir: record['saveDir'] as String,
            fileName: record['fileName'] as String,
            showNotification: record['showNotification'] as bool? ?? false,
            openFileFromNotification: false,
            requiresStorageNotLow: true,
            allowCellular: record['allowCellular'] as bool? ?? false,
            timeout: 120000,
          );
          if (taskId == null) throw StateError('Android nie przyjął zadania.');
          _backgroundTasks[itemId] = {
            ...record,
            'taskId': taskId,
            'attempts': 0,
          };
          await _saveBackgroundTasks();
        } else {
          final downloader = DioDownloader();
          await _downloadQueue.enqueue(itemId, () async {
            await downloader.downloadVideo(
              itemId: itemId,
              downloadUrl: record['url'] as String,
              saveDir: record['saveDir'] as String,
              fileName: record['fileName'] as String,
              token: record['token'] as String,
              wifiOnly: !(record['allowCellular'] as bool? ?? false),
              showNotification: false,
              onProgress: (id, value, text) =>
                  _updateProgress(id, progressValue: value, progressText: text),
              onFinished: (id) => _finishDownload(
                id,
                '${record['saveDir']}/${record['fileName']}',
              ),
              onFailed: (id) => _registerFailedDownload(id, record),
            );
          });
        }
      } catch (error) {
        debugPrint(
          'Nie udało się ponowić pobierania $itemId (${error.runtimeType}).',
        );
        await _registerFailedDownload(itemId, record);
        _updateProgress(
          itemId,
          progressText: 'Nie udało się ponowić pobierania',
        );
      } finally {
        _enqueueingItemIds.remove(itemId);
      }
    }
  }

  Future<BaseDownloader> _getDownloaderInstance() async {
    if (Platform.isAndroid) {
      return NativeDownloader();
    } else {
      return DioDownloader();
    }
  }

  Future<void> initializeBackgroundDownloads() async {
    if (!Platform.isAndroid ||
        _backgroundInitialized ||
        (_backgroundSyncTimer?.isActive ?? false)) {
      return;
    }
    _backgroundInitialized = true;
    try {
      final encoded = await _storage.getString('background_downloads_v1');
      if (encoded != null && encoded.isNotEmpty) {
        final decoded = jsonDecode(encoded) as Map<String, dynamic>;
        _backgroundTasks = decoded.map(
          (id, value) => MapEntry(id, Map<String, dynamic>.from(value as Map)),
        );
      }
      final metadataEncoded = await _storage.getString(
        'background_metadata_preparations_v1',
      );
      if (metadataEncoded != null && metadataEncoded.isNotEmpty) {
        final decoded = jsonDecode(metadataEncoded) as Map<String, dynamic>;
        _pendingMetadataPreparations = decoded.map(
          (id, value) => MapEntry(id, Map<String, dynamic>.from(value as Map)),
        );
      }
      await updateConcurrencyLimit();
      await _syncBackgroundDownloads();
      unawaited(_processPendingMetadataPreparations());
      _backgroundSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        unawaited(_syncBackgroundDownloads());
        unawaited(_processPendingMetadataPreparations());
      });
    } catch (e) {
      debugPrint('Nie udało się odtworzyć pobrań w tle (${e.runtimeType}).');
      _backgroundInitialized = false;
    }
  }

  Future<void> _persistenceTail = Future<void>.value();

  Future<void> _persist(String key, String value) {
    final write = _persistenceTail.then((_) => _storage.saveString(key, value));
    _persistenceTail = write.catchError((Object _) {});
    return write;
  }

  Future<void> _saveBackgroundTasks() async {
    await _persist('background_downloads_v1', jsonEncode(_backgroundTasks));
  }

  Future<void> _savePendingMetadataPreparations() async {
    await _persist(
      'background_metadata_preparations_v1',
      jsonEncode(_pendingMetadataPreparations),
    );
  }

  Future<void> _processPendingMetadataPreparations() async {
    if (!Platform.isAndroid || !FlutterDownloader.initialized) return;
    for (final entry in _pendingMetadataPreparations.entries.toList()) {
      final itemId = entry.key;
      if (_enqueueingItemIds.contains(itemId)) continue;
      if (!_preparingMetadataItemIds.add(itemId)) continue;
      try {
        final preparation = entry.value;
        final retryAt = preparation['retryAt'] as int? ?? 0;
        if (retryAt > DateTime.now().millisecondsSinceEpoch) continue;
        await _downloadJsonMetadata(
          itemId: itemId,
          baseUrl: preparation['baseUrl'] as String,
          token: preparation['token'] as String,
          userId: preparation['userId'] as String,
          seriesId: preparation['seriesId'] as String?,
          seriesDir: Directory(preparation['seriesDir'] as String),
          fileName: preparation['fileName'] as String,
        );
        _pendingMetadataPreparations.remove(itemId);
        await _savePendingMetadataPreparations();
      } catch (error) {
        final preparation = _pendingMetadataPreparations[itemId];
        if (preparation != null) {
          final attempts = (preparation['attempts'] as int? ?? 0) + 1;
          final delaySeconds = (15 * (1 << (attempts - 1).clamp(0, 5))).clamp(
            15,
            480,
          );
          preparation['attempts'] = attempts;
          preparation['retryAt'] = DateTime.now()
              .add(Duration(seconds: delaySeconds))
              .millisecondsSinceEpoch;
          await _savePendingMetadataPreparations();
        }
        debugPrint(
          'Przygotowanie metadanych $itemId nie powiodło się (${error.runtimeType}); ponowię przy następnym sprawdzeniu.',
        );
      } finally {
        _preparingMetadataItemIds.remove(itemId);
      }
    }
  }

  AndroidDownloadTaskSnapshot _snapshotAndroidTask(dynamic task) {
    final state = switch (task.status as DownloadTaskStatus) {
      DownloadTaskStatus.enqueued => AndroidDownloadTaskState.enqueued,
      DownloadTaskStatus.running => AndroidDownloadTaskState.running,
      DownloadTaskStatus.paused => AndroidDownloadTaskState.paused,
      DownloadTaskStatus.complete => AndroidDownloadTaskState.complete,
      DownloadTaskStatus.failed => AndroidDownloadTaskState.failed,
      DownloadTaskStatus.canceled => AndroidDownloadTaskState.canceled,
      _ => AndroidDownloadTaskState.other,
    };
    return AndroidDownloadTaskSnapshot(
      taskId: task.taskId as String,
      savedDir: task.savedDir as String,
      fileName: task.filename as String,
      url: task.url as String,
      createdAt: task.timeCreated as int,
      state: state,
    );
  }

  Future<void> _syncBackgroundDownloads() async {
    if (!Platform.isAndroid ||
        !FlutterDownloader.initialized ||
        _isSyncingBackgroundDownloads) {
      return;
    }
    _isSyncingBackgroundDownloads = true;
    try {
      final tasks = await FlutterDownloader.loadTasks();
      if (tasks == null) return;
      final snapshots = tasks.map(_snapshotAndroidTask).toList();

      for (final entry in _backgroundTasks.entries.toList()) {
        final itemId = entry.key;
        if (_enqueueingItemIds.contains(itemId)) continue;
        final record = entry.value;
        final taskId = record['taskId'] as String?;
        // Recover when Android accepted the job but the process died before
        // its task ID was saved. Prefer the newest active matching task.
        final matchedSnapshot = findAndroidDownloadTask(
          tasks: snapshots,
          taskId: taskId,
          savedDir: record['saveDir'] as String,
          fileName: record['fileName'] as String,
          url: record['url'] as String,
        );
        final task = matchedSnapshot == null
            ? null
            : tasks.firstWhere(
                (candidate) => candidate.taskId == matchedSnapshot.taskId,
              );

        if (task == null) {
          final missingSince = record['missingTaskSince'] as int?;
          final now = DateTime.now().millisecondsSinceEpoch;
          if (taskId != null &&
              missingSince != null &&
              now - missingSince < const Duration(seconds: 30).inMilliseconds) {
            continue;
          }
          record['missingTaskSince'] = now;
          await _saveBackgroundTasks();
          _enqueueingItemIds.add(itemId);
          try {
            final newTaskId = await FlutterDownloader.enqueue(
              url: record['url'] as String,
              headers: {'X-Emby-Token': record['token'] as String},
              savedDir: record['saveDir'] as String,
              fileName: record['fileName'] as String,
              showNotification: record['showNotification'] as bool? ?? false,
              openFileFromNotification: false,
              requiresStorageNotLow: true,
              allowCellular: record['allowCellular'] as bool? ?? false,
              timeout: 120000,
            );
            if (newTaskId == null) {
              _updateProgress(
                itemId,
                isQueued: true,
                progressText: 'Oczekiwanie na ponowienie...',
              );
            } else {
              record['taskId'] = newTaskId;
              record.remove('missingTaskSince');
              await _saveBackgroundTasks();
            }
          } catch (error) {
            debugPrint(
              'Nie udało się odtworzyć zadania Android (${error.runtimeType}).',
            );
            _updateProgress(
              itemId,
              isQueued: true,
              progressText: 'Oczekiwanie na ponowienie...',
            );
          } finally {
            _enqueueingItemIds.remove(itemId);
          }
          continue;
        }

        record['taskId'] = task.taskId;
        record.remove('missingTaskSince');
        final fullPath = '${task.savedDir}/${task.filename}';
        if (task.status == DownloadTaskStatus.complete) {
          if (!await File(fullPath).exists() ||
              await File(fullPath).length() == 0) {
            // A completed database row is insufficient if the user removed the file.
            record['taskId'] = null;
            await FlutterDownloader.remove(
              taskId: task.taskId,
              shouldDeleteContent: false,
            );
            await _saveBackgroundTasks();
            continue;
          }
          if (_pendingMetadataPreparations.containsKey(itemId)) {
            _updateProgress(
              itemId,
              progressValue: 1,
              progressText: 'Przygotowanie metadanych i napisów...',
            );
            continue;
          }
          _finishDownload(itemId, fullPath);
          _backgroundTasks.remove(itemId);
          await _saveBackgroundTasks();
        } else if (task.status == DownloadTaskStatus.failed ||
            task.status == DownloadTaskStatus.canceled) {
          final duplicateActiveTask = tasks
              .where(
                (candidate) =>
                    candidate.taskId != task.taskId &&
                    findAndroidDownloadTask(
                          tasks: [_snapshotAndroidTask(candidate)],
                          taskId: null,
                          savedDir: record['saveDir'] as String,
                          fileName: record['fileName'] as String,
                          url: record['url'] as String,
                          includeInactiveFallback: false,
                        ) !=
                        null &&
                    (candidate.status == DownloadTaskStatus.enqueued ||
                        candidate.status == DownloadTaskStatus.running ||
                        candidate.status == DownloadTaskStatus.paused),
              )
              .firstOrNull;
          if (duplicateActiveTask != null) {
            record['taskId'] = duplicateActiveTask.taskId;
            await _saveBackgroundTasks();
            continue;
          }

          final attempts = (record['attempts'] as int? ?? 0) + 1;
          if (attempts < 4) {
            record['attempts'] = attempts;
            final newTaskId = await FlutterDownloader.retry(
              taskId: task.taskId,
              timeout: 120000,
            );
            if (newTaskId != null) {
              record['taskId'] = newTaskId;
              await _saveBackgroundTasks();
            } else {
              _failBackgroundDownload(itemId, record);
              _backgroundTasks.remove(itemId);
              await _saveBackgroundTasks();
            }
          } else {
            _failBackgroundDownload(itemId, record);
            _backgroundTasks.remove(itemId);
            await _saveBackgroundTasks();
          }
        } else if (task.status == DownloadTaskStatus.paused) {
          final resumedTaskId = await FlutterDownloader.resume(
            taskId: task.taskId,
            timeout: 120000,
          );
          if (resumedTaskId != null) record['taskId'] = resumedTaskId;
          await _saveBackgroundTasks();
        } else {
          final percent = task.progress.clamp(0, 100).toInt();
          final progress = task.progress < 0 ? -1.0 : percent / 100.0;
          _updateProgress(
            itemId,
            progressValue: progress,
            progressText: task.progress < 0 || percent == 0
                ? 'Pobieranie w tle...'
                : '$percent%',
            isQueued: task.status == DownloadTaskStatus.enqueued,
          );
        }
      }
    } finally {
      _isSyncingBackgroundDownloads = false;
    }
  }

  void _failBackgroundDownload(String itemId, Map<String, dynamic> record) {
    final fullPath = '${record['saveDir']}/${record['fileName']}';
    final partial = File(fullPath);
    if (partial.existsSync()) {
      try {
        partial.deleteSync();
      } catch (_) {}
    }
    _updateProgress(
      itemId,
      progressValue: 0,
      progressText: 'Pobieranie nie powiodło się — spróbuj ponownie',
    );
    unawaited(_registerFailedDownload(itemId, record));
  }

  Future<void> updateConcurrencyLimit() async {
    final limit = await _storage.getInt(
      'setting_max_concurrent_downloads',
      defaultValue: 1,
    );
    _downloadQueue.maxConcurrent = limit;
    if (Platform.isAndroid && FlutterDownloader.initialized) {
      await FlutterDownloader.setMaxConcurrentDownloads(limit);
    }
  }

  void _processQueue() async {
    try {
      _downloadQueue.maxConcurrent = await _storage.getInt(
        'setting_max_concurrent_downloads',
        defaultValue: 1,
      );
    } catch (e) {
      debugPrint('Błąd kolejki pobierania (${e.runtimeType}).');
    }
  }

  Future<String> getDirectoryPath() async {
    final customPath = await _storage.getString('setting_download_path');

    if (customPath != null && customPath.isNotEmpty) {
      return "$customPath/JellyDawtyl";
    }

    if (Platform.isAndroid) {
      return "/storage/emulated/0/Download/JellyDawtyl";
    } else if (Platform.isWindows) {
      final directory = await getApplicationSupportDirectory();
      return "${directory.path}\\JellyDawtyl";
    }

    return "";
  }

  Future<DownloadStatus> checkStatus(
    String uniqueId,
    String relativePath,
  ) async {
    final active = activeDownloads.value[uniqueId];
    if (active != null) return active;
    if (_backgroundTasks.containsKey(uniqueId)) {
      return DownloadStatus(
        isQueued: true,
        progressText: 'Oczekiwanie na pobieranie...',
      );
    }
    String dirPath = await getDirectoryPath();
    if (dirPath.isEmpty) return DownloadStatus();

    String fullPath = "$dirPath/$relativePath";
    if (File(fullPath).existsSync() && File(fullPath).lengthSync() > 0) {
      return DownloadStatus(isDownloaded: true, filePath: fullPath);
    }
    return activeDownloads.value[uniqueId] ?? DownloadStatus();
  }

  Map<String, String> _generatePaths(
    JellyfinItem item,
    String? seriesOverrideName,
    String qualityLabel,
  ) {
    final bool isEpisode = item.type == "Episode";
    String folderBaseName =
        seriesOverrideName ??
        (isEpisode ? (item.seriesName ?? item.name) : item.name);
    String safeFolder = folderBaseName.replaceAll(RegExp(r'[^\w\s]+'), '');
    String fileName = isEpisode
        ? "${safeFolder}_S${item.parentIndexNumber.toString().padLeft(3, '0')}E${item.indexNumber.toString().padLeft(3, '0')}_$qualityLabel.mp4"
        : "${safeFolder}_$qualityLabel.mp4";
    return {"folder": safeFolder, "file": fileName};
  }

  Future<void> startDownload({
    required JellyfinItem item,
    required String baseUrl,
    required String token,
    int? maxWidth,
    int? bitrate,
    required String qualityLabel,
    String? seriesOverrideName,
  }) async {
    if (Platform.isAndroid) await initializeBackgroundDownloads();
    await updateConcurrencyLimit();
    final String itemId = item.id;
    if (activeDownloads.value.containsKey(itemId)) return;

    _updateProgress(
      itemId,
      progressValue: 0.0,
      progressText: "Oczekiwanie...",
      isQueued: true,
    );
    Future<void> downloadTask() async {
      String? finalSeriesName = seriesOverrideName;
      if (item.type == "Episode" &&
          finalSeriesName == null &&
          !Platform.isAndroid) {
        finalSeriesName = item.seriesName;
        if (finalSeriesName == null && item.seriesId != null) {
          _updateProgress(itemId, progressValue: 0.0, progressText: "Dane...");
          finalSeriesName = await JellyfinApi().fetchSeriesName(
            baseUrl,
            token,
            item.seriesId!,
          );
        }
      }

      final String baseDir = await getDirectoryPath();
      if (baseDir.isEmpty) return;

      final paths = _generatePaths(item, finalSeriesName, qualityLabel);
      final String safeFolderName = paths["folder"]!;
      final String fileName = paths["file"]!;

      Directory seriesDir = Directory('$baseDir/$safeFolderName');
      if (!seriesDir.existsSync()) seriesDir.createSync(recursive: true);

      final targetFile = File('${seriesDir.path}/$fileName');
      if (!_backgroundTasks.containsKey(itemId) &&
          await targetFile.exists() &&
          await targetFile.length() > 0) {
        _finishDownload(itemId, targetFile.path);
        return;
      }

      final storage = StorageService();
      final hwAccel = await storage.getString('setting_hw_accel') ?? 'auto';
      final cpuLimit = await storage.getString('setting_cpu_limit') ?? 'auto';
      final maxFps = await storage.getString('setting_max_fps') ?? 'auto';
      final audioBitrate =
          await storage.getString('setting_audio_bitrate') ?? 'auto';

      final downloadQuery = <String, String>{
        'Static': qualityLabel == 'original' ? 'true' : 'false',
      };
      if (qualityLabel != 'original') {
        downloadQuery.addAll({
          'VideoCodec': 'h264',
          'AudioCodec': 'aac,mp3',
          'MaxAudioChannels': '2',
          'EnableSubtitlesInManifest': 'false',
          'PlaySessionId': '${DateTime.now().millisecondsSinceEpoch}',
        });
        if (maxWidth != null) downloadQuery['MaxWidth'] = '$maxWidth';
        if (bitrate != null) downloadQuery['VideoBitrate'] = '$bitrate';
        if (hwAccel != 'auto') downloadQuery['TranscodingMaxType'] = hwAccel;
        if (cpuLimit != 'auto') downloadQuery['CpuCoreLimit'] = cpuLimit;
        if (maxFps != 'auto') downloadQuery['MaxFramerate'] = maxFps;
        if (audioBitrate != 'auto') {
          downloadQuery['AudioBitrate'] = audioBitrate;
        }
      }
      final downloadUrl = Uri.parse(
        '$baseUrl/Videos/$itemId/stream.mp4',
      ).replace(queryParameters: downloadQuery).toString();

      BaseDownloader downloader = await _getDownloaderInstance();

      bool wifiOnly = await _storage.getSetting(
        'setting_wifionly',
        defaultValue: true,
      );

      final showNotification = await _storage.getSetting(
        'setting_native_downloader',
        defaultValue: false,
      );
      if (Platform.isAndroid) {
        _pendingMetadataPreparations[itemId] = {
          'baseUrl': baseUrl,
          'token': token,
          'userId': await _storage.getString('userId') ?? '',
          'seriesId': item.seriesId,
          'seriesDir': seriesDir.path,
          'fileName': fileName,
        };
        await _savePendingMetadataPreparations();
        _enqueueingItemIds.add(itemId);
        _backgroundTasks[itemId] = {
          'taskId': null,
          'saveDir': seriesDir.path,
          'fileName': fileName,
          'url': downloadUrl,
          'token': token,
          'allowCellular': !wifiOnly,
          'showNotification': showNotification,
          'attempts': 0,
        };
        // Persist the request before enqueueing. Startup reconciliation can
        // submit it if Android killed the process between these two steps.
        await _saveBackgroundTasks();
      } else {
        await _downloadJsonMetadata(
          itemId: itemId,
          baseUrl: baseUrl,
          token: token,
          userId: await _storage.getString('userId') ?? '',
          seriesId: item.seriesId,
          seriesDir: seriesDir,
          fileName: fileName,
        );
        await _downloadMetadataImages(
          item,
          baseUrl,
          token,
          seriesDir,
          fileName,
        );
      }

      String? taskId;
      try {
        taskId = await downloader.downloadVideo(
          itemId: itemId,
          downloadUrl: downloadUrl,
          saveDir: seriesDir.path,
          fileName: fileName,
          token: token,
          wifiOnly: wifiOnly,
          showNotification: showNotification,
          onProgress: (id, val, text) =>
              _updateProgress(id, progressValue: val, progressText: text),
          onFinished: (id) =>
              _finishDownload(id, "${seriesDir.path}/$fileName"),
          onFailed: (id) => _registerFailedDownload(id, {
            'taskId': null,
            'saveDir': seriesDir.path,
            'fileName': fileName,
            'url': downloadUrl,
            'token': token,
            'allowCellular': !wifiOnly,
            'showNotification': showNotification,
            'attempts': 0,
          }),
        );
      } finally {
        _enqueueingItemIds.remove(itemId);
      }

      if (Platform.isAndroid) {
        final record = _backgroundTasks[itemId];
        if (record != null && taskId != null) {
          record['taskId'] = taskId;
          await _saveBackgroundTasks();
        }
        unawaited(initializeBackgroundDownloads());
        unawaited(_processPendingMetadataPreparations());
        unawaited(
          _downloadMetadataImages(
            item,
            baseUrl,
            token,
            seriesDir,
            fileName,
          ).catchError((Object error) {
            debugPrint(
              'Nie udało się pobrać grafik odcinka (${error.runtimeType}).',
            );
          }),
        );
      } else {
        await _downloadMetadataImages(
          item,
          baseUrl,
          token,
          seriesDir,
          fileName,
        );
      }
    }

    if (Platform.isAndroid) {
      await _downloadQueue.enqueue(itemId, () async {
        try {
          await downloadTask();
        } catch (error) {
          debugPrint(
            'Błąd przygotowania pobierania Android (${error.runtimeType}).',
          );
          if (_backgroundTasks.containsKey(itemId)) {
            unawaited(initializeBackgroundDownloads());
          } else {
            final updated = Map<String, DownloadStatus>.from(
              activeDownloads.value,
            )..remove(itemId);
            activeDownloads.value = updated;
          }
          if (_backgroundTasks.containsKey(itemId)) {
            _updateProgress(
              itemId,
              isQueued: true,
              progressText: 'Oczekiwanie na ponowienie...',
            );
          }
        }
      });
    } else {
      unawaited(_downloadQueue.enqueue(itemId, downloadTask));
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 150), () {
        _processQueue();
      });
    }
  }

  void _updateProgress(
    String id, {
    double progressValue = 0.0,
    String progressText = "",
    bool isQueued = false,
  }) {
    final normalizedProgress = progressValue < 0
        ? -1.0
        : (progressValue > 1 ? progressValue / 100 : progressValue)
              .clamp(0.0, 1.0)
              .toDouble();
    var newMap = Map<String, DownloadStatus>.from(activeDownloads.value);
    newMap[id] = DownloadStatus(
      progressValue: normalizedProgress,
      progressText: progressText,
      isQueued: isQueued,
    );
    activeDownloads.value = newMap;
  }

  void _finishDownload(String id, String fullPath) {
    var newMap = Map<String, DownloadStatus>.from(activeDownloads.value);
    newMap[id] = DownloadStatus(isDownloaded: true, filePath: fullPath);
    activeDownloads.value = newMap;
    Future.delayed(const Duration(seconds: 1), () {
      var finalMap = Map<String, DownloadStatus>.from(activeDownloads.value);
      finalMap.remove(id);
      activeDownloads.value = finalMap;
    });
  }

  Future<void> _downloadMetadataImages(
    JellyfinItem item,
    String baseUrl,
    String token,
    Directory seriesDir,
    String fileName,
  ) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    String coverUrl =
        "$baseUrl/Items/${item.seriesId ?? item.id}/Images/Primary?fillWidth=400&quality=90";

    File coverFile = File('${seriesDir.path}/folder.jpg');
    if (!coverFile.existsSync()) {
      try {
        await dio.download(
          coverUrl,
          coverFile.path,
          options: Options(headers: {"X-Emby-Token": token}),
        );
        if (coverFile.existsSync() && coverFile.lengthSync() < 500) {
          coverFile.deleteSync();
        }
      } catch (_) {
        if (coverFile.existsSync()) coverFile.deleteSync();
      }
    }

    String thumbUrl =
        "$baseUrl/Items/${item.id}/Images/Primary?fillWidth=400&quality=90";
    String thumbFileName = fileName.replaceAll('.mp4', '.jpg');
    File thumbFile = File('${seriesDir.path}/$thumbFileName');

    if (!thumbFile.existsSync()) {
      try {
        await dio.download(
          thumbUrl,
          thumbFile.path,
          options: Options(headers: {"X-Emby-Token": token}),
        );
        if (thumbFile.existsSync() && thumbFile.lengthSync() < 500) {
          thumbFile.deleteSync();
        }
      } catch (_) {
        if (thumbFile.existsSync()) thumbFile.deleteSync();
      }
    }
  }

  Future<void> _downloadJsonMetadata({
    required String itemId,
    required String baseUrl,
    required String token,
    required String userId,
    required String? seriesId,
    required Directory seriesDir,
    required String fileName,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    Future<Map<String, dynamic>?> fetchItem(String id) async {
      try {
        final response = await dio.get(
          '$baseUrl/Users/$userId/Items/$id',
          options: Options(headers: {'X-Emby-Token': token}),
        );
        if (response.data is Map) {
          return Map<String, dynamic>.from(response.data as Map);
        }
      } catch (e) {
        debugPrint('Nie udało się pobrać metadanych $id (${e.runtimeType}).');
      }
      return null;
    }

    final itemMetadata = await fetchItem(itemId);
    if (itemMetadata == null) {
      throw StateError('Nie udało się pobrać metadanych odcinka.');
    }
    final downloadedSubtitles = await _downloadAllSubtitles(
      itemId: itemId,
      baseUrl: baseUrl,
      token: token,
      seriesDir: seriesDir,
      videoFileName: fileName,
    );
    itemMetadata['DownloadedSubtitles'] = downloadedSubtitles;
    await File(
      '${seriesDir.path}/$fileName.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(itemMetadata));
    if (seriesId != null && seriesId.isNotEmpty) {
      final seriesMetadata = await fetchItem(seriesId);
      if (seriesMetadata == null) {
        throw StateError('Nie udało się pobrać metadanych serialu.');
      }
      await File('${seriesDir.path}/series.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert(seriesMetadata),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _downloadAllSubtitles({
    required String itemId,
    required String baseUrl,
    required String token,
    required Directory seriesDir,
    required String videoFileName,
  }) async {
    final streams = await JellyfinApi().fetchSubtitleStreams(
      baseUrl,
      token,
      itemId,
    );
    if (streams.isEmpty) return [];

    final videoStem = videoFileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final subtitleDir = Directory('${seriesDir.path}/$videoStem.subtitles');
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    final downloaded = <Map<String, dynamic>>[];
    final usedPaths = <String>{};
    const textCodecs = {
      'srt',
      'subrip',
      'ass',
      'ssa',
      'vtt',
      'webvtt',
      'sami',
      'smi',
      'ttml',
      'dfxp',
      'mov_text',
      'tx3g',
    };

    for (final stream in streams) {
      final index = stream['Index'];
      if (index is! num) continue;
      final isText = stream['IsTextSubtitleStream'];
      final codec = (stream['Codec'] ?? stream['Format'] ?? 'srt')
          .toString()
          .toLowerCase();
      if (isText == false || !textCodecs.contains(codec)) continue;

      final displayTitle = (stream['DisplayTitle'] ?? stream['Title'] ?? '')
          .toString()
          .trim();
      final language = (stream['Language'] ?? '').toString().trim();
      final originalName = displayTitle.isNotEmpty
          ? displayTitle
          : (language.isNotEmpty ? language : 'Napisy');
      final safeName = originalName
          .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final extension = codec == 'subrip'
          ? 'srt'
          : (codec == 'webvtt'
                ? 'vtt'
                : (codec == 'mov_text' || codec == 'tx3g' ? 'srt' : codec));
      var subtitleName = '$safeName.$extension';
      if (!usedPaths.add(subtitleName.toLowerCase())) {
        subtitleName = '${safeName}_${index.toInt()}.$extension';
        usedPaths.add(subtitleName.toLowerCase());
      }
      final file = File('${subtitleDir.path}/$subtitleName');
      final subtitleJobs = Platform.isAndroid
          ? await FlutterDownloader.loadTasks() ?? []
          : null;
      final previousJobs =
          subtitleJobs
              ?.where(
                (job) =>
                    job.savedDir == subtitleDir.path &&
                    job.filename == subtitleName,
              )
              .toList()
            ?..sort((a, b) => b.timeCreated.compareTo(a.timeCreated));
      final verifiedSubtitle =
          !Platform.isAndroid ||
          previousJobs == null ||
          previousJobs.isEmpty ||
          previousJobs.first.status == DownloadTaskStatus.complete;
      if (verifiedSubtitle && await file.exists() && await file.length() > 0) {
        downloaded.add(
          _subtitleJsonEntry(stream, index.toInt(), seriesDir, file),
        );
        continue;
      }
      if (!Platform.isAndroid && await file.exists()) await file.delete();

      try {
        await subtitleDir.create(recursive: true);
        final uri = Uri.parse(
          '$baseUrl/Videos/$itemId/$itemId/Subtitles/${index.toInt()}/0/Stream.$extension',
        );
        if (Platform.isAndroid) {
          final tasks = await FlutterDownloader.loadTasks() ?? [];
          final activeTask = tasks.where((task) {
            final active =
                task.status == DownloadTaskStatus.enqueued ||
                task.status == DownloadTaskStatus.running ||
                task.status == DownloadTaskStatus.paused;
            return active &&
                task.savedDir == subtitleDir.path &&
                task.filename == subtitleName &&
                task.url.split('?').first == uri.toString();
          }).firstOrNull;
          if (activeTask == null) {
            final wifiOnly = await _storage.getSetting(
              'setting_wifionly',
              defaultValue: true,
            );
            final taskId = await FlutterDownloader.enqueue(
              url: uri.toString(),
              headers: {'X-Emby-Token': token},
              savedDir: subtitleDir.path,
              fileName: subtitleName,
              showNotification: false,
              openFileFromNotification: false,
              requiresStorageNotLow: true,
              allowCellular: !wifiOnly,
              timeout: 120000,
            );
            if (taskId == null) {
              throw StateError(
                'Android nie przyjął zadania pobierania napisów.',
              );
            }
          }
          while (true) {
            final jobs = await FlutterDownloader.loadTasks() ?? [];
            final matching =
                jobs
                    .where(
                      (job) =>
                          job.savedDir == subtitleDir.path &&
                          job.filename == subtitleName,
                    )
                    .toList()
                  ..sort((a, b) => b.timeCreated.compareTo(a.timeCreated));
            if (matching.isEmpty) throw StateError('Brak zadania napisów.');
            final job = matching.first;
            if (job.status == DownloadTaskStatus.complete &&
                await file.exists() &&
                await file.length() > 0) {
              break;
            }
            if (job.status == DownloadTaskStatus.complete ||
                job.status == DownloadTaskStatus.failed ||
                job.status == DownloadTaskStatus.canceled) {
              throw StateError('Nie udało się pobrać napisów.');
            }
            await Future<void>.delayed(const Duration(seconds: 2));
          }
        } else {
          final tempFile = File('${file.path}.part');
          await dio.download(
            uri.toString(),
            tempFile.path,
            options: Options(headers: {'X-Emby-Token': token}),
          );
          if (await tempFile.length() == 0) {
            await tempFile.delete();
            continue;
          }
          if (!Platform.isAndroid && await file.exists()) await file.delete();
          await tempFile.rename(file.path);
        }
        downloaded.add(
          _subtitleJsonEntry(stream, index.toInt(), seriesDir, file),
        );
      } catch (error) {
        debugPrint(
          'Nie udało się pobrać napisów $itemId/$index (${error.runtimeType}).',
        );
        if (Platform.isAndroid) rethrow;
        final partial = File('${file.path}.part');
        if (await partial.exists()) await partial.delete();
      }
    }
    return downloaded;
  }

  Map<String, dynamic> _subtitleJsonEntry(
    Map<String, dynamic> stream,
    int index,
    Directory seriesDir,
    File file,
  ) {
    final relativePath = file.path
        .substring(seriesDir.path.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
    return {
      'Index': index,
      'Language': stream['Language'],
      'DisplayTitle': stream['DisplayTitle'] ?? stream['Title'],
      'Codec': stream['Codec'] ?? stream['Format'],
      'Path': relativePath,
      'FileName': file.uri.pathSegments.last,
    };
  }

  Future<String?> findLocalFile(
    dynamic item, {
    String? seriesOverrideName,
  }) async {
    const qualities = ["original", "1080p", "720p", "480p", "360p", "144p"];
    for (String q in qualities) {
      final paths = _generatePaths(item, seriesOverrideName, q);
      final status = await checkStatus(
        item.id,
        "${paths["folder"]}/${paths["file"]}",
      );
      if (status.isDownloaded && status.filePath != null) {
        return status.filePath;
      }
    }
    return null;
  }

  static List<Map<String, dynamic>> getQualityOptions(
    Map<String, dynamic>? mediaInfo,
  ) {
    final qualities = [
      {
        "label": "Oryginalna",
        "icon": Icons.star,
        "color": Colors.greenAccent,
        "width": null,
        "height": null,
        "qualityLabel": "original",
      },
      {
        "label": "1080p (Full HD)",
        "icon": Icons.hd,
        "color": Colors.blueAccent,
        "width": 1920,
        "height": 1080,
        "qualityLabel": "1080p",
      },
      {
        "label": "720p (HD)",
        "icon": Icons.high_quality,
        "color": Colors.lightBlueAccent,
        "width": 1280,
        "height": 720,
        "qualityLabel": "720p",
      },
      {
        "label": "480p (SD)",
        "icon": Icons.sd,
        "color": Colors.orangeAccent,
        "width": 854,
        "height": 480,
        "qualityLabel": "480p",
      },
      {
        "label": "144p (Bardzo niska)",
        "icon": Icons.speed,
        "color": Colors.redAccent,
        "width": 256,
        "height": 144,
        "qualityLabel": "144p",
      },
    ];

    if (mediaInfo != null) {
      final originalWidth = mediaInfo['Width'] as int?;
      final originalHeight = mediaInfo['Height'] as int?;
      final originalBitrate = mediaInfo['Bitrate'] as int?;
      final bool hasSourceInfo =
          originalWidth != null && originalHeight != null;

      final filteredQualities = <Map<String, dynamic>>[];

      for (final quality in qualities) {
        final width = quality['width'] as int?;
        final height = quality['height'] as int?;
        int? bitrate = quality['bitrate'] as int?;

        if (width != null && height != null && hasSourceInfo) {
          if (originalWidth <= width || originalHeight <= height) continue;
        }

        if (width != null &&
            height != null &&
            hasSourceInfo &&
            originalBitrate != null) {
          final ratio = (width * height) / (originalWidth * originalHeight);
          bitrate = (originalBitrate * ratio).round();
          if (bitrate > originalBitrate) bitrate = originalBitrate;
        }
        filteredQualities.add({...quality, 'bitrate': bitrate});
      }
      return filteredQualities;
    } else {
      return qualities
          .map((q) => {...q, 'bitrate': q['bitrate'] as int?})
          .toList();
    }
  }
}
