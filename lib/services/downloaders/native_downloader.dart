import 'dart:io';

import 'package:flutter_downloader/flutter_downloader.dart';

import 'base_downloader.dart';

/// Android WorkManager-backed downloader. Tasks continue if Flutter is closed.
class NativeDownloader implements BaseDownloader {
  @override
  Future<String?> downloadVideo({
    required String itemId,
    required String downloadUrl,
    required String saveDir,
    required String fileName,
    required String token,
    required bool wifiOnly,
    required bool showNotification,
    required Function(String, double, String) onProgress,
    required Function(String) onFinished,
    required Future<void> Function(String) onFailed,
  }) async {
    if (!Platform.isAndroid) return null;

    try {
      final taskId = await FlutterDownloader.enqueue(
        url: downloadUrl,
        headers: {'X-Emby-Token': token},
        savedDir: saveDir,
        fileName: fileName,
        showNotification: showNotification,
        openFileFromNotification: false,
        requiresStorageNotLow: true,
        allowCellular: !wifiOnly,
        timeout: 120000,
      );
      if (taskId == null) {
        throw StateError('Android nie przyjął zadania pobierania.');
      }
      onProgress(itemId, 0, 'Dodano do pobierania w tle');
      return taskId;
    } catch (error) {
      onProgress(itemId, 0, 'Nie udało się rozpocząć pobierania');
      await onFailed(itemId);
      rethrow;
    }
  }
}
