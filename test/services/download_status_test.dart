import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_application_1/services/download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final service = DownloadService();
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('download_status_');
    FlutterSecureStorage.setMockInitialValues({
      'setting_download_path': directory.path,
    });
    await Directory('${directory.path}/JellyDawtyl').create();
    service.activeDownloads.value = {};
  });
  tearDown(() async {
    service.activeDownloads.value = {};
    await directory.delete(recursive: true);
  });

  test(
    'an active transfer takes precedence over an existing legacy partial file',
    () async {
      await File(
        '${directory.path}/JellyDawtyl/video.mp4',
      ).writeAsBytes([1, 2]);
      service.activeDownloads.value = {
        'item': DownloadStatus(progressValue: .5),
      };
      final status = await service.checkStatus('item', 'video.mp4');
      expect(status.isDownloaded, isFalse);
      expect(status.progressValue, .5);
    },
  );
  test('temporary and empty files are never downloaded videos', () async {
    await File(
      '${directory.path}/JellyDawtyl/video.mp4.part',
    ).writeAsBytes([1, 2]);
    expect(
      (await service.checkStatus('item', 'video.mp4')).isDownloaded,
      isFalse,
    );
    await File('${directory.path}/JellyDawtyl/video.mp4').create();
    expect(
      (await service.checkStatus('item', 'video.mp4')).isDownloaded,
      isFalse,
    );
  });
  test('a published nonempty file can be found offline', () async {
    await File('${directory.path}/JellyDawtyl/video.mp4').writeAsBytes([1, 2]);
    final status = await service.checkStatus('item', 'video.mp4');
    expect(status.isDownloaded, isTrue);
    expect(status.filePath, endsWith('video.mp4'));
  });
}
