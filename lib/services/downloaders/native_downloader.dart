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
    onProgress(itemId, -1, "Przygotowanie w tle...");

    try {
      var status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }

      await FlutterDownloader.enqueue(
        url: downloadUrl,
        headers: {"X-Emby-Token": token},
        savedDir: saveDir,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: false,
        allowCellular: !wifiOnly,
      );

      Future.delayed(const Duration(seconds: 3), () => onFinished(itemId));
    } catch (e) {
      debugPrint("Błąd kolejkowania FlutterDownloader: $e");
      onFinished(itemId);
    }
  }
}
