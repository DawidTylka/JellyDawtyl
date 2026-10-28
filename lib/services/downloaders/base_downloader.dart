abstract class BaseDownloader {
  Future<String?> downloadVideo({
    required String itemId,
    required String downloadUrl,
    required String saveDir,
    required String fileName,
    required String token,
    required bool wifiOnly,
    required bool showNotification,
    required Function(String id, double progressValue, String progressText)
    onProgress,
    required Function(String id) onFinished,
    required Future<void> Function(String id) onFailed,
  });
}
