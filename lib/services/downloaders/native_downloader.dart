import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'base_downloader.dart';

class NativeDownloader implements BaseDownloader {
  @override
  Future<void> downloadVideo({
    required String itemId,
    required String downloadUrl,
    required String saveDir,
    required String fileName,
    required String token,
    required bool wifiOnly,
    required Function(String, double, String) onProgress,
    required Function(String) onFinished,
  }) async {
    await Permission.notification.request();

    final completer = Completer<void>();

    try {
      final taskId = await FlutterDownloader.enqueue(
        url: downloadUrl,
        headers: {"X-Emby-Token": token},
        savedDir: saveDir,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: false,
        allowCellular: !wifiOnly,
      );

      if (taskId == null) {
        onFinished(itemId);
        return;
      }

      Timer.periodic(const Duration(seconds: 2), (timer) async {
        final tasks = await FlutterDownloader.loadTasksWithRawQuery(
          query: "SELECT * FROM task WHERE task_id='$taskId'",
        );

        if (tasks == null || tasks.isEmpty) {
          timer.cancel();
          if (!completer.isCompleted) completer.complete();
          return;
        }

        final task = tasks.first;
        
        double progressValue = 0.0;
        String progressText = "";

        if (task.progress >= 0 && task.progress <= 100) {
          progressValue = task.progress / 100.0;
          progressText = "${task.progress}%";
        } else {
          try {
            final file = File("$saveDir/$fileName");
            if (file.existsSync()) {
              double actualBytes = file.lengthSync().toDouble();
              double downloadedMB = actualBytes / (1024 * 1024);
              progressValue = -1.0;
              progressText = "Pobrano: ${downloadedMB.toStringAsFixed(1)} MB";
            } else {
              progressValue = -1.0;
              progressText = "Inicjalizacja...";
            }
          } catch (e) {
            progressValue = -1.0;
            progressText = "Pobieranie danych...";
          }
        }

        onProgress(itemId, progressValue, progressText);

        if (task.status == DownloadTaskStatus.complete) {
          timer.cancel();
          onFinished(itemId);
          if (!completer.isCompleted) completer.complete();
        } else if (task.status == DownloadTaskStatus.failed ||
            task.status == DownloadTaskStatus.canceled) {
          timer.cancel();
          onFinished(itemId);
          if (!completer.isCompleted) completer.complete();
        }
      });
    } catch (e) {
      debugPrint("Błąd NativeDownloader: $e");
      onFinished(itemId);
      if (!completer.isCompleted) completer.complete();
    }

    return completer.future;
  }
}