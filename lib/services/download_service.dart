import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/jellyfin_item.dart';
import 'jellyfin_api.dart';
import 'storage_service.dart';

import 'downloaders/base_downloader.dart';
import 'downloaders/dio_downloader.dart';
import 'downloaders/native_downloader.dart';

import 'dart:async';

class DownloadStatus {
  final double progressValue;
  final String progressText;
  final bool isDownloaded;
  final bool isQueued;
  final String? filePath;

  DownloadStatus({
    this.progressValue = 0.0,
    this.progressText = "",
    this.isDownloaded = false,
    this.isQueued = false,
    this.filePath,
  });
}

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  static final List<Future<void> Function()> _queue = [];
  static int _activeCount = 0;
  static bool _isProcessing = false;
  static Timer? _debounceTimer;
  final StorageService _storage = StorageService();
  final ValueNotifier<Map<String, DownloadStatus>> activeDownloads =
      ValueNotifier({});

  Future<BaseDownloader> _getDownloaderInstance() async {
    bool useNative = await _storage.getSetting(
      'setting_native_downloader',
      defaultValue: false,
    );

    if (useNative && Platform.isAndroid) {
      return NativeDownloader();
    } else {
      return DioDownloader();
    }
  }

  void _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      int maxConcurrent = await _storage.getInt('setting_max_concurrent_downloads', defaultValue: 1);

      while (_queue.isNotEmpty && _activeCount < maxConcurrent) {
        final Future<void> Function() task = _queue.removeAt(0);

        _activeCount++;

        debugPrint("Startuję zadanie. Aktywne: $_activeCount / $maxConcurrent");

        task().whenComplete(() {
          _activeCount--;
          debugPrint("Zakończono zadanie. Pozostało aktywnych: $_activeCount");
          _processQueue();
        });
      }
    } catch (e) {
      debugPrint("Błąd kolejki: $e");
    } finally {
      _isProcessing = false;
    }
  }

  Future<String> getDirectoryPath() async {
    final customPath = await _storage.getString('setting_download_path');

    if (customPath != null && customPath.isNotEmpty) {
      return "$customPath/JellyDawtyl";
    }

    if (Platform.isAndroid) {
      return "/storage/emulated/0/Download/JellyDawtyl";
    } else if (Platform.isWindows) {
      final directory = await getApplicationSupportDirectory();
      return "${directory.path}\\JellyDawtyl";
    }

    return "";
  }

  Future<DownloadStatus> checkStatus(
    String uniqueId,
    String relativePath,
  ) async {
    String dirPath = await getDirectoryPath();
    if (dirPath.isEmpty) return DownloadStatus();

    String fullPath = "$dirPath/$relativePath";
    if (File(fullPath).existsSync()) {
      return DownloadStatus(isDownloaded: true, filePath: fullPath);
    }
    return activeDownloads.value[uniqueId] ?? DownloadStatus();
  }

  Map<String, String> _generatePaths(
    JellyfinItem item,
    String? seriesOverrideName,
    String qualityLabel,
  ) {
    final bool isEpisode = item.type == "Episode";
    String folderBaseName =
        seriesOverrideName ??
        (isEpisode ? (item.seriesName ?? item.name) : item.name);
    String safeFolder = folderBaseName.replaceAll(RegExp(r'[^\w\s]+'), '');
    String fileName = isEpisode
        ? "${safeFolder}_S${item.parentIndexNumber.toString().padLeft(3, '0')}E${item.indexNumber.toString().padLeft(3, '0')}_$qualityLabel.mp4"
        : "${safeFolder}_$qualityLabel.mp4";
    return {"folder": safeFolder, "file": fileName};
  }

  Future<void> startDownload({
    required JellyfinItem item,
    required String baseUrl,
    required String token,
    int? maxWidth,
    int? bitrate,
    required String qualityLabel,
    String? seriesOverrideName,
  }) async {
    final String itemId = item.id;
    if (activeDownloads.value.containsKey(itemId)) return;

    _updateProgress(
      itemId,
      progressValue: 0.0,
      progressText: "Oczekiwanie...",
      isQueued: true,
    );
    Future<void> downloadTask() async {
      String? finalSeriesName = seriesOverrideName;
      if (item.type == "Episode" && finalSeriesName == null) {
        finalSeriesName = item.seriesName;
        if (finalSeriesName == null && item.seriesId != null) {
          _updateProgress(itemId, progressValue: 0.0, progressText: "Dane...");
          finalSeriesName = await JellyfinApi().fetchSeriesName(
            baseUrl,
            token,
            item.seriesId!,
          );
        }
      }

      final String baseDir = await getDirectoryPath();
      if (baseDir.isEmpty) return;

      final paths = _generatePaths(item, finalSeriesName, qualityLabel);
      final String safeFolderName = paths["folder"]!;
      final String fileName = paths["file"]!;

      Directory seriesDir = Directory('$baseDir/$safeFolderName');
      if (!seriesDir.existsSync()) seriesDir.createSync(recursive: true);

      File targetFile = File('${seriesDir.path}/$fileName');
      if (targetFile.existsSync()) {
        try {
          targetFile.deleteSync();
          debugPrint("Usunięto stary plik przed nowym pobraniem: ${targetFile.path}");
        } catch (e) {
          debugPrint("Nie udało się usunąć starego pliku: $e");
        }
      }

      await _downloadMetadataImages(item, baseUrl, token, seriesDir, fileName);

      final storage = StorageService();
      final hwAccel = await storage.getString('setting_hw_accel') ?? 'auto';
      final cpuLimit = await storage.getString('setting_cpu_limit') ?? 'auto';
      final maxFps = await storage.getString('setting_max_fps') ?? 'auto';
      final audioBitrate = await storage.getString('setting_audio_bitrate') ?? 'auto';

      String urlArgs = "&Static=false"
          "&VideoCodec=h264"
          "&AudioCodec=aac,mp3"
          "&MaxAudioChannels=2"
          "&EnableSubtitlesInManifest=false"
          "&PlaySessionId=${DateTime.now().millisecondsSinceEpoch}";

      if (maxWidth != null) urlArgs += "&MaxWidth=$maxWidth";
      if (bitrate != null) urlArgs += "&VideoBitrate=$bitrate";

      if (hwAccel != 'auto') urlArgs += "&TranscodingMaxType=$hwAccel";
      if (cpuLimit != 'auto') urlArgs += "&CpuCoreLimit=$cpuLimit";
      if (maxFps != 'auto') urlArgs += "&MaxFramerate=$maxFps";
      if (audioBitrate != 'auto') urlArgs += "&AudioBitrate=$audioBitrate";

      String downloadUrl = qualityLabel == "original"
        ? "$baseUrl/Videos/$itemId/stream.mp4?api_key=$token&Static=true"
        : "$baseUrl/Videos/$itemId/stream.mp4?api_key=$token$urlArgs";

      BaseDownloader downloader = await _getDownloaderInstance();

      bool wifiOnly = await _storage.getSetting(
        'setting_wifionly',
        defaultValue: true,
      );

      await downloader.downloadVideo(
        itemId: itemId,
        downloadUrl: downloadUrl,
        saveDir: seriesDir.path,
        fileName: fileName,
        token: token,
        wifiOnly: wifiOnly,
        onProgress: (id, val, text) =>
            _updateProgress(id, progressValue: val, progressText: text),
        onFinished: (id) => _finishDownload(id, "${seriesDir.path}/$fileName"),
      );
    }

    _queue.add(downloadTask);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      _processQueue();
    });
  }

  void _updateProgress(
    String id, {
    double progressValue = 0.0,
    String progressText = "",
    bool isQueued = false,
  }) {
    var newMap = Map<String, DownloadStatus>.from(activeDownloads.value);
    newMap[id] = DownloadStatus(
      progressValue: progressValue,
      progressText: progressText,
      isQueued: isQueued,
    );
    activeDownloads.value = newMap;
  }

  void _finishDownload(String id, String fullPath) {
    var newMap = Map<String, DownloadStatus>.from(activeDownloads.value);
    newMap[id] = DownloadStatus(isDownloaded: true, filePath: fullPath);
    activeDownloads.value = newMap;
    Future.delayed(const Duration(seconds: 1), () {
      var finalMap = Map<String, DownloadStatus>.from(activeDownloads.value);
      finalMap.remove(id);
      activeDownloads.value = finalMap;
    });
  }

  Future<void> _downloadMetadataImages(
    JellyfinItem item,
    String baseUrl,
    String token,
    Directory seriesDir,
    String fileName,
  ) async {
    final dio = Dio();
    String coverUrl =
        "$baseUrl/Items/${item.seriesId ?? item.id}/Images/Primary?fillWidth=400&quality=90";

    File coverFile = File('${seriesDir.path}/folder.jpg');
    if (!coverFile.existsSync()) {
      try {
        await dio.download(
          coverUrl,
          coverFile.path,
          options: Options(headers: {"X-Emby-Token": token}),
        );
        if (coverFile.existsSync() && coverFile.lengthSync() < 500) {
          coverFile.deleteSync();
        }
      } catch (_) {
        if (coverFile.existsSync()) coverFile.deleteSync();
      }
    }

    String thumbUrl =
        "$baseUrl/Items/${item.id}/Images/Primary?fillWidth=400&quality=90";
    String thumbFileName = fileName.replaceAll('.mp4', '.jpg');
    File thumbFile = File('${seriesDir.path}/$thumbFileName');

    if (!thumbFile.existsSync()) {
      try {
        await dio.download(
          thumbUrl,
          thumbFile.path,
          options: Options(headers: {"X-Emby-Token": token}),
        );
        if (thumbFile.existsSync() && thumbFile.lengthSync() < 500) {
          thumbFile.deleteSync();
        }
      } catch (_) {
        if (thumbFile.existsSync()) thumbFile.deleteSync();
      }
    }
  }

  Future<String?> findLocalFile(
    dynamic item, {
    String? seriesOverrideName,
  }) async {
    const qualities = ["original", "1080p", "720p", "480p", "360p", "144p"];
    for (String q in qualities) {
      final paths = _generatePaths(item, seriesOverrideName, q);
      final status = await checkStatus(
        item.id,
        "${paths["folder"]}/${paths["file"]}",
      );
      if (status.isDownloaded && status.filePath != null) {
        return status.filePath;
      }
    }
    return null;
  }

  static List<Map<String, dynamic>> getQualityOptions(
    Map<String, dynamic>? mediaInfo,
  ) {
    final qualities = [
      {
        "label": "Oryginalna",
        "icon": Icons.star,
        "color": Colors.greenAccent,
        "width": null,
        "height": null,
        "qualityLabel": "original",
      },
      {
        "label": "1080p (Full HD)",
        "icon": Icons.hd,
        "color": Colors.blueAccent,
        "width": 1920,
        "height": 1080,
        "qualityLabel": "1080p",
      },
      {
        "label": "720p (HD)",
        "icon": Icons.high_quality,
        "color": Colors.lightBlueAccent,
        "width": 1280,
        "height": 720,
        "qualityLabel": "720p",
      },
      {
        "label": "480p (SD)",
        "icon": Icons.sd,
        "color": Colors.orangeAccent,
        "width": 854,
        "height": 480,
        "qualityLabel": "480p",
      },
      {
        "label": "144p (Bardzo niska)",
        "icon": Icons.speed,
        "color": Colors.redAccent,
        "width": 256,
        "height": 144,
        "qualityLabel": "144p",
      },
    ];

    if (mediaInfo != null) {
      final originalWidth = mediaInfo['Width'] as int?;
      final originalHeight = mediaInfo['Height'] as int?;
      final originalBitrate = mediaInfo['Bitrate'] as int?;
      final bool hasSourceInfo =
          originalWidth != null && originalHeight != null;

      final filteredQualities = <Map<String, dynamic>>[];

      for (final quality in qualities) {
        final width = quality['width'] as int?;
        final height = quality['height'] as int?;
        int? bitrate = quality['bitrate'] as int?;

        if (width != null && height != null && hasSourceInfo) {
          if (originalWidth <= width || originalHeight <= height) continue;
        }

        if (width != null &&
            height != null &&
            hasSourceInfo &&
            originalBitrate != null) {
          final ratio = (width * height) / (originalWidth * originalHeight);
          bitrate = (originalBitrate * ratio).round();
          if (bitrate > originalBitrate) bitrate = originalBitrate;
        }
        filteredQualities.add({...quality, 'bitrate': bitrate});
      }
      return filteredQualities;
    } else {
      return qualities
          .map((q) => {...q, 'bitrate': q['bitrate'] as int?})
          .toList();
    }
  }

  Future<void> downloadSubtitles({
    required JellyfinItem item,
    required String baseUrl,
    required String token,
    required int subtitleIndex,
    required String languageName,
    String? seriesOverrideName,
  }) async {
    final dio = Dio();
    final baseDir = await getDirectoryPath();

    final paths = _generatePaths(item, seriesOverrideName, "TEMP");
    final String folderPath = "$baseDir/${paths["folder"]}";

    String subFileName = paths["file"]!.replaceAll(
      "_TEMP.mp4",
      ".$languageName.srt",
    );

    Directory dir = Directory(folderPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    await dio.download(
      "$baseUrl/Videos/${item.id}/${item.id}/Subtitles/$subtitleIndex/0/Stream.srt?api_key=$token",
      "$folderPath/$subFileName",
      options: Options(headers: {"X-Emby-Token": token}),
    );

    debugPrint("Pobrano napisy: $folderPath/$subFileName");
  }
}
