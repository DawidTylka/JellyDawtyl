/// A downloaded video file with its metadata sidecar (may be empty).
class OfflineEpisodeFile {
  final String path;
  final Map<String, dynamic> metadata;
  const OfflineEpisodeFile({required this.path, required this.metadata});
}

const _qualityPreference = [
  'original',
  '1080p',
  '720p',
  '480p',
  '360p',
  '144p',
];

int _qualityRank(String fileName) {
  final match = RegExp(
    r'_([0-9]+p|original)\.[a-z0-9]+$',
    caseSensitive: false,
  ).firstMatch(fileName);
  final rank = match == null
      ? -1
      : _qualityPreference.indexOf(match.group(1)!.toLowerCase());
  return rank < 0 ? _qualityPreference.length : rank;
}

/// Builds the offline episode list of one folder: one entry per episode,
/// sorted by season and episode number.
///
/// Files are grouped by the item `Id` from the sidecar, or by the
/// `_S001E002_` part of the file name when there is no sidecar. From a group
/// the file being played is kept; otherwise the best quality.
List<Map<String, dynamic>> buildOfflineEpisodeList(
  List<OfflineEpisodeFile> files, {
  required String currentPath,
  String pathSeparator = '/',
}) {
  final groups = <String, List<Map<String, dynamic>>>{};
  final sorted = [...files]
    ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

  for (var i = 0; i < sorted.length; i++) {
    final file = sorted[i];
    final fileName = file.path.split(pathSeparator).last;
    final match = RegExp(r'_S(\d+)E(\d+)_').firstMatch(fileName);
    final metadata = file.metadata;
    final season =
        metadata['ParentIndexNumber'] ??
        (match != null ? int.parse(match.group(1)!) : 1);
    final episode =
        metadata['IndexNumber'] ??
        (match != null ? int.parse(match.group(2)!) : i + 1);
    final id = (metadata['Id'] as String?) ?? '';
    final key = id.isNotEmpty
        ? 'id:$id'
        : (match != null ? 'se:$season:$episode' : 'file:${file.path}');
    final title = fileName
        .replaceAll(RegExp(r'\.(mp4|mkv|m4v|avi)$', caseSensitive: false), '')
        .replaceAll('_', ' ');
    groups.putIfAbsent(key, () => []).add({
      ...metadata,
      'Id': id,
      'Name': metadata['Name'] ?? title,
      'IndexNumber': episode,
      'ParentIndexNumber': season,
      'Path': file.path,
    });
  }

  final result = groups.values.map((group) {
    final current = group.where((e) => e['Path'] == currentPath).firstOrNull;
    if (current != null) return current;
    group.sort(
      (a, b) => _qualityRank((a['Path'] as String).split(pathSeparator).last)
          .compareTo(
            _qualityRank((b['Path'] as String).split(pathSeparator).last),
          ),
    );
    return group.first;
  }).toList();

  result.sort((a, b) {
    final bySeason = ((a['ParentIndexNumber'] as num?) ?? 0).compareTo(
      (b['ParentIndexNumber'] as num?) ?? 0,
    );
    if (bySeason != 0) return bySeason;
    final byEpisode = ((a['IndexNumber'] as num?) ?? 0).compareTo(
      (b['IndexNumber'] as num?) ?? 0,
    );
    if (byEpisode != 0) return byEpisode;
    return (a['Path'] as String).compareTo(b['Path'] as String);
  });
  return result;
}
