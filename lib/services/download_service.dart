import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';

import '../models/jellyfin_item.dart';
import '../utils/server_url.dart';
import 'jellyfin_api.dart';
import 'storage_service.dart';

import 'downloaders/base_downloader.dart';
import 'downloaders/dio_downloader.dart';
import 'downloaders/native_downloader.dart';
import 'android_download_task_matcher.dart';
import 'download_task_queue.dart';

import 'dart:async';
import '../utils/jellyfin_auth.dart';

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

  /// Display names of items in [activeDownloads], for the downloads screen.
  final Map<String, String> downloadTitles = {};
  final ValueNotifier<List<Map<String, dynamic>>> failedDownloads =
      ValueNotifier([]);

  bool _backgroundInitialized = false;
  bool _isSyncingBackgroundDownloads = false;
  Map<String, Map<String, dynamic>> _backgroundTasks = {};
  Map<String, Map<String, dynamic>> _pendingMetadataPreparations = {};
  bool _failuresInitialized = false;
  final Set<String> _enqueueingItemIds = {};
  final Set<String> _preparingMetadataItemIds = {};
  // Cancellation state. Desktop transfers stop through their CancelToken;
  // Android tasks created by a request that was in flight while the user
  // cancelled are swept by the next background sync.
  final Set<String> _cancelledItemIds = {};
  final Map<String, int> _cancelGenerations = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, String> _desktopTargets = {};
  final Map<String, Map<String, dynamic>> _cancelledAndroidTargets = {};

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

  static String? _recordPath(Map<String, dynamic>? record) {
    final dir = record?['saveDir'];
    final name = record?['fileName'];
    return dir is String && name is String ? '$dir/$name' : null;
  }

  Future<void> _registerFailedDownload(
    String itemId,
    Map<String, dynamic> record,
  ) async {
    await _restoreSetAsideCopy(_recordPath(record));
    // A download the user cancelled is not a failure to offer for retry.
    if (_cancelledItemIds.contains(itemId)) return;
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
      _cancelledItemIds.remove(itemId);
      final generation = _cancelGenerations[itemId] ?? 0;
      bool cancelled() => (_cancelGenerations[itemId] ?? 0) != generation;
      _updateProgress(itemId, progressText: 'Ponawianie pobierania...');
      try {
        if (Platform.isAndroid) {
          _enqueueingItemIds.add(itemId);
          _backgroundTasks[itemId] = {...record, 'taskId': null, 'attempts': 0};
          await _saveBackgroundTasks();
          final taskId = await FlutterDownloader.enqueue(
            url: record['url'] as String,
            headers: jellyfinAuthHeaders(record['token'] as String),
            savedDir: record['saveDir'] as String,
            fileName: record['fileName'] as String,
            showNotification: record['showNotification'] as bool? ?? false,
            openFileFromNotification: false,
            requiresStorageNotLow: true,
            allowCellular: record['allowCellular'] as bool? ?? false,
            timeout: 120000,
          );
          if (taskId == null) throw StateError('Android nie przyjął zadania.');
          if (cancelled()) {
            await _cancelAndroidTask(taskId);
            continue;
          }
          _backgroundTasks[itemId] = {
            ...record,
            'taskId': taskId,
            'attempts': 0,
          };
          await _saveBackgroundTasks();
        } else {
          // Not awaited: the queue runs as many transfers as the limit allows
          // instead of retrying one file at a time.
          unawaited(
            _downloadQueue.enqueue(itemId, () async {
              if (cancelled()) return;
              final cancelToken = CancelToken();
              _cancelTokens[itemId] = cancelToken;
              _desktopTargets[itemId] =
                  '${record['saveDir']}/${record['fileName']}';
              final downloader = DioDownloader(cancelToken: cancelToken);
              try {
                await downloader.downloadVideo(
                  itemId: itemId,
                  downloadUrl: record['url'] as String,
                  saveDir: record['saveDir'] as String,
                  fileName: record['fileName'] as String,
                  token: record['token'] as String,
                  wifiOnly: !(record['allowCellular'] as bool? ?? false),
                  showNotification: false,
                  onProgress: (id, value, text) {
                    if (cancelled()) return;
                    _updateProgress(
                      id,
                      progressValue: value,
                      progressText: text,
                    );
                  },
                  onFinished: (id) => _finishDownload(
                    id,
                    '${record['saveDir']}/${record['fileName']}',
                  ),
                  onFailed: (id) => _registerFailedDownload(id, record),
                );
              } finally {
                _releaseCancelToken(itemId, cancelToken);
              }
            }),
          );
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

  Future<BaseDownloader> _getDownloaderInstance({
    CancelToken? cancelToken,
  }) async {
    if (Platform.isAndroid) {
      return NativeDownloader();
    } else {
      return DioDownloader(cancelToken: cancelToken);
    }
  }

  void _releaseCancelToken(String itemId, CancelToken token) {
    if (identical(_cancelTokens[itemId], token)) {
      _cancelTokens.remove(itemId);
      _desktopTargets.remove(itemId);
    }
  }

  static bool _isActiveAndroidTask(DownloadTaskStatus status) =>
      status == DownloadTaskStatus.enqueued ||
      status == DownloadTaskStatus.running ||
      status == DownloadTaskStatus.paused;

  Future<void> _cancelAndroidTask(String taskId) async {
    try {
      await FlutterDownloader.cancel(taskId: taskId);
    } catch (error) {
      debugPrint('Nie udało się anulować zadania (${error.runtimeType}).');
    }
    try {
      await FlutterDownloader.remove(taskId: taskId, shouldDeleteContent: true);
    } catch (error) {
      debugPrint('Nie udało się usunąć zadania (${error.runtimeType}).');
    }
  }

  /// Stops a queued or running download and forgets it, so that the
  /// background reconciliation does not start it again.
  Future<void> cancelDownload(String itemId) async {
    _cancelledItemIds.add(itemId);
    _cancelGenerations[itemId] = (_cancelGenerations[itemId] ?? 0) + 1;
    final record = _backgroundTasks.remove(itemId);
    final preparation = _pendingMetadataPreparations.remove(itemId);
    if (record != null) await _saveBackgroundTasks();
    if (preparation != null) await _savePendingMetadataPreparations();
    _cancelTokens.remove(itemId)?.cancel();
    final desktopTarget = _desktopTargets.remove(itemId);

    if (Platform.isAndroid && record != null) {
      final saveDir = record['saveDir'] as String?;
      final fileName = record['fileName'] as String?;
      _cancelledAndroidTargets[itemId] = {
        'saveDir': saveDir,
        'fileName': fileName,
        'until': DateTime.now()
            .add(const Duration(minutes: 2))
            .millisecondsSinceEpoch,
      };
      if (FlutterDownloader.initialized) {
        final taskIds = <String>{};
        final knownTaskId = record['taskId'];
        if (knownTaskId is String) taskIds.add(knownTaskId);
        try {
          final tasks = await FlutterDownloader.loadTasks() ?? [];
          for (final task in tasks) {
            if (task.taskId == knownTaskId &&
                task.status == DownloadTaskStatus.complete) {
              // The video is already on disk (only metadata was pending):
              // removing the task would delete it, e.g. on logout.
              taskIds.remove(task.taskId);
            } else if (task.savedDir == saveDir &&
                task.filename == fileName &&
                _isActiveAndroidTask(task.status)) {
              taskIds.add(task.taskId);
            }
          }
        } catch (error) {
          debugPrint('Nie udało się odczytać zadań (${error.runtimeType}).');
        }
        for (final taskId in taskIds) {
          await _cancelAndroidTask(taskId);
        }
      }
    }
    await _restoreSetAsideCopy(desktopTarget ?? _recordPath(record));

    activeDownloads.value = Map<String, DownloadStatus>.from(
      activeDownloads.value,
    )..remove(itemId);
  }

  /// Cancels every download whose target file is [path] or lies inside the
  /// directory [path]. Called before the user deletes downloaded content.
  Future<void> cancelDownloadsInPath(String path) async {
    String normalize(String value) {
      final unified = value
          .replaceAll('\\', '/')
          .replaceAll(RegExp(r'/+'), '/')
          .replaceFirst(RegExp(r'/$'), '');
      return Platform.isWindows ? unified.toLowerCase() : unified;
    }

    final target = normalize(path);
    bool covers(String file) {
      final candidate = normalize(file);
      return candidate == target || candidate.startsWith('$target/');
    }

    final itemIds = <String>{};
    _backgroundTasks.forEach((itemId, record) {
      if (covers('${record['saveDir']}/${record['fileName']}')) {
        itemIds.add(itemId);
      }
    });
    _pendingMetadataPreparations.forEach((itemId, preparation) {
      if (covers('${preparation['seriesDir']}/${preparation['fileName']}')) {
        itemIds.add(itemId);
      }
    });
    _desktopTargets.forEach((itemId, file) {
      if (covers(file)) itemIds.add(itemId);
    });
    for (final itemId in itemIds) {
      await cancelDownload(itemId);
    }
  }

  /// Called at logout. Every queued, running or failed download holds the
  /// access token of the account that is logging out, so all of them are
  /// cancelled and forgotten. Files already downloaded are kept.
  Future<void> cancelAllAndForgetTokens() async {
    final itemIds = <String>{
      ..._backgroundTasks.keys,
      ..._pendingMetadataPreparations.keys,
      ..._cancelTokens.keys,
      ...activeDownloads.value.keys,
    };
    for (final itemId in itemIds) {
      await cancelDownload(itemId);
    }
    failedDownloads.value = [];
    await _saveFailedDownloads();
  }

  Future<void> _cancelOrphanedAndroidTasks(List<DownloadTask> tasks) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in _cancelledAndroidTargets.entries.toList()) {
      final itemId = entry.key;
      final target = entry.value;
      if (_backgroundTasks.containsKey(itemId) ||
          now > (target['until'] as int)) {
        _cancelledAndroidTargets.remove(itemId);
        continue;
      }
      for (final task in tasks) {
        if (task.savedDir == target['saveDir'] &&
            task.filename == target['fileName'] &&
            _isActiveAndroidTask(task.status)) {
          await _cancelAndroidTask(task.taskId);
        }
      }
    }
  }

  Future<void>? _backgroundInitFuture;

  /// Restores Android background downloads once. Concurrent callers (a whole
  /// season queued at once) wait for the same restore, so records they add
  /// are never overwritten by the stored copy loaded a moment later.
  Future<void> initializeBackgroundDownloads() {
    if (!Platform.isAndroid) return Future<void>.value();
    return _backgroundInitFuture ??= _initializeBackgroundDownloads();
  }

  Future<void> _initializeBackgroundDownloads() async {
    if (_backgroundInitialized || (_backgroundSyncTimer?.isActive ?? false)) {
      return;
    }
    _backgroundInitialized = true;
    try {
      final encoded = await _storage.getString('background_downloads_v1');
      if (encoded != null && encoded.isNotEmpty) {
        final decoded = jsonDecode(encoded) as Map<String, dynamic>;
        final stored = decoded.map(
          (id, value) => MapEntry(id, Map<String, dynamic>.from(value as Map)),
        );
        // Records added while the stored copy was loading win.
        _backgroundTasks = {...stored, ..._backgroundTasks};
      }
      final metadataEncoded = await _storage.getString(
        'background_metadata_preparations_v1',
      );
      if (metadataEncoded != null && metadataEncoded.isNotEmpty) {
        final decoded = jsonDecode(metadataEncoded) as Map<String, dynamic>;
        final stored = decoded.map(
          (id, value) => MapEntry(id, Map<String, dynamic>.from(value as Map)),
        );
        _pendingMetadataPreparations = {
          ...stored,
          ..._pendingMetadataPreparations,
        };
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
      _backgroundInitFuture = null;
    }
  }

  final Map<String, Future<void>> _pathLocks = {};

  /// Runs [action] alone for [path]. Episodes of one series share the folder
  /// cover and series.json; parallel downloads used to write and delete the
  /// same file at once, which fails on Windows and corrupts JSON elsewhere.
  Future<T> _withPathLock<T>(String path, Future<T> Function() action) {
    final previous = _pathLocks[path] ?? Future<void>.value();
    final result = previous.then((_) => action());
    final tail = result.then<void>((_) {}, onError: (Object _) {});
    _pathLocks[path] = tail;
    tail.whenComplete(() {
      if (identical(_pathLocks[path], tail)) _pathLocks.remove(path);
    });
    return result;
  }

  /// Writes through a temporary file and a rename, so a reader never sees
  /// half of a file and a crash mid-write keeps the previous version.
  Future<void> _writeStringAtomic(String path, String content) {
    return _withPathLock(path, () async {
      final temp = File('$path.${DateTime.now().microsecondsSinceEpoch}.tmp');
      try {
        await temp.writeAsString(content, flush: true);
        await temp.rename(path);
      } catch (_) {
        try {
          if (await temp.exists()) await temp.delete();
        } catch (_) {}
        rethrow;
      }
    });
  }

  /// Downloads an image once; a failure only costs the picture.
  Future<void> _downloadImageOnce(
    Dio dio,
    String url,
    String path,
    String token,
  ) {
    return _withPathLock(path, () async {
      final target = File(path);
      if (await target.exists()) return;
      final temp = File('$path.${DateTime.now().microsecondsSinceEpoch}.tmp');
      try {
        await dio.download(
          url,
          temp.path,
          options: Options(headers: jellyfinAuthHeaders(token)),
        );
        if (await temp.length() >= 500 && !await target.exists()) {
          await temp.rename(path);
        }
      } catch (error) {
        debugPrint('Nie udało się pobrać grafiki (${error.runtimeType}).');
      } finally {
        try {
          if (await temp.exists()) await temp.delete();
        } catch (_) {}
      }
    });
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

  /// How many metadata preparations may run at once. Each runs on its own,
  /// so one episode stuck waiting for Wi-Fi no longer blocks the others.
  static const _maxParallelMetadataPreparations = 3;

  Future<void> _processPendingMetadataPreparations() async {
    if (!Platform.isAndroid || !FlutterDownloader.initialized) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in _pendingMetadataPreparations.entries.toList()) {
      if (_preparingMetadataItemIds.length >=
          _maxParallelMetadataPreparations) {
        break;
      }
      final itemId = entry.key;
      if (_enqueueingItemIds.contains(itemId)) continue;
      if (_preparingMetadataItemIds.contains(itemId)) continue;
      final retryAt = entry.value['retryAt'] as int? ?? 0;
      if (retryAt > now) continue;
      _preparingMetadataItemIds.add(itemId);
      unawaited(_prepareMetadata(itemId, entry.value));
    }
  }

  Future<void> _prepareMetadata(
    String itemId,
    Map<String, dynamic> preparation,
  ) async {
    try {
      await _downloadJsonMetadata(
        itemId: itemId,
        baseUrl: normalizeServerUrl(preparation['baseUrl'] as String),
        token: preparation['token'] as String,
        userId: preparation['userId'] as String,
        seriesId: preparation['seriesId'] as String?,
        seriesDir: Directory(preparation['seriesDir'] as String),
        fileName: preparation['fileName'] as String,
      );
      if (identical(_pendingMetadataPreparations[itemId], preparation)) {
        _pendingMetadataPreparations.remove(itemId);
        await _savePendingMetadataPreparations();
      }
    } catch (error) {
      final current = _pendingMetadataPreparations[itemId];
      if (current != null) {
        final attempts = (current['attempts'] as int? ?? 0) + 1;
        final delaySeconds = (15 * (1 << (attempts - 1).clamp(0, 5))).clamp(
          15,
          480,
        );
        current['attempts'] = attempts;
        current['retryAt'] = DateTime.now()
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
      await _cancelOrphanedAndroidTasks(tasks);
      final snapshots = tasks.map(_snapshotAndroidTask).toList();

      for (final entry in _backgroundTasks.entries.toList()) {
        final itemId = entry.key;
        if (_enqueueingItemIds.contains(itemId)) continue;
        final record = entry.value;
        // Skip a record the user cancelled while this pass was running.
        if (!identical(_backgroundTasks[itemId], record)) continue;
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
              headers: jellyfinAuthHeaders(record['token'] as String),
              savedDir: record['saveDir'] as String,
              fileName: record['fileName'] as String,
              showNotification: record['showNotification'] as bool? ?? false,
              openFileFromNotification: false,
              requiresStorageNotLow: true,
              allowCellular: record['allowCellular'] as bool? ?? false,
              timeout: 120000,
            );
            if (newTaskId != null &&
                !identical(_backgroundTasks[itemId], record)) {
              await _cancelAndroidTask(newTaskId);
            } else if (newTaskId == null) {
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
            if (identical(_backgroundTasks[itemId], record)) {
              _updateProgress(
                itemId,
                isQueued: true,
                progressText: 'Oczekiwanie na ponowienie...',
              );
            }
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
    if (_cancelledItemIds.contains(itemId)) return;
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

  Future<String>? _directoryPathCache;

  /// Must be called after `setting_download_path` changes.
  void invalidateDirectoryPathCache() => _directoryPathCache = null;

  /// The download root. Cached: checking a season of episodes used to read
  /// the setting from secure storage once per episode and quality.
  Future<String> getDirectoryPath() {
    final cached = _directoryPathCache;
    if (cached != null) return cached;
    final future = _resolveDirectoryPath();
    _directoryPathCache = future;
    future.catchError((Object _) {
      if (identical(_directoryPathCache, future)) _directoryPathCache = null;
      return '';
    });
    return future;
  }

  Future<String> _resolveDirectoryPath() async {
    final customPath = await _storage.getString('setting_download_path');

    if (customPath != null && customPath.isNotEmpty) {
      return "$customPath/JellyDawtyl";
    }

    if (Platform.isAndroid) {
      return "/storage/emulated/0/Download/JellyDawtyl";
    } else if (Platform.isWindows) {
      final directory = await getApplicationSupportDirectory();
      return "${directory.path}\\JellyDawtyl";
    } else if (Platform.isLinux || Platform.isMacOS) {
      // ~/Downloads when the platform has one, the documents folder otherwise.
      final directory =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      return "${directory.path}/JellyDawtyl";
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

  /// Names used by versions before item IDs were part of file names. They
  /// are only used to find, and keep using, files downloaded back then.
  Map<String, String> _generateLegacyPaths(
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

  /// Keeps letters of every alphabet and removes only characters that are
  /// not allowed in file names on Android, Windows, Linux or macOS.
  static String _safePathLabel(String value) {
    var label = value
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final runes = label.runes.toList();
    if (runes.length > 50) label = String.fromCharCodes(runes.take(50));
    return label
        .replaceFirst(RegExp(r'^[. ]+'), '')
        .replaceFirst(RegExp(r'[. ]+$'), '');
  }

  @visibleForTesting
  Map<String, String> generatePathsForTest(
    JellyfinItem item,
    String? seriesOverrideName,
    String qualityLabel,
  ) => _generatePaths(item, seriesOverrideName, qualityLabel);

  /// Paths for new downloads. The item ID in the file name keeps two items
  /// with the same title (or a title without Latin letters) apart.
  Map<String, String> _generatePaths(
    JellyfinItem item,
    String? seriesOverrideName,
    String qualityLabel,
  ) {
    final bool isEpisode = item.type == "Episode";
    final String folderBaseName =
        seriesOverrideName ??
        (isEpisode ? (item.seriesName ?? item.name) : item.name);
    final label = _safePathLabel(folderBaseName);
    final folderId = isEpisode ? (item.seriesId ?? item.id) : item.id;
    final folder = label.isEmpty ? folderId : label;
    final season = (item.parentIndexNumber ?? 0).toString().padLeft(3, '0');
    final episode = (item.indexNumber ?? 0).toString().padLeft(3, '0');
    final fileName = isEpisode
        ? "${folder}_S${season}E${episode}_${item.id}_$qualityLabel.mp4"
        : "${folder}_${item.id}_$qualityLabel.mp4";
    return {"folder": folder, "file": fileName};
  }

  /// A file found under a legacy name may belong to another item with the
  /// same title. The metadata sidecar names its item; without a readable
  /// sidecar the file is accepted, as older versions did.
  bool _legacyFileBelongsTo(String filePath, String itemId) {
    final sidecar = File('$filePath.json');
    try {
      if (!sidecar.existsSync()) return true;
      final decoded = jsonDecode(sidecar.readAsStringSync());
      final id = decoded is Map ? decoded['Id'] : null;
      return id == null || id == itemId;
    } catch (_) {
      return true;
    }
  }

  Future<void> startDownload({
    required JellyfinItem item,
    required String baseUrl,
    required String token,
    int? maxWidth,
    int? bitrate,
    required String qualityLabel,
    String? seriesOverrideName,
    bool force = false,
  }) async {
    if (Platform.isAndroid) await initializeBackgroundDownloads();
    await updateConcurrencyLimit();
    final String itemId = item.id;
    if (activeDownloads.value.containsKey(itemId)) return;
    downloadTitles[itemId] = item.type == 'Episode'
        ? '${seriesOverrideName ?? item.seriesName ?? ''} '
                  'S${item.parentIndexNumber ?? 0}E${item.indexNumber ?? 0} · ${item.name}'
              .trim()
        : item.name;
    _cancelledItemIds.remove(itemId);
    final generation = _cancelGenerations[itemId] ?? 0;
    bool cancelled() => (_cancelGenerations[itemId] ?? 0) != generation;

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
      if (baseDir.isEmpty) {
        // No usable folder: say so instead of leaving "Waiting..." forever.
        _updateProgress(
          itemId,
          progressText: 'Brak folderu pobierania — wybierz go w ustawieniach',
        );
        Future.delayed(const Duration(seconds: 5), () {
          if (activeDownloads.value[itemId]?.isDownloaded == false) {
            activeDownloads.value = Map<String, DownloadStatus>.from(
              activeDownloads.value,
            )..remove(itemId);
          }
        });
        return;
      }

      if (cancelled()) return;

      final paths = _generatePaths(item, finalSeriesName, qualityLabel);
      final legacyPaths = _generateLegacyPaths(
        item,
        finalSeriesName,
        qualityLabel,
      );
      String safeFolderName = paths["folder"]!;
      final String fileName = paths["file"]!;
      // Keep new episodes next to ones downloaded under the old folder name.
      final legacyFolder = legacyPaths["folder"]!;
      if (legacyFolder.trim().isNotEmpty &&
          legacyFolder != safeFolderName &&
          Directory('$baseDir/$legacyFolder').existsSync()) {
        safeFolderName = legacyFolder;
      }

      Directory seriesDir = Directory('$baseDir/$safeFolderName');
      if (!seriesDir.existsSync()) seriesDir.createSync(recursive: true);

      final targetFile = File('${seriesDir.path}/$fileName');
      final legacyFile = File(
        '$baseDir/${legacyPaths["folder"]}/${legacyPaths["file"]}',
      );
      if (force && !_backgroundTasks.containsKey(itemId)) {
        // "Download again": set the old copy aside instead of deleting it,
        // so a failed or cancelled download gives it back. It also keeps the
        // Android worker from mistaking the old file for a partial one.
        await _setAsideCopy(targetFile.path);
      }
      if (!_backgroundTasks.containsKey(itemId) &&
          await targetFile.exists() &&
          await targetFile.length() > 0) {
        _finishDownload(itemId, targetFile.path);
        return;
      }
      if (!force &&
          !_backgroundTasks.containsKey(itemId) &&
          await legacyFile.exists() &&
          await legacyFile.length() > 0 &&
          _legacyFileBelongsTo(legacyFile.path, itemId)) {
        _finishDownload(itemId, legacyFile.path);
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

      final cancelToken = Platform.isAndroid ? null : CancelToken();
      BaseDownloader downloader = await _getDownloaderInstance(
        cancelToken: cancelToken,
      );

      bool wifiOnly = await _storage.getSetting(
        'setting_wifionly',
        defaultValue: true,
      );

      final showNotification = await _storage.getSetting(
        'setting_native_downloader',
        defaultValue: false,
      );
      if (cancelled()) return;
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

      if (cancelled()) return;
      if (cancelToken != null) {
        _cancelTokens[itemId] = cancelToken;
        _desktopTargets[itemId] = '${seriesDir.path}/$fileName';
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
          onProgress: (id, val, text) {
            if (cancelled()) return;
            _updateProgress(id, progressValue: val, progressText: text);
          },
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
        if (cancelToken != null) _releaseCancelToken(itemId, cancelToken);
      }

      if (cancelled()) {
        // Cancelled while the transfer was starting or running.
        if (taskId != null) await _cancelAndroidTask(taskId);
        return;
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

  static String _setAsidePath(String videoPath) => '$videoPath.old';

  Future<void> _setAsideCopy(String videoPath) async {
    try {
      final video = File(videoPath);
      if (await video.exists()) await video.rename(_setAsidePath(videoPath));
    } catch (error) {
      debugPrint('Nie udało się odłożyć starej kopii (${error.runtimeType}).');
    }
  }

  /// After a failed or cancelled "Download again", puts the old copy back.
  Future<void> _restoreSetAsideCopy(String? videoPath) async {
    if (videoPath == null) return;
    try {
      final old = File(_setAsidePath(videoPath));
      if (await old.exists() && !await File(videoPath).exists()) {
        await old.rename(videoPath);
      }
    } catch (error) {
      debugPrint('Nie udało się przywrócić kopii (${error.runtimeType}).');
    }
  }

  Future<void> _dropSetAsideCopy(String videoPath) async {
    try {
      final old = File(_setAsidePath(videoPath));
      if (await old.exists()) await old.delete();
    } catch (_) {}
  }

  final Map<String, DateTime> _lastProgressEmit = {};

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
    final previous = activeDownloads.value[id];
    final now = DateTime.now();
    // Every listener rebuilds on each update. Several transfers reporting
    // every few kilobytes used to flood the UI, so small steps are merged.
    if (previous != null &&
        !previous.isDownloaded &&
        previous.isQueued == isQueued &&
        previous.progressValue > 0 &&
        normalizedProgress >= previous.progressValue &&
        normalizedProgress - previous.progressValue < 0.01 &&
        now.difference(_lastProgressEmit[id] ?? DateTime(0)) <
            const Duration(milliseconds: 500)) {
      return;
    }
    _lastProgressEmit[id] = now;
    final newMap = Map<String, DownloadStatus>.from(activeDownloads.value);
    newMap[id] = DownloadStatus(
      progressValue: normalizedProgress,
      progressText: progressText,
      isQueued: isQueued,
    );
    activeDownloads.value = newMap;
  }

  void _finishDownload(String id, String fullPath) {
    _lastProgressEmit.remove(id);
    unawaited(_dropSetAsideCopy(fullPath));
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
    final coverUrl =
        "$baseUrl/Items/${item.seriesId ?? item.id}/Images/Primary?fillWidth=400&quality=90";
    await _downloadImageOnce(
      dio,
      coverUrl,
      '${seriesDir.path}/folder.jpg',
      token,
    );

    final thumbUrl =
        "$baseUrl/Items/${item.id}/Images/Primary?fillWidth=400&quality=90";
    final thumbFileName = fileName.replaceAll('.mp4', '.jpg');
    await _downloadImageOnce(
      dio,
      thumbUrl,
      '${seriesDir.path}/$thumbFileName',
      token,
    );
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
          '$baseUrl/Items/$id',
          queryParameters: {'UserId': userId},
          options: Options(headers: jellyfinAuthHeaders(token)),
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
    // Intro/credits segments (Intro Skipper), so skipping works offline.
    final segments = await JellyfinApi().fetchMediaSegments(
      baseUrl: baseUrl,
      token: token,
      itemId: itemId,
    );
    if (segments.isNotEmpty) itemMetadata['MediaSegments'] = segments;
    await _writeStringAtomic(
      '${seriesDir.path}/$fileName.json',
      const JsonEncoder.withIndent('  ').convert(itemMetadata),
    );
    if (seriesId != null && seriesId.isNotEmpty) {
      final seriesMetadata = await fetchItem(seriesId);
      if (seriesMetadata == null) {
        throw StateError('Nie udało się pobrać metadanych serialu.');
      }
      await _writeStringAtomic(
        '${seriesDir.path}/series.json',
        const JsonEncoder.withIndent('  ').convert(seriesMetadata),
      );
    }
  }

  static const subtitleWaitTimeout = Duration(minutes: 10);

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

    // One read of the downloader database for the checks below; the wait
    // loop re-reads it because it waits for a state change.
    final initialJobs = Platform.isAndroid
        ? await FlutterDownloader.loadTasks() ?? <DownloadTask>[]
        : null;

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
      final previousJobs =
          initialJobs
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
          final activeTask = initialJobs!.where((task) {
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
              headers: jellyfinAuthHeaders(token),
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
          // A Wi-Fi-only task stays "enqueued" on mobile data for as long as
          // it takes; give up after a while and let the backoff retry later.
          final waitUntil = DateTime.now().add(subtitleWaitTimeout);
          while (true) {
            if (DateTime.now().isAfter(waitUntil)) {
              throw TimeoutException(
                'Przekroczono czas oczekiwania na napisy.',
              );
            }
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
            options: Options(headers: jellyfinAuthHeaders(token)),
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
      final legacyPaths = _generateLegacyPaths(item, seriesOverrideName, q);
      final candidates = <String>[
        "${paths["folder"]}/${paths["file"]}",
        if (legacyPaths["folder"]!.trim().isNotEmpty &&
            legacyPaths["folder"] != paths["folder"])
          "${legacyPaths["folder"]}/${paths["file"]}",
      ];
      for (final relativePath in candidates) {
        final status = await checkStatus(item.id, relativePath);
        if (status.isDownloaded && status.filePath != null) {
          return status.filePath;
        }
      }
      // Files downloaded by older versions keep their original names.
      final status = await checkStatus(
        item.id,
        "${legacyPaths["folder"]}/${legacyPaths["file"]}",
      );
      if (status.isDownloaded &&
          status.filePath != null &&
          _legacyFileBelongsTo(status.filePath!, item.id)) {
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
