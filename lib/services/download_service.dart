import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/jellyfin_item.dart';
import 'jellyfin_api.dart';
import 'storage_service.dart';

import 'downloaders/base_downloader.dart';
import 'downloaders/dio_downloader.dart';
import 'downloaders/native_downloader.dart';

class DownloadStatus {
  final double progressValue;
  final String progressText;
  final bool isDownloaded;
  final String? filePath;

  DownloadStatus({
    this.progressValue = 0.0,
    this.progressText = "",
    this.isDownloaded = false,
    this.filePath,
  });
}

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

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

    await _downloadMetadataImages(item, baseUrl, token, seriesDir, fileName);

    String downloadUrl = qualityLabel == "original"
        ? "$baseUrl/Items/$itemId/Download?api_key=$token"
        : "$baseUrl/Videos/$itemId/stream.mp4?api_key=$token&Static=false&VideoCodec=h264&AudioCodec=aac&VideoProfile=main&MaxFramerate=24&AudioBitrate=96000&MaxAudioChannels=2&TranscodingMaxType=Vaapi&CpuCoreLimit=2&EnableSubtitlesInManifest=false&PlaySessionId=${DateTime.now().millisecondsSinceEpoch}";

    if (qualityLabel != "original" && maxWidth != null) {
      downloadUrl += "&maxWidth=$maxWidth";
      if (bitrate != null) downloadUrl += "&videoBitrate=$bitrate";
      downloadUrl += "&VideoBitratePreroll=0&FillMethod=Preserve";
    }

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

  void _updateProgress(
    String id, {
    double progressValue = 0.0,
    String progressText = "",
  }) {
    var newMap = Map<String, DownloadStatus>.from(activeDownloads.value);
    newMap[id] = DownloadStatus(
      progressValue: progressValue,
      progressText: progressText,
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
        "$baseUrl/Items/${item.seriesId}/Images/Primary?fillWidth=400&quality=90";

    File coverFile = File('${seriesDir.path}/folder.jpg');
    if (!coverFile.existsSync()) {
      try {
        await dio.download(
          coverUrl,
          coverFile.path,
          options: Options(headers: {"X-Emby-Token": token}),
        );
        if (coverFile.existsSync() && coverFile.lengthSync() < 500)
          coverFile.deleteSync();
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
        if (thumbFile.existsSync() && thumbFile.lengthSync() < 500)
          thumbFile.deleteSync();
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
      if (status.isDownloaded && status.filePath != null)
        return status.filePath;
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
          if (originalWidth! <= width || originalHeight! <= height) continue;
        }

        if (width != null &&
            height != null &&
            hasSourceInfo &&
            originalBitrate != null) {
          final ratio = (width * height) / (originalWidth! * originalHeight!);
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
