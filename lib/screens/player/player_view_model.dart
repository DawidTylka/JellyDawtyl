import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// Upewnij się, że te ścieżki pasują do struktury Twojego projektu:
import '../../../services/jellyfin_api.dart';
import '../../../services/storage_service.dart';
import '../../../main.dart'; // Tu znajduje się globalny audioHandler

class PlayerViewModel extends ChangeNotifier {
  // === Parametry Wejściowe ===
  final String originalUrl;
  final String title;
  final String itemId;
  final String? baseUrl;
  final String? token;
  final String? userId;
  final bool isOffline;
  final int? startPositionMs;

  // Callback nawigacji (wywoływany, gdy trzeba odtworzyć następny odcinek)
  final void Function(String url, String title, String itemId, bool isOffline)? onPlayNext;

  // === Komponenty Odtwarzacza ===
  late final Player player;
  late final VideoController controller;

  // === Stan UI ===
  bool isLoading = true;
  String? error;

  // === Stan Strumieni (Jakość, Audio, Napisy) ===
  int? selectedWidth;
  int? selectedBitrate;
  int? selectedAudioIndex;
  int? selectedSubtitleIndex;

  List<dynamic> jellyfinAudioStreams = [];
  List<dynamic> jellyfinSubtitleStreams = [];
  Map<String, dynamic>? itemData;
  
  String? currentExternalSubtitlePath;
  List<File> localSubtitleFiles = [];

  // === Stan Wewnętrzny Logiki ===
  Timer? _progressTimer;
  Duration? _pendingSeek;
  bool _firstLoadDone = false;
  bool _hasPerformedInitialSeek = false;
  bool _isDisposed = false;

