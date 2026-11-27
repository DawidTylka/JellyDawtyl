import 'package:flutter_test/flutter_test.dart';
import 'package:jellydawtyl/services/unwanted_api.dart';

void main() {
  group('UnwantedStatus', () {
    test('parses an episode resolved to its series', () {
      final status = UnwantedStatus.fromJson({
        'ItemId': 'ep1',
        'TargetId': 'series1',
        'TargetName': 'Serial',
        'TargetType': 'Series',
        'Unwanted': false,
        'Snoozed': true,
        'SnoozeUntilUtc': '2026-12-01T10:00:00Z',
        'UntilNewEpisode': true,
        'WatchLater': true,
      });
      expect(status.targetId, 'series1');
      expect(status.canSnooze, isTrue);
      expect(status.snoozed, isTrue);
      expect(status.untilNewEpisode, isTrue);
      expect(status.watchLater, isTrue);
      expect(status.snoozeUntil?.toUtc(), DateTime.utc(2026, 12, 1, 10));
    });

    test('movies cannot be snoozed', () {
      final status = UnwantedStatus.fromJson({
        'ItemId': 'm1',
        'TargetType': 'Movie',
      });
      expect(status.targetId, 'm1');
      expect(status.canSnooze, isFalse);
    });
  });

  group('UnwantedListEntry', () {
    test('accepts the kind as a string or a number', () {
      final fromString = UnwantedListEntry.fromJson({
        'ItemId': 'a',
        'Name': 'A',
        'Kind': 'WatchLater',
      });
      final fromNumber = UnwantedListEntry.fromJson({
        'ItemId': 'b',
        'Name': 'B',
        'Kind': 1,
      });
      expect(fromString?.kind, UnwantedListKind.watchLater);
      expect(fromNumber?.kind, UnwantedListKind.snoozed);
    });

    test('skips entries with an unknown kind', () {
      expect(
        UnwantedListEntry.fromJson({'ItemId': 'x', 'Kind': 'Other'}),
        isNull,
      );
    });
  });
}
