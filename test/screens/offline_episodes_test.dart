import 'package:flutter_test/flutter_test.dart';
import 'package:jellydawtyl/screens/player/offline_episodes.dart';

void main() {
  OfflineEpisodeFile file(String name, [Map<String, dynamic>? meta]) =>
      OfflineEpisodeFile(path: '/d/$name', metadata: meta ?? {});

  test('an episode downloaded in two qualities appears once', () {
    final list = buildOfflineEpisodeList([
      file('Show_S001E001_a_720p.mp4', {'Id': 'a', 'IndexNumber': 1}),
      file('Show_S001E001_a_original.mp4', {'Id': 'a', 'IndexNumber': 1}),
      file('Show_S001E002_b_720p.mp4', {'Id': 'b', 'IndexNumber': 2}),
    ], currentPath: '/d/Show_S001E001_a_720p.mp4');
    expect(list.map((e) => e['Path']), [
      '/d/Show_S001E001_a_720p.mp4', // the file being played is kept
      '/d/Show_S001E002_b_720p.mp4',
    ]);
  });

  test('without sidecars files are grouped by season and episode', () {
    final list = buildOfflineEpisodeList([
      file('Show_S001E002_480p.mp4'),
      file('Show_S001E002_1080p.mp4'),
      file('Show_S002E001_480p.mp4'),
      file('Show_S001E001_480p.mp4'),
    ], currentPath: '/d/Show_S002E001_480p.mp4');
    expect(list.map((e) => e['Path']), [
      '/d/Show_S001E001_480p.mp4',
      '/d/Show_S001E002_1080p.mp4', // best quality of the group
      '/d/Show_S002E001_480p.mp4',
    ]);
  });
}