  PlayerViewModel({
    required this.originalUrl,
    required this.title,
    required this.itemId,
    this.baseUrl,
    this.token,
    this.userId,
    this.isOffline = false,
    this.startPositionMs,
    this.onPlayNext,
  }) {
    player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024,
        ready: null,
      ),
    );
    controller = VideoController(player);
  }

  // ==========================================
  // INICJALIZACJA
  // ==========================================
  Future<void> init() async {
    try {
      WakelockPlus.enable();
      
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      audioHandler.attachPlayer(player);
      audioHandler.mediaItem.add(
        MediaItem(id: itemId, title: title, album: 'JellyDawtyl'),
      );

      await _fetchJellyfinStreamData();

      if (isOffline) {
        await player.setRate(1.0);
        _findLocalSubtitles();
      }

      String finalSource = isOffline
          ? File(originalUrl).absolute.path
          : _buildCompatibleUrl(originalUrl);
          
      final headers = token != null ? {'X-Emby-Token': token!} : null;

      _setupPlayerListeners();

      await player.open(
        Media(finalSource, httpHeaders: headers), 
        play: true
      );

      if (!isOffline && baseUrl != null) {
        _startProgressReporting();
      }
    } catch (e) {
      _setError("Wystąpił błąd inicjalizacji odtwarzacza.");
      debugPrint("Initialize Error: $e");
    }
  }

  void _setupPlayerListeners() {
    player.stream.tracks.listen((tracks) {
      if (selectedWidth != null && currentExternalSubtitlePath != null) {
        final currentId = player.state.track.subtitle.id;
        if (!currentId.contains('.srt')) {
          player.setSubtitleTrack(SubtitleTrack.uri(currentExternalSubtitlePath!));
        }
      }
    });

    player.stream.duration.listen((duration) async {
      if (duration.inSeconds > 0) {
        if (!_firstLoadDone) {
          _firstLoadDone = true;
          _applyInitialTracks();
        } else if (_pendingSeek != null) {
          final targetTime = _pendingSeek!;
          _pendingSeek = null;
          await player.seek(targetTime);
          await Future.delayed(const Duration(milliseconds: 300));
          _applyInitialTracks();
        }
      }
    });

    player.stream.completed.listen((completed) {
      if (completed && !_isDisposed) {
        _handlePlaybackCompleted();
      }
    });

    player.stream.error.listen((event) {
      if (!_isDisposed) {
        _setError("Wystąpił błąd odtwarzania.");
        debugPrint("Player Error: $event");
      }
    });

    player.stream.playing.listen((isPlaying) async {
      if (isPlaying && !_isDisposed) {
        if (isLoading) {
          isLoading = false;
          notifyListeners();
        }

        if (!_hasPerformedInitialSeek && startPositionMs != null && startPositionMs! > 0) {
          _hasPerformedInitialSeek = true;
          await player.pause();
          await Future.delayed(const Duration(milliseconds: 400));
          await player.seek(Duration(milliseconds: startPositionMs!));
          await Future.delayed(const Duration(milliseconds: 100));
          await player.play();
        }
      }
    });
  }

  // ==========================================
  // LOGIKA STRUMIENI I ZMIANY JAKOŚCI
  // ==========================================
  Future<void> changeOnlineQuality(int? width, int? bitrate) async {
    if (selectedWidth == width) return;

    _pendingSeek = player.state.position;

    if (width != null && selectedWidth == null) {
      selectedAudioIndex = _getTrueJellyfinIndexAudio(player.state.track.audio, player.state.tracks.audio) ?? selectedAudioIndex;
      selectedSubtitleIndex = _getTrueJellyfinIndexSub(player.state.track.subtitle, player.state.tracks.subtitle) ?? selectedSubtitleIndex;
    }

    selectedWidth = width;
    selectedBitrate = bitrate;
    isLoading = true;
    notifyListeners();

    final newUrl = _buildCompatibleUrl(originalUrl);
    final headers = token != null ? {'X-Emby-Token': token!} : null;

    await player.open(Media(newUrl, httpHeaders: headers), play: true);
  }

  void setAudioTrack(dynamic track, {bool isJellyfinIndex = false}) {
    if (isOffline || !isJellyfinIndex) {
      player.setAudioTrack(track);
    } else {
      selectedAudioIndex = track as int;
      if (selectedWidth == null) {
        _applyOriginalAudio();
      } else {
        changeOnlineQuality(selectedWidth, selectedBitrate);
      }
    }
    notifyListeners();
  }

  Future<void> setSubtitleTrack(dynamic track, {bool isJellyfinIndex = false, String? externalPath}) async {
    if (externalPath != null) {
      currentExternalSubtitlePath = externalPath;
      player.setSubtitleTrack(SubtitleTrack.uri(externalPath));
    } else if (isOffline || !isJellyfinIndex) {
      currentExternalSubtitlePath = null;
      player.setSubtitleTrack(track);
    } else {
      selectedSubtitleIndex = track as int?;
      if (selectedWidth == null) {
        _applyOriginalSubtitles();
      } else {
        await _applyExternalSubtitles();
      }
    }
    notifyListeners();
  }

  // ==========================================
  // METODY WEWNĘTRZNE (API & URL)
  // ==========================================
  Future<void> _fetchJellyfinStreamData() async {
    if (isOffline || baseUrl == null || token == null) return;
    
    try {
      final httpClient = HttpClient()..badCertificateCallback = ((cert, host, port) => true);
      final url = '$baseUrl/Users/$userId/Items/$itemId?api_key=$token';
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode == 200) {
        final data = jsonDecode(await response.transform(utf8.decoder).join());
        itemData = data;

        final sources = data['MediaSources'] as List?;
        if (sources != null && sources.isNotEmpty) {
          final streams = sources[0]['MediaStreams'] as List?;
          if (streams != null) {
            jellyfinAudioStreams = streams.where((s) => s['Type'] == 'Audio').toList();
            jellyfinSubtitleStreams = streams.where((s) => s['Type'] == 'Subtitle').toList();

            if (selectedAudioIndex == null && jellyfinAudioStreams.isNotEmpty) {
              try {
                selectedAudioIndex = jellyfinAudioStreams.firstWhere((s) => s['IsDefault'] == true)['Index'];
              } catch (_) {
                selectedAudioIndex = jellyfinAudioStreams.first['Index'];
              }
            }
            if (selectedSubtitleIndex == null && jellyfinSubtitleStreams.isNotEmpty) {
              try {
                selectedSubtitleIndex = jellyfinSubtitleStreams.firstWhere((s) => s['IsDefault'] == true)['Index'];
              } catch (_) {}
            }
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint("Błąd pobierania strumieni: $e");
    }
  }

  String _buildCompatibleUrl(String url) {
    if (isOffline) return url;

    if (selectedWidth != null && selectedBitrate != null && baseUrl != null) {
      String audioParam = selectedAudioIndex != null ? '&AudioStreamIndex=$selectedAudioIndex' : '';
      return '$baseUrl/Videos/$itemId/master.m3u8'
          '?api_key=$token'
          '&MediaSourceId=$itemId'
          '&VideoCodec=h264'
          '&AudioCodec=aac,mp3'
          '&VideoBitrate=$selectedBitrate'
          '&AudioBitrate=320000'
          '&MaxWidth=$selectedWidth'
          '&TranscodingMaxAudioChannels=2'
          '&SegmentContainer=ts'
          '&MinSegments=1'
          '&BreakOnNonKeyFrames=True'
          '&EnableAdaptiveBitrateStreaming=true'
          '&RequireAvc=false'
          '$audioParam';
    }

    final uri = Uri.parse(url);
    final query = Map<String, String>.from(uri.queryParameters);
    if (token != null) query['api_key'] = token!;
    query['Static'] = 'true';
    query.removeWhere((key, value) => ['MaxWidth', 'VideoBitrate', 'VideoCodec', 'AudioCodec', 'MaxFramerate', 'AudioBitrate', 'MaxAudioChannels'].contains(key));
    
    return uri.replace(queryParameters: query).toString();
  }

  Future<void> _applyExternalSubtitles() async {
    if (selectedSubtitleIndex == null || baseUrl == null) {
      player.setSubtitleTrack(SubtitleTrack.no());
      currentExternalSubtitlePath = null;
      notifyListeners();
      return;
    }
    try {
      final httpClient = HttpClient()..badCertificateCallback = ((cert, host, port) => true);
      final subUrl = '$baseUrl/Videos/$itemId/$itemId/Subtitles/$selectedSubtitleIndex/0/Stream.srt?api_key=$token';
      final request = await httpClient.getUrl(Uri.parse(subUrl));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        final file = File('${Directory.systemTemp.path}/subs_${itemId}_$selectedSubtitleIndex.srt');
        await file.writeAsString(content);

        currentExternalSubtitlePath = file.path;
        player.setSubtitleTrack(SubtitleTrack.uri(currentExternalSubtitlePath!));
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Błąd pobierania napisów: $e");
    }
  }

  void _applyInitialTracks() async {
    if (selectedWidth == null) {
      _applyOriginalAudio();
      _applyOriginalSubtitles();
      if (isOffline && currentExternalSubtitlePath != null) {
        player.setSubtitleTrack(SubtitleTrack.uri(currentExternalSubtitlePath!));
      }
    } else {
      if (!isOffline) await _applyExternalSubtitles();
    }
  }

  void _applyOriginalAudio() {
    if (selectedAudioIndex == null) return;
    final jfIndex = jellyfinAudioStreams.indexWhere((s) => s['Index'] == selectedAudioIndex);
    final realTracks = player.state.tracks.audio.where((t) => t.id != 'no' && t.id != 'auto').toList();
    if (jfIndex != -1 && jfIndex < realTracks.length) {
      player.setAudioTrack(realTracks[jfIndex]);
    }
  }

  void _applyOriginalSubtitles() {
    if (selectedSubtitleIndex == null) {
      player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }
    final jfIndex = jellyfinSubtitleStreams.indexWhere((s) => s['Index'] == selectedSubtitleIndex);
    final realTracks = player.state.tracks.subtitle.where((t) => t.id != 'no' && t.id != 'auto').toList();
    if (jfIndex != -1 && jfIndex < realTracks.length) {
      player.setSubtitleTrack(realTracks[jfIndex]);
    }
  }

  int? _getTrueJellyfinIndexAudio(AudioTrack track, List<AudioTrack> tracks) {
    if (track.id == 'no' || track.id == 'auto') return null;
    final real = tracks.where((t) => t.id != 'no' && t.id != 'auto').toList();
    final pos = real.indexWhere((t) => t.id == track.id);
    if (pos != -1 && pos < jellyfinAudioStreams.length) return jellyfinAudioStreams[pos]['Index'];
    return null;
  }

  int? _getTrueJellyfinIndexSub(SubtitleTrack track, List<SubtitleTrack> tracks) {
    if (track.id == 'no' || track.id == 'auto') return null;
    final real = tracks.where((t) => t.id != 'no' && t.id != 'auto').toList();
    final pos = real.indexWhere((t) => t.id == track.id);
    if (pos != -1 && pos < jellyfinSubtitleStreams.length) return jellyfinSubtitleStreams[pos]['Index'];
    return null;
  }

  // ==========================================
  // PROGRESS & AUTO-PLAY LOGIC
  // ==========================================
  void _startProgressReporting() {
    _progressTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (player.state.playing) {
        JellyfinApi().reportPlaybackProgress(
          baseUrl: baseUrl!,
          token: token!,
          userId: userId!,
          itemId: itemId,
          position: player.state.position,
          isPaused: false,
          isStopped: false,
        );
      }
    });
  }

  Future<void> _handlePlaybackCompleted() async {
    final autoPlay = await StorageService().getSetting('setting_autoplay', defaultValue: true);
    if (!autoPlay || onPlayNext == null) return;

    if (isOffline) {
      await _playNextOffline();
    } else {
      await _playNextOnline();
    }
  }

  Future<void> _playNextOffline() async {
    try {
      final file = File(originalUrl);
      final dir = file.parent;
      final fileName = file.path.split(Platform.pathSeparator).last;

      final RegExp regex = RegExp(r'_S(\d+)E(\d+)_');
      final match = regex.firstMatch(fileName);

      if (match != null) {
        final seasonStr = match.group(1)!;
        final epStr = match.group(2)!;
        final nextEpStr = (int.parse(epStr) + 1).toString().padLeft(epStr.length, '0');
        final searchPattern = '_S${seasonStr}E$nextEpStr';

        final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.mp4')).toList();
        
        for (var f in files) {
          if (f.path.contains(searchPattern)) {
            final nextTitle = f.path.split(Platform.pathSeparator).last.replaceAll('.mp4', '').replaceAll('_', ' ');
            onPlayNext?.call(f.path, nextTitle, '', true);
            break;
          }
        }
      }
    } catch (e) {
      debugPrint("Błąd autoodtwarzania offline: $e");
    }
  }

  Future<void> _playNextOnline() async {
    if (itemData == null || itemData!['Type'] != 'Episode') return;
    try {
      final seriesId = itemData!['SeriesId'];
      final seasonId = itemData!['SeasonId'];
      if (seriesId == null) return;

      final httpClient = HttpClient()..badCertificateCallback = ((cert, host, port) => true);
      final url = '$baseUrl/Shows/$seriesId/Episodes?seasonId=$seasonId&UserId=$userId&api_key=$token';
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode == 200) {
        final data = jsonDecode(await response.transform(utf8.decoder).join());
        final items = data['Items'] as List?;

        if (items != null) {
          int currentIndex = items.indexWhere((item) => item['Id'] == itemId);
          if (currentIndex != -1 && currentIndex + 1 < items.length) {
            final nextItem = items[currentIndex + 1];
            final nextUrl = '$baseUrl/Videos/${nextItem['Id']}/stream.mp4';
            onPlayNext?.call(nextUrl, nextItem['Name'], nextItem['Id'], false);
          }
        }
      }
    } catch (e) {
      debugPrint("Błąd autoodtwarzania online: $e");
    }
  }

  void _findLocalSubtitles() {
    try {
      final videoFile = File(originalUrl);
      final dir = videoFile.parent;
      final videoFileName = videoFile.path.split(Platform.pathSeparator).last;

      // Zabezpieczenie: usuwamy końcówkę .mp4 (niezależnie od wielkości liter) lub odcinamy parametry po '_'
      final baseName = videoFileName.contains('_')
          ? videoFileName.substring(0, videoFileName.lastIndexOf('_'))
          : videoFileName.replaceAll(RegExp(r'\.mp4$', caseSensitive: false), '');

      localSubtitleFiles = dir.listSync().whereType<File>().where((f) {
        final name = f.path.split(Platform.pathSeparator).last;
        return name.startsWith(baseName) && name.endsWith('.srt');
      }).toList();

      if (localSubtitleFiles.isNotEmpty && currentExternalSubtitlePath == null) {
        currentExternalSubtitlePath = localSubtitleFiles.first.path;
        
        // WAŻNE: Informujemy interfejs, że znaleźliśmy i wybraliśmy domyślne napisy z pliku!
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Błąd szukania lokalnych napisów: $e");
    }
  }

  void _setError(String msg) {
    error = msg;
    isLoading = false;
    notifyListeners();
  }

  // ==========================================
  // DISPOSE
  // ==========================================
  @override
  void dispose() {
    _isDisposed = true;
    _progressTimer?.cancel();

    if (!isOffline && baseUrl != null) {
      JellyfinApi().reportPlaybackProgress(
        baseUrl: baseUrl!,
        token: token!,
        userId: userId!,
        itemId: itemId,
        position: player.state.position,
        isPaused: false,
        isStopped: true,
      );
    }

    audioHandler.detachPlayer();
    audioHandler.stop();
    player.dispose();
    WakelockPlus.disable();
    super.dispose();
  }
}