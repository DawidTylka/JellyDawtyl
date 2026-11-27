import 'package:flutter_test/flutter_test.dart';
import 'package:jellydawtyl/models/episode.dart';
import 'package:jellydawtyl/models/movie.dart';
import 'package:jellydawtyl/services/download_service.dart';

void main() {
  final service = DownloadService();

  test('two movies with the same title get different files', () {
    final a = service.generatePathsForTest(
      Movie(id: 'aaa', name: 'Ślepnąc od świateł', type: 'Movie'),
      null,
      '720p',
    );
    final b = service.generatePathsForTest(
      Movie(id: 'bbb', name: 'Ślepnąc od świateł', type: 'Movie'),
      null,
      '720p',
    );
    expect(a['folder'], 'Ślepnąc od świateł');
    expect(a['file'], isNot(b['file']));
    expect(a['file'], 'Ślepnąc od świateł_aaa_720p.mp4');
  });

  test('non-Latin and symbol-only titles keep a usable folder', () {
    final cjk = service.generatePathsForTest(
      Episode.fromJson({
        'Id': 'ep1',
        'Name': '第1話',
        'Type': 'Episode',
        'SeriesName': '進撃の巨人',
        'SeriesId': 'series1',
        'ParentIndexNumber': 1,
        'IndexNumber': 2,
      }),
      null,
      'original',
    );
    expect(cjk['folder'], '進撃の巨人');
    expect(cjk['file'], '進撃の巨人_S001E002_ep1_original.mp4');

    final symbols = service.generatePathsForTest(
      Movie(id: 'm1', name: '???', type: 'Movie'),
      null,
      '480p',
    );
    expect(symbols['folder'], 'm1');
  });
}
