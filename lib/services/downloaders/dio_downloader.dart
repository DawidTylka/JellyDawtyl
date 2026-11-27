import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'base_downloader.dart';
import '../../utils/jellyfin_auth.dart';

class DioDownloader implements BaseDownloader {
  DioDownloader({
    Dio? dio,
    Future<void> Function(Duration)? wait,
    CancelToken? cancelToken,
  }) : _dio =
           dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 30))),
       _wait = wait ?? Future<void>.delayed,
       _cancelToken = cancelToken;

  final Dio _dio;
  final Future<void> Function(Duration) _wait;
  final CancelToken? _cancelToken;

  bool get _isCancelled => _cancelToken?.isCancelled ?? false;

  @visibleForTesting
  static bool isResumableUrl(String url) =>
      Uri.tryParse(url)?.queryParameters['Static']?.toLowerCase() == 'true';

  /// Downloads [url] into [temporaryPath], continuing an existing partial
  /// file with `Range` when the server answers 206. Throws when the result
  /// is shorter than the server announced.
  Future<void> _downloadResumable({
    required String itemId,
    required String url,
    required String temporaryPath,
    required String token,
    required Function(String, double, String) onProgress,
  }) async {
    final partial = File(temporaryPath);
    // The partial file is only continued when the server confirms, through
    // If-Range, that the file has not changed since it was started.
    final validatorFile = File('$temporaryPath.validator');
    final validator = await validatorFile.exists()
        ? (await validatorFile.readAsString()).trim()
        : '';
    final offset = validator.isNotEmpty && await partial.exists()
        ? await partial.length()
        : 0;
    final response = await _dio.get<ResponseBody>(
      url,
      cancelToken: _cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(minutes: 30),
        headers: {
          ...jellyfinAuthHeaders(token),
          if (offset > 0) ...{'Range': 'bytes=$offset-', 'If-Range': validator},
        },
      ),
    );
    final body = response.data!;
    final append = offset > 0 && response.statusCode == 206;
    int? total;
    if (append) {
      final range = response.headers.value('content-range') ?? '';
      total = int.tryParse(range.split('/').last);
    } else {
      final length = int.tryParse(
        response.headers.value(Headers.contentLengthHeader) ?? '',
      );
      total = length;
    }
    if (!append) {
      final newValidator =
          response.headers.value('etag') ??
          response.headers.value('last-modified');
      if (newValidator != null) {
        await validatorFile.writeAsString(newValidator);
      } else if (await validatorFile.exists()) {
        await validatorFile.delete();
      }
    }
    var received = append ? offset : 0;
    final sink = partial.openWrite(
      mode: append ? FileMode.append : FileMode.write,
    );
    try {
      await for (final chunk in body.stream) {
        if (_isCancelled) {
          throw DioException.requestCancelled(
            requestOptions: response.requestOptions,
            reason: 'cancelled',
          );
        }
        sink.add(chunk);
        received += chunk.length;
        if (total != null && total > 0) {
          final progress = received / total;
          onProgress(
            itemId,
            progress,
            '${(progress * 100).toStringAsFixed(0)}%',
          );
        } else {
          onProgress(
            itemId,
            -1,
            '${(received / (1024 * 1024)).toStringAsFixed(1)} MB',
          );
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    final length = await partial.length();
    if (length == 0) {
      throw const FileSystemException('Pobrany plik jest pusty.');
    }
    if (total != null && length != total) {
      throw StateError('Pobrany plik jest niekompletny.');
    }
  }

  static Future<void> _deleteIfExists(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

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
    // The original file (Static=true) is served with Range support, so an
    // interrupted transfer continues from the bytes already saved. A
    // transcoded stream has no stable length and always starts over.
    final resumable = isResumableUrl(downloadUrl);
    onProgress(itemId, 0.0, 'Start...');

    for (var attempt = 1; ; attempt++) {
      // A cancelled download ends quietly: it is not reported as failed.
      if (_isCancelled) return null;
      try {
        if (wifiOnly) {
          final connectivity = await Connectivity().checkConnectivity();
          if (!connectivity.contains(ConnectivityResult.wifi)) {
            throw StateError('Połączenie Wi-Fi jest wymagane do pobierania.');
          }
        }

        if (resumable) {
          await _downloadResumable(
            itemId: itemId,
            url: downloadUrl,
            temporaryPath: temporaryPath,
            token: token,
            onProgress: onProgress,
          );
          final destination = File(fullPath);
          if (await destination.exists()) await destination.delete();
          await File(temporaryPath).rename(fullPath);
          await _deleteIfExists('$temporaryPath.validator');
          onFinished(itemId);
          return null;
        }

        final partial = File(temporaryPath);
        if (await partial.exists()) await partial.delete();

        final response = await _dio.download(
          downloadUrl,
          temporaryPath,
          deleteOnError: true,
          cancelToken: _cancelToken,
          options: Options(
            headers: jellyfinAuthHeaders(token),
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
        final status = e is DioException ? e.response?.statusCode : null;
        final permanentHttpError =
            status != null &&
            status >= 400 &&
            status < 500 &&
            status != 408 &&
            status != 416 && // stale partial file: start over
            status != 429;
        final partial = File(temporaryPath);
        // Keep a resumable partial file for the next attempt; it is removed
        // only when the download is cancelled or fails for good.
        final diskError =
            e is FileSystemException ||
            (e is DioException && e.error is FileSystemException);
        final keepPartial =
            resumable &&
            !_isCancelled &&
            !permanentHttpError &&
            !diskError &&
            status != 416;
        if (!keepPartial) {
          if (await partial.exists()) await partial.delete();
          await _deleteIfExists('$temporaryPath.validator');
        }
        if (_isCancelled) return null;
        if (diskError || permanentHttpError) {
          onProgress(
            itemId,
            0,
            'Pobieranie nie powiodło się — spróbuj ponownie',
          );
          await onFailed(itemId);
          return null;
        }
        onProgress(itemId, -1, 'Oczekiwanie na połączenie — ponawianie...');
        final delay = _wait(
          Duration(
            seconds: (2 * (1 << (attempt - 1).clamp(0, 6))).clamp(2, 120),
          ),
        );
        final cancelToken = _cancelToken;
        await (cancelToken == null
            ? delay
            : Future.any<void>([delay, cancelToken.whenCancel.then((_) {})]));
      }
    }
  }
}
