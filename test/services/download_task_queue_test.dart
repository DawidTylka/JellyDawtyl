import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/download_task_queue.dart';

void main() {
  test('continues to the next task after a task throws', () async {
    final order = <String>[];
    final errors = <String>[];
    final queue = DownloadTaskQueue(
      maxConcurrent: 1,
      onError: (itemId, error, _) => errors.add('$itemId:${error.runtimeType}'),
    );

    await Future.wait([
      queue.enqueue('first', () async {
        order.add('first');
        throw StateError('intentional test failure');
      }),
      queue.enqueue('second', () async => order.add('second')),
    ]);

    expect(order, ['first', 'second']);
    expect(errors, ['first:StateError']);
    expect(queue.activeCount, 0);
    expect(queue.waitingCount, 0);
  });

  test('respects the configured concurrency limit', () async {
    final firstStarted = Completer<void>();
    final secondStarted = Completer<void>();
    final thirdStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final releaseSecond = Completer<void>();
    final releaseThird = Completer<void>();
    var active = 0;
    var peakActive = 0;

    Future<void> run(Completer<void> started, Completer<void> release) async {
      active++;
      if (active > peakActive) peakActive = active;
      started.complete();
      await release.future;
      active--;
    }

    final queue = DownloadTaskQueue(maxConcurrent: 2, onError: (_, _, _) {});
    final first = queue.enqueue('first', () => run(firstStarted, releaseFirst));
    final second = queue.enqueue(
      'second',
      () => run(secondStarted, releaseSecond),
    );
    final third = queue.enqueue('third', () => run(thirdStarted, releaseThird));

    await Future.wait([firstStarted.future, secondStarted.future]);
    expect(thirdStarted.isCompleted, isFalse);
    releaseFirst.complete();
    await thirdStarted.future;
    expect(peakActive, 2);
    releaseSecond.complete();
    releaseThird.complete();
    await Future.wait([first, second, third]);
    expect(queue.activeCount, 0);
  });
}
