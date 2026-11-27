/// A skippable part of a video, as reported by `/MediaSegments/{id}`
/// (Jellyfin 10.10+, filled e.g. by the Intro Skipper plugin).
enum MediaSegmentType { intro, outro, recap, preview, commercial }

class MediaSegment {
  final MediaSegmentType type;
  final Duration start;
  final Duration end;

  const MediaSegment({
    required this.type,
    required this.start,
    required this.end,
  });

  static MediaSegment? fromJson(Map<String, dynamic> json) {
    final type = switch (json['Type']?.toString().toLowerCase()) {
      'intro' => MediaSegmentType.intro,
      'outro' => MediaSegmentType.outro,
      'recap' => MediaSegmentType.recap,
      'preview' => MediaSegmentType.preview,
      'commercial' => MediaSegmentType.commercial,
      _ => null,
    };
    final startTicks = json['StartTicks'];
    final endTicks = json['EndTicks'];
    if (type == null || startTicks is! num || endTicks is! num) return null;
    if (endTicks <= startTicks) return null;
    return MediaSegment(
      type: type,
      start: Duration(microseconds: startTicks ~/ 10),
      end: Duration(microseconds: endTicks ~/ 10),
    );
  }

  /// Parses a list of raw segments, skipping unknown types and bad ranges.
  static List<MediaSegment> listFromJson(Object? json) {
    if (json is! List) return const [];
    final segments = json
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => MediaSegment.fromJson(Map<String, dynamic>.from(item)))
        .whereType<MediaSegment>()
        .toList();
    segments.sort((a, b) => a.start.compareTo(b.start));
    return segments;
  }

  bool contains(Duration position) => position >= start && position < end;

  /// Intro and recap are skipped automatically with "auto-skip intro";
  /// credits with "auto-skip credits". Previews and commercials only show
  /// the button.
  bool get isIntroLike =>
      type == MediaSegmentType.intro || type == MediaSegmentType.recap;
}

/// The segment playing at [position], ignoring ones shorter than [minLength]
/// (very short segments are usually detection noise) and the last moment
/// before a segment ends, so the button does not flash at its end.
MediaSegment? activeSegmentAt(
  List<MediaSegment> segments,
  Duration position, {
  Duration minLength = const Duration(seconds: 2),
  Duration tail = const Duration(milliseconds: 500),
}) {
  for (final segment in segments) {
    if (segment.end - segment.start < minLength) continue;
    if (position >= segment.start && position < segment.end - tail) {
      return segment;
    }
  }
  return null;
}
