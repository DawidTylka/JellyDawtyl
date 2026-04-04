abstract class BaseDownloader {
  Future<void> downloadVideo({
    required String itemId,
    required String downloadUrl,
    required String saveDir,
    required String fileName,
    required String token,
    required bool wifiOnly,
    required Function(String id, double progressValue, String progressText)
    onProgress,
    required Function(String id) onFinished,
  });
}
