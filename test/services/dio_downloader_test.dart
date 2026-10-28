import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/downloaders/dio_downloader.dart';

void main() {
  late Directory directory;
  late HttpServer server;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('download_test_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });
  tearDown(() async {
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  test(
    'retries temporary errors beyond the old limit and publishes only the complete file',
    () async {
      var requests = 0;
      var finished = 0;
      var failed = 0;
      final payload = List<int>.generate(32768, (i) => i % 256);
      server.listen((request) async {
        requests++;
        if (requests <= 4) {
          request.response.statusCode = 503;
        } else {
          request.response.contentLength = payload.length;
          request.response.add(payload);
        }
        await request.response.close();
      });
      final target = File('${directory.path}/video.mp4');
      await DioDownloader(wait: (_) async {})
          .downloadVideo(
            itemId: 'item',
            downloadUrl: 'http://127.0.0.1:${server.port}/video',
            saveDir: directory.path,
            fileName: 'video.mp4',
            token: 'test',
            wifiOnly: false,
            showNotification: false,
            onProgress: (_, _, _) => expect(target.existsSync(), isFalse),
            onFinished: (_) {
              finished++;
              expect(target.readAsBytesSync(), payload);
            },
            onFailed: (_) async {
              failed++;
            },
          )
          .timeout(const Duration(seconds: 10));
      expect(requests, 5);
      expect(finished, 1);
      expect(failed, 0);
      expect(File('${target.path}.part').existsSync(), isFalse);
    },
  );

  test(
    'a disconnected response is retried without exposing the truncated movie',
    () async {
      final rawServer = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      var requests = 0;
      final sockets = <Socket>[];
      final payload = List<int>.filled(1024, 65);
      rawServer.listen((socket) {
        sockets.add(socket);
        var answered = false;
        socket.listen((_) async {
          if (answered) return;
          answered = true;
          requests++;
          socket.add(
            ascii.encode(
              'HTTP/1.1 200 OK\r\nContent-Length: 1024\r\nConnection: close\r\n\r\n',
            ),
          );
          socket.add(requests == 1 ? payload.sublist(0, 50) : payload);
          await socket.flush();
          socket.destroy();
        });
      });
      var finished = 0;
      try {
        await DioDownloader(wait: (_) async {})
            .downloadVideo(
              itemId: 'item',
              downloadUrl: 'http://127.0.0.1:${rawServer.port}/video',
              saveDir: directory.path,
              fileName: 'video.mp4',
              token: 'test',
              wifiOnly: false,
              showNotification: false,
              onProgress: (_, _, _) => expect(
                File('${directory.path}/video.mp4').existsSync(),
                isFalse,
              ),
              onFinished: (_) {
                finished++;
              },
              onFailed: (_) async {
                fail('Unexpected failure');
              },
            )
            .timeout(const Duration(seconds: 10));
        expect(requests, 2);
        expect(finished, 1);
        expect(File('${directory.path}/video.mp4').readAsBytesSync(), payload);
      } finally {
        for (final socket in sockets) {
          socket.destroy();
        }
        await rawServer.close();
      }
    },
  );

  test(
    'permanent HTTP errors stay failed and never publish a partial file',
    () async {
      var finished = false;
      var failures = 0;
      server.listen((request) async {
        request.response.statusCode = 403;
        await request.response.close();
      });
      await DioDownloader(wait: (_) async {})
          .downloadVideo(
            itemId: 'item',
            downloadUrl: 'http://127.0.0.1:${server.port}/video',
            saveDir: directory.path,
            fileName: 'video.mp4',
            token: 'test',
            wifiOnly: false,
            showNotification: false,
            onProgress: (_, _, _) {},
            onFinished: (_) {
              finished = true;
            },
            onFailed: (_) async {
              failures++;
            },
          )
          .timeout(const Duration(seconds: 10));
      expect(finished, isFalse);
      expect(failures, 1);
      expect(directory.listSync(), isEmpty);
    },
  );
}
