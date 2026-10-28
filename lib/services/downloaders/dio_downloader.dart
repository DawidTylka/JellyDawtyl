import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'base_downloader.dart';

class DioDownloader implements BaseDownloader {
  DioDownloader({Dio? dio, Future<void> Function(Duration)? wait})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 30))),
      _wait = wait ?? Future<void>.delayed;

  final Dio _dio;
  final Future<void> Function(Duration) _wait;

  @override
  Future<String?> downloadVideo({
    required String itemId,
    required String downloadUrl,
    required String saveDir,
    required String fileName,
    required String token,
    required bool wifiOnly,
    required bool showNotification,
    required Function(String, double, String) onProgress,
    required Function(String) onFinished,
    required Future<void> Function(String) onFailed,
  }) async {
    final fullPath = '$saveDir/$fileName';
    final temporaryPath = '$fullPath.part';
    onProgress(itemId, 0.0, 'Start...');

    for (var attempt = 1; ; attempt++) {
      try {
        if (wifiOnly) {
          final connectivity = await Connectivity().checkConnectivity();
          if (!connectivity.contains(ConnectivityResult.wifi)) {
            throw StateError('Połączenie Wi-Fi jest wymagane do pobierania.');
          }
        }

        final partial = File(temporaryPath);
        if (await partial.exists()) await partial.delete();

        final response = await _dio.download(
          downloadUrl,
          temporaryPath,
          deleteOnError: true,
          options: Options(
            headers: {'X-Emby-Token': token},
            receiveTimeout: const Duration(minutes: 30),
          ),
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final progress = received / total;
              onProgress(
                itemId,
                progress,
                '${(progress * 100).toStringAsFixed(0)}%',
              );
            } else {
              final mb = received / (1024 * 1024);
              onProgress(itemId, -1, '${mb.toStringAsFixed(1)} MB');
            }
          },
        );

        final result = File(temporaryPath);
        if (!await result.exists() || await result.length() == 0) {
          throw const FileSystemException('Pobrany plik jest pusty.');
        }
        final expectedLength = int.tryParse(
          response.headers.value(Headers.contentLengthHeader) ?? '',
        );
        if (expectedLength != null && await result.length() != expectedLength) {
          throw StateError('Pobrany plik jest niekompletny.');
        }
        final destination = File(fullPath);
        if (await destination.exists()) await destination.delete();
        await result.rename(fullPath);
        onFinished(itemId);
        return null;
      } catch (e) {
        // Dio exceptions include the full request URL and headers; keep them
        // out of logs because either can contain credentials.
        debugPrint('Błąd pobierania Dio (próba $attempt, ${e.runtimeType}).');
        final partial = File(temporaryPath);
        if (await partial.exists()) await partial.delete();
        final status = e is DioException ? e.response?.statusCode : null;
        final permanentHttpError =
            status != null &&
            status >= 400 &&
            status < 500 &&
            status != 408 &&
            status != 429;
        if (e is FileSystemException ||
            (e is DioException && e.error is FileSystemException) ||
            permanentHttpError) {
          onProgress(
            itemId,
            0,
            'Pobieranie nie powiodło się — spróbuj ponownie',
          );
          await onFailed(itemId);
          return null;
        }
        onProgress(itemId, -1, 'Oczekiwanie na połączenie — ponawianie...');
        await _wait(
          Duration(
            seconds: (2 * (1 << (attempt - 1).clamp(0, 6))).clamp(2, 120),
          ),
        );
      }
    }
  }
}
