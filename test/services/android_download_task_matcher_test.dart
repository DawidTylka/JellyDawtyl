import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/android_download_task_matcher.dart';

void main() {
  const targetUrl = 'https://jellyfin.test/video/item/stream.mp4?Static=true';
  const activeTask = AndroidDownloadTaskSnapshot(
    taskId: 'active',
    savedDir: '/downloads/show',
    fileName: 'episode.mp4',
    url: 'https://jellyfin.test/video/item/stream.mp4?Static=true',
    createdAt: 100,
    state: AndroidDownloadTaskState.running,
  );

  test('recovers the active task when its id was lost before app shutdown', () {
    final recovered = findAndroidDownloadTask(
      tasks: const [
        activeTask,
        AndroidDownloadTaskSnapshot(
          taskId: 'different-target',
          savedDir: '/downloads/other',
          fileName: 'episode.mp4',
          url: 'https://jellyfin.test/video/item/stream.mp4',
          createdAt: 200,
          state: AndroidDownloadTaskState.running,
        ),
      ],
      taskId: null,
      savedDir: '/downloads/show',
      fileName: 'episode.mp4',
      url: targetUrl,
    );

    expect(recovered?.taskId, 'active');
  });

  test('prefers a live matching task over a newer failed task', () {
    final recovered = findAndroidDownloadTask(
      tasks: const [
        activeTask,
        AndroidDownloadTaskSnapshot(
          taskId: 'failed-newer',
          savedDir: '/downloads/show',
          fileName: 'episode.mp4',
          url: 'https://jellyfin.test/video/item/stream.mp4?retry=1',
          createdAt: 300,
          state: AndroidDownloadTaskState.failed,
        ),
      ],
      taskId: null,
      savedDir: '/downloads/show',
      fileName: 'episode.mp4',
      url: targetUrl,
    );

    expect(recovered?.taskId, 'active');
  });

  test('uses the stored task id when Android still knows it', () {
    final completed = activeTask.copyWith(
      taskId: 'stored-id',
      state: AndroidDownloadTaskState.complete,
    );
    final recovered = findAndroidDownloadTask(
      tasks: [
        completed,
        const AndroidDownloadTaskSnapshot(
          taskId: 'new-active',
          savedDir: '/downloads/show',
          fileName: 'episode.mp4',
          url: 'https://jellyfin.test/video/item/stream.mp4',
          createdAt: 400,
          state: AndroidDownloadTaskState.running,
        ),
      ],
      taskId: 'stored-id',
      savedDir: '/downloads/show',
      fileName: 'episode.mp4',
      url: targetUrl,
    );

    expect(recovered?.taskId, 'stored-id');
  });

  test('recognizes a paused Android task as recoverable', () {
    final paused = activeTask.copyWith(
      taskId: 'paused-id',
      state: AndroidDownloadTaskState.paused,
    );
    final recovered = findAndroidDownloadTask(
      tasks: [paused],
      taskId: null,
      savedDir: '/downloads/show',
      fileName: 'episode.mp4',
      url: targetUrl,
    );

    expect(recovered?.taskId, 'paused-id');
    expect(recovered?.isActive, isTrue);
  });
}

extension on AndroidDownloadTaskSnapshot {
  AndroidDownloadTaskSnapshot copyWith({
    String? taskId,
    AndroidDownloadTaskState? state,
  }) => AndroidDownloadTaskSnapshot(
    taskId: taskId ?? this.taskId,
    savedDir: savedDir,
    fileName: fileName,
    url: url,
    createdAt: createdAt,
    state: state ?? this.state,
  );
}
