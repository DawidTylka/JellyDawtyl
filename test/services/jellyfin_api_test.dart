import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellydawtyl/services/jellyfin_api.dart';

void main() {
  late HttpServer server;
  late String baseUrl;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';
  });
  tearDown(() => server.close(force: true));

  test('an expired token is reported apart from other errors', () async {
    server.listen((request) async {
      request.response.statusCode = 401;
      await request.response.close();
    });
    await expectLater(
      JellyfinApi().fetchUserLibrariesOrThrow(baseUrl, 'token', 'user'),
      throwsA(isA<JellyfinUnauthorizedException>()),
    );
  });

  test('an unreachable server is reported as such', () async {
    final port = server.port;
    await server.close(force: true);
    await expectLater(
      JellyfinApi().fetchUserLibrariesOrThrow(
        'http://127.0.0.1:$port',
        'token',
        'user',
      ),
      throwsA(isA<JellyfinUnreachableException>()),
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });

  test('libraries are returned on success', () async {
    server.listen((request) async {
      expect(request.uri.path, '/UserViews');
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        '{"Items":[{"Id":"1","Name":"Filmy","CollectionType":"movies"},'
        '{"Id":"2","Name":"Muzyka","CollectionType":"music"}]}',
      );
      await request.response.close();
    });
    final libraries = await JellyfinApi().fetchUserLibrariesOrThrow(
      baseUrl,
      'token',
      'user',
    );
    expect(libraries.map((l) => l.id), ['1']);
  });

  test('login failures are classified for the login screen', () {
    final options = RequestOptions(path: '/');
    expect(
      JellyfinApi.classifyLoginError(
        DioException.badResponse(
          statusCode: 401,
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 401),
        ),
      ),
      LoginFailure.invalidCredentials,
    );
    expect(
      JellyfinApi.classifyLoginError(
        DioException.connectionError(requestOptions: options, reason: 'x'),
      ),
      LoginFailure.unreachable,
    );
    expect(
      JellyfinApi.classifyLoginError(
        DioException.badCertificate(requestOptions: options),
      ),
      LoginFailure.certificate,
    );
  });
}
