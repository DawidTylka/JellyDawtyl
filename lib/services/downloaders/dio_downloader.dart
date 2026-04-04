import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'base_downloader.dart';

class DioDownloader implements BaseDownloader {
  final Dio _dio = Dio();

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
    String fullPath = "$saveDir/$fileName";

    if (wifiOnly) {
      final connectivityResult = await Connectivity().checkConnectivity();
      bool hasWifi = connectivityResult.contains(ConnectivityResult.wifi);

      if (!hasWifi) {
        debugPrint("Zablokowano: Brak Wi-Fi!");
        onProgress(itemId, 0.0, "Oczekuje na Wi-Fi...");
        Future.delayed(const Duration(seconds: 3), () => onFinished(itemId));
        return;
      }
    }

    onProgress(itemId, 0.0, "Start...");

    try {
      await _dio.download(
        downloadUrl,
        fullPath,
        options: Options(headers: {"X-Emby-Token": token}),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            double progress = received / total;
            onProgress(
              itemId,
              progress,
              "${(progress * 100).toStringAsFixed(0)}%",
            );
          } else {
            double mb = received / (1024 * 1024);
            onProgress(itemId, -1, "${mb.toStringAsFixed(1)} MB");
          }
        },
      );

      Future.delayed(const Duration(seconds: 1), () => onFinished(itemId));
    } catch (e) {
      debugPrint("Błąd pobierania Dio: $e");
      onFinished(itemId);
    }
  }
}
