import 'dart:async';
import 'dart:collection';

typedef DownloadQueueErrorHandler =
    void Function(String itemId, Object error, StackTrace stackTrace);

/// Runs download preparation and transfer tasks with a bounded concurrency.
/// A failed task is reported and does not prevent later tasks from starting.
class DownloadTaskQueue {
  DownloadTaskQueue({
    int maxConcurrent = 1,
    required DownloadQueueErrorHandler onError,
  }) : _maxConcurrent = maxConcurrent < 1 ? 1 : maxConcurrent,
       _onError = onError;

  final Queue<_QueuedTask> _waiting = Queue<_QueuedTask>();
  final DownloadQueueErrorHandler _onError;
  int _maxConcurrent;
  int _activeCount = 0;
  bool _pumping = false;

  int get activeCount => _activeCount;
  int get waitingCount => _waiting.length;

  set maxConcurrent(int value) {
    _maxConcurrent = value < 1 ? 1 : value;
    unawaited(_pump());
  }

  Future<void> enqueue(String itemId, Future<void> Function() run) {
    final task = _QueuedTask(itemId, run, Completer<void>());
    _waiting.add(task);
    unawaited(_pump());
    return task.completer.future;
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (_waiting.isNotEmpty && _activeCount < _maxConcurrent) {
        final task = _waiting.removeFirst();
        _activeCount++;
        unawaited(_run(task));
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> _run(_QueuedTask task) async {
    try {
      await task.run();
    } catch (error, stackTrace) {
      try {
        _onError(task.itemId, error, stackTrace);
      } catch (_) {
        // Error reporting must not strand the queue either.
      }
    } finally {
      _activeCount--;
      await _pump();
      if (!task.completer.isCompleted) task.completer.complete();
    }
  }
}

class _QueuedTask {
  final String itemId;
  final Future<void> Function() run;
  final Completer<void> completer;

  const _QueuedTask(this.itemId, this.run, this.completer);
}
