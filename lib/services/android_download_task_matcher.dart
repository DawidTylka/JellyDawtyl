enum AndroidDownloadTaskState {
  enqueued,
  running,
  paused,
  complete,
  failed,
  canceled,
  other,
}

class AndroidDownloadTaskSnapshot {
  const AndroidDownloadTaskSnapshot({
    required this.taskId,
    required this.savedDir,
    required this.fileName,
    required this.url,
    required this.createdAt,
    required this.state,
  });

  final String taskId;
  final String savedDir;
  final String fileName;
  final String url;
  final int createdAt;
  final AndroidDownloadTaskState state;

  bool get isActive =>
      state == AndroidDownloadTaskState.enqueued ||
      state == AndroidDownloadTaskState.running ||
      state == AndroidDownloadTaskState.paused;
}

/// Finds the task to reconcile after app restart or a lost enqueue response.
AndroidDownloadTaskSnapshot? findAndroidDownloadTask({
  required List<AndroidDownloadTaskSnapshot> tasks,
  required String? taskId,
  required String savedDir,
  required String fileName,
  required String url,
  bool includeInactiveFallback = true,
}) {
  if (taskId != null) {
    for (final task in tasks) {
      if (task.taskId == taskId) return task;
    }
  }

  String endpoint(String value) {
    final queryIndex = value.indexOf('?');
    return queryIndex < 0 ? value : value.substring(0, queryIndex);
  }

  final expectedEndpoint = endpoint(url);
  final matches = tasks.where((task) {
    return task.savedDir == savedDir &&
        task.fileName == fileName &&
        endpoint(task.url) == expectedEndpoint;
  }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  for (final task in matches) {
    if (task.isActive) return task;
  }
  if (includeInactiveFallback && taskId == null && matches.isNotEmpty) {
    return matches.first;
  }
  return null;
}
