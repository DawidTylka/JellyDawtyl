import 'package:flutter_test/flutter_test.dart';
import 'package:jellydawtyl/models/media_segment.dart';
import 'package:jellydawtyl/services/jellyfin_api.dart';

void main() {
  test('parses /MediaSegments items and skips unknown or broken ones', () {
    final segments = MediaSegment.listFromJson([
      {'Type': 'Outro', 'StartTicks': 13000000000, 'EndTicks': 14000000000},
      {'Type': 'Intro', 'StartTicks': 600000000, 'EndTicks': 1500000000},
      {'Type': 'Unknown', 'StartTicks': 0, 'EndTicks': 10},
      {'Type': 'Recap', 'StartTicks': 50, 'EndTicks': 10},
      'not a map',
    ]);
    expect(segments.map((s) => s.type), [
      MediaSegmentType.intro,
      MediaSegmentType.outro,
    ]);
    expect(segments.first.start, const Duration(seconds: 60));
    expect(segments.first.end, const Duration(seconds: 150));
  });

  test('converts the legacy Intro Skipper answer', () {
    final raw = JellyfinApi.introSkipperToMediaSegments({
      'Introduction': {
        'EpisodeId': 'x',
        'Valid': true,
        'IntroStart': 12.5,
        'IntroEnd': 95,
      },
      'Credits': {'Valid': false, 'IntroStart': 1300, 'IntroEnd': 1400},
      'Recap': {'Start': 0, 'End': 30},
    });
    final segments = MediaSegment.listFromJson(raw);
    expect(segments.map((s) => s.type), [
      MediaSegmentType.recap,
      MediaSegmentType.intro,
    ]);
    expect(segments[1].start, const Duration(milliseconds: 12500));
    expect(segments[1].end, const Duration(seconds: 95));
  });

  test('activeSegmentAt ignores short segments and the last moment', () {
    const intro = MediaSegment(
      type: MediaSegmentType.intro,
      start: Duration(seconds: 10),
      end: Duration(seconds: 40),
    );
    const blip = MediaSegment(
      type: MediaSegmentType.preview,
      start: Duration(seconds: 100),
      end: Duration(milliseconds: 101000),
    );
    const segments = [intro, blip];
    expect(activeSegmentAt(segments, const Duration(seconds: 9)), isNull);
    expect(activeSegmentAt(segments, const Duration(seconds: 10)), intro);
    expect(
      activeSegmentAt(segments, const Duration(milliseconds: 39800)),
      isNull,
    );
    expect(
      activeSegmentAt(segments, const Duration(milliseconds: 100500)),
      isNull,
    );
  });
}
