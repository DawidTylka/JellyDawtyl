import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellydawtyl/services/downloaders/dio_downloader.dart';

void main() {
  late Directory directory;
  late HttpServer server;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('resume_test_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });
  tearDown(() async {
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  test('only original-quality URLs are resumable', () {
    expect(DioDownloader.isResumableUrl('http://h/v.mp4?Static=true'), isTrue);
    expect(
      DioDownloader.isResumableUrl('http://h/v.mp4?Static=false&MaxWidth=1'),
      isFalse,
    );
  });

  test('an interrupted original download continues with Range', () async {
    final payload = List<int>.generate(20000, (i) => i % 251);
    final ranges = <String?>[];
    final ifRanges = <String?>[];
    // Raw sockets, so the first response can be cut off mid-body.
    final raw = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(raw.close);
    raw.listen((socket) {
      final buffer = <int>[];
      var answered = false;
      socket.listen((data) async {
        buffer.addAll(data);
        final text = String.fromCharCodes(buffer);
        if (answered || !text.contains('\r\n\r\n')) return;
        answered = true;
        final match = RegExp(
          r'^range: bytes=(\d+)-',
          caseSensitive: false,
          multiLine: true,
        ).firstMatch(text);
        ranges.add(match?.group(0));
        ifRanges.add(
          RegExp(
            r'^if-range: (.+)$',
            caseSensitive: false,
            multiLine: true,
          ).firstMatch(text)?.group(1)?.trim(),
        );
        if (match == null) {
          socket.add(
            'HTTP/1.1 200 OK\r\nETag: "v1"\r\n'
                    'Content-Length: ${payload.length}\r\n\r\n'
                .codeUnits,
          );
          socket.add(payload.sublist(0, 10000));
          await socket.flush();
          socket.destroy();
          return;
        }
        final start = int.parse(match.group(1)!);
        socket.add(
          ('HTTP/1.1 206 Partial Content\r\n'
                  'Content-Range: bytes $start-${payload.length - 1}/${payload.length}\r\n'
                  'Content-Length: ${payload.length - start}\r\n'
                  'Connection: close\r\n\r\n')
              .codeUnits,
        );
        socket.add(payload.sublist(start));
        await socket.flush();
        await socket.close();
      });
    });
    final port = raw.port;

    var finished = 0;
    var failed = 0;
    final target = File('${directory.path}/video.mp4');
    await DioDownloader(wait: (_) async {})
        .downloadVideo(
          itemId: 'item',
          downloadUrl: 'http://127.0.0.1:$port/video?Static=true',
          saveDir: directory.path,
          fileName: 'video.mp4',
          token: 'test',
          wifiOnly: false,
          showNotification: false,
          onProgress: (_, _, _) {},
          onFinished: (_) => finished++,
          onFailed: (_) async => failed++,
        )
        .timeout(const Duration(seconds: 10));

    expect(finished, 1);
    expect(failed, 0);
    expect(ranges.first, isNull);
    expect(ranges.last, isNotNull);
    expect(ranges.last, isNot(contains('bytes=0-')));
    // The resume is tied to the file version the partial data came from.
    expect(ifRanges.last, '"v1"');
    expect(target.readAsBytesSync(), payload);
    expect(File('${target.path}.part').existsSync(), isFalse);
    expect(File('${target.path}.part.validator').existsSync(), isFalse);
  });
}
