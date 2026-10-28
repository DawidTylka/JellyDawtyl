import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/pending_playback_changes.dart';

void main() {
  test(
    'retains a watched update until progress and watched status both succeed',
    () async {
      final pending = <String, Map<String, dynamic>>{
        'episode-1': {
          'itemId': 'episode-1',
          'positionMs': 95000,
          'played': true,
          'stopped': true,
        },
      };
      var progressCalls = 0;
      var watchedCalls = 0;
      var saves = 0;

      await flushPendingPlaybackChanges(
        pending: pending,
        synchronize: (change) => synchronizePlaybackChange(
          change: change,
          reportProgress: () async {
            progressCalls++;
            return true;
          },
          markPlayed: () async {
            watchedCalls++;
            return false;
          },
        ),
        save: () async => saves++,
      );

      expect(pending, contains('episode-1'));
      expect(progressCalls, 1);
      expect(watchedCalls, 1);
      expect(saves, 0);

      await flushPendingPlaybackChanges(
        pending: pending,
        synchronize: (change) => synchronizePlaybackChange(
          change: change,
          reportProgress: () async => true,
          markPlayed: () async => true,
        ),
        save: () async => saves++,
      );

      expect(pending, isEmpty);
      expect(saves, 1);
    },
  );

  test(
    'does not send watched status if saving playback progress fails',
    () async {
      var watchedCalls = 0;
      final synchronized = await synchronizePlaybackChange(
        change: {'itemId': 'episode-2', 'played': true},
        reportProgress: () async => false,
        markPlayed: () async {
          watchedCalls++;
          return true;
        },
      );

      expect(synchronized, isFalse);
      expect(watchedCalls, 0);
    },
  );

  test(
    'leaves a thrown synchronization in the queue and continues other items',
    () async {
      final pending = <String, Map<String, dynamic>>{
        'broken': {'itemId': 'broken'},
        'good': {'itemId': 'good'},
      };

      await flushPendingPlaybackChanges(
        pending: pending,
        synchronize: (change) async {
          if (change['itemId'] == 'broken') throw StateError('offline');
          return true;
        },
        save: () async {},
      );

      expect(pending.keys, ['broken']);
    },
  );
}
