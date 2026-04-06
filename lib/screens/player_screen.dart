import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../l10n/app_localizations.dart';
import '../services/jellyfin_api.dart';
import '../services/storage_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audio_service/audio_service.dart';
import '../main.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PlayerScreen extends StatefulWidget {
  final String url;
  final String title;
  final String itemId;
  final String? baseUrl;
  final String? token;
  final String? userId;
  final bool isOffline;
  final int? startPositionMs;

  const PlayerScreen({
    super.key,
    required this.url,
    required this.title,
    required this.itemId,
    this.baseUrl,
    this.token,
    this.userId,
    this.isOffline = false,
    this.startPositionMs,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player player = Player(
    configuration: const PlayerConfiguration(
      bufferSize: 32 * 1024 * 1024,
      ready: null,
    ),
  );
  late final VideoController controller = VideoController(player);

  Timer? _progressTimer;
  bool _isLoading = true;
  String? _error;

  int? _selectedWidth;
  int? _selectedBitrate;

  Duration? _pendingSeek;
  bool _firstLoadDone = false;

  int? _selectedAudioIndex;
  int? _selectedSubtitleIndex;

  List<dynamic> _jellyfinAudioStreams = [];
  List<dynamic> _jellyfinSubtitleStreams = [];

  Map<String, dynamic>? _itemData;
  String? _currentExternalSubtitlePath;
  List<File> _localSubtitleFiles = [];

  bool _isTransitioningToNext = false;
  bool _hasPerformedInitialSeek = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initializePlayer();
  }

  void _findLocalSubtitles() {
    try {
      final videoFile = File(widget.url);
      final dir = videoFile.parent;
      final videoFileName = videoFile.path.split(Platform.pathSeparator).last;

      final baseName = videoFileName.contains('_')
          ? videoFileName.substring(0, videoFileName.lastIndexOf('_'))
          : videoFileName.replaceAll('.mp4', '');

      final files = dir.listSync().whereType<File>();
      _localSubtitleFiles = files.where((f) {
        final name = f.path.split(Platform.pathSeparator).last;
        return name.startsWith(baseName) && name.endsWith('.srt');
      }).toList();

      if (_localSubtitleFiles.isNotEmpty &&
          _currentExternalSubtitlePath == null) {
        _currentExternalSubtitlePath = _localSubtitleFiles.first.path;
      }
    } catch (e) {
      debugPrint("Błąd szukania lokalnych napisów: $e");
    }
  }

  Future<void> _fetchJellyfinStreamData() async {
    if (widget.isOffline || widget.baseUrl == null || widget.token == null) {
      return;
    }
    try {
      final httpClient = HttpClient()
        ..badCertificateCallback = ((cert, host, port) => true);
      final url =
          '${widget.baseUrl}/Users/${widget.userId}/Items/${widget.itemId}?api_key=${widget.token}';
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode == 200) {
        final data = jsonDecode(await response.transform(utf8.decoder).join());
        _itemData = data;

        final sources = data['MediaSources'] as List?;
        if (sources != null && sources.isNotEmpty) {
          final streams = sources[0]['MediaStreams'] as List?;
          if (streams != null) {
            _jellyfinAudioStreams = streams
                .where((s) => s['Type'] == 'Audio')
                .toList();
            _jellyfinSubtitleStreams = streams
                .where((s) => s['Type'] == 'Subtitle')
                .toList();

            if (_selectedAudioIndex == null &&
                _jellyfinAudioStreams.isNotEmpty) {
              try {
                final def = _jellyfinAudioStreams.firstWhere(
                  (s) => s['IsDefault'] == true,
                );
                _selectedAudioIndex = def['Index'];
              } catch (_) {
                _selectedAudioIndex = _jellyfinAudioStreams.first['Index'];
              }
            }
            if (_selectedSubtitleIndex == null &&
                _jellyfinSubtitleStreams.isNotEmpty) {
              try {
                final def = _jellyfinSubtitleStreams.firstWhere(
                  (s) => s['IsDefault'] == true,
                );
                _selectedSubtitleIndex = def['Index'];
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Błąd pobierania strumieni: $e");
    }
  }

  int? _getTrueJellyfinIndexAudio(AudioTrack track, List<AudioTrack> tracks) {
    if (track.id == 'no' || track.id == 'auto') return null;
    final real = tracks.where((t) => t.id != 'no' && t.id != 'auto').toList();
    final pos = real.indexWhere((t) => t.id == track.id);
    if (pos != -1 && pos < _jellyfinAudioStreams.length) {
      return _jellyfinAudioStreams[pos]['Index'];
    }
    return null;
  }

  int? _getTrueJellyfinIndexSub(
    SubtitleTrack track,
    List<SubtitleTrack> tracks,
  ) {
    if (track.id == 'no' || track.id == 'auto') return null;
    final real = tracks.where((t) => t.id != 'no' && t.id != 'auto').toList();
    final pos = real.indexWhere((t) => t.id == track.id);
    if (pos != -1 && pos < _jellyfinSubtitleStreams.length) {
      return _jellyfinSubtitleStreams[pos]['Index'];
    }
    return null;
  }

  void _applyOriginalAudio() {
    if (_selectedAudioIndex == null) return;
    final jfIndex = _jellyfinAudioStreams.indexWhere(
      (s) => s['Index'] == _selectedAudioIndex,
    );
    final realTracks = player.state.tracks.audio
        .where((t) => t.id != 'no' && t.id != 'auto')
        .toList();
    if (jfIndex != -1 && jfIndex < realTracks.length) {
      player.setAudioTrack(realTracks[jfIndex]);
    }
  }

  void _applyOriginalSubtitles() {
    if (_selectedSubtitleIndex == null) {
      player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }
    final jfIndex = _jellyfinSubtitleStreams.indexWhere(
      (s) => s['Index'] == _selectedSubtitleIndex,
    );
    final realTracks = player.state.tracks.subtitle
        .where((t) => t.id != 'no' && t.id != 'auto')
        .toList();
    if (jfIndex != -1 && jfIndex < realTracks.length) {
      player.setSubtitleTrack(realTracks[jfIndex]);
    }
  }

  Future<void> _applyExternalSubtitles() async {
    if (_selectedSubtitleIndex == null || widget.baseUrl == null) {
      player.setSubtitleTrack(SubtitleTrack.no());
      _currentExternalSubtitlePath = null;
      return;
    }
    try {
      final httpClient = HttpClient()
        ..badCertificateCallback = ((cert, host, port) => true);
      final subUrl =
          '${widget.baseUrl}/Videos/${widget.itemId}/${widget.itemId}/Subtitles/$_selectedSubtitleIndex/0/Stream.srt?api_key=${widget.token}';

      final request = await httpClient.getUrl(Uri.parse(subUrl));
      final response = await request.close();
      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        final tempDir = Directory.systemTemp;
        final file = File(
          '${tempDir.path}/subs_${widget.itemId}_$_selectedSubtitleIndex.srt',
        );
        await file.writeAsString(content);

        _currentExternalSubtitlePath = file.path;
        player.setSubtitleTrack(
          SubtitleTrack.uri(_currentExternalSubtitlePath!),
        );
      }
    } catch (e) {
      debugPrint("Błąd pobierania napisów: $e");
    }
  }

  String _buildCompatibleUrl(String url) {
    if (widget.isOffline) return url;

    if (_selectedWidth != null &&
        _selectedBitrate != null &&
        widget.baseUrl != null) {
      String audioParam = _selectedAudioIndex != null
          ? '&AudioStreamIndex=$_selectedAudioIndex'
          : '';
          
      return '${widget.baseUrl}/Videos/${widget.itemId}/master.m3u8'
          '?api_key=${widget.token}'
          '&MediaSourceId=${widget.itemId}'
          '&VideoCodec=h264'
          '&AudioCodec=aac,mp3'
          '&VideoBitrate=$_selectedBitrate'
          '&AudioBitrate=320000'
          '&MaxWidth=$_selectedWidth'
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
    if (widget.token != null) query['api_key'] = widget.token!;

    query['Static'] = 'true';
    query.remove('MaxWidth');
    query.remove('VideoBitrate');
    query.remove('VideoCodec');
    query.remove('AudioCodec');
    query.remove('MaxFramerate');
    query.remove('AudioBitrate');
    query.remove('MaxAudioChannels');

    return uri.replace(queryParameters: query).toString();
  }

  Future<void> _initializePlayer() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      audioHandler.attachPlayer(player);
      audioHandler.mediaItem.add(
        MediaItem(id: widget.itemId, title: widget.title, album: 'JellyDawtyl'),
      );

      await _fetchJellyfinStreamData();

      if (widget.isOffline) {
        await player.setRate(1.0);
        _findLocalSubtitles();
      }

      String finalSource = widget.isOffline
          ? File(widget.url).absolute.path
          : _buildCompatibleUrl(widget.url);
      final headers = widget.token != null
          ? {'X-Emby-Token': widget.token!}
          : null;

      player.stream.tracks.listen((tracks) {
        if (_selectedWidth != null && _currentExternalSubtitlePath != null) {
          final currentId = player.state.track.subtitle.id;
          if (!currentId.contains('.srt')) {
            player.setSubtitleTrack(
              SubtitleTrack.uri(_currentExternalSubtitlePath!),
            );
          }
        }
      });

      player.stream.duration.listen((duration) async {
        if (duration.inSeconds > 0) {
          if (!_firstLoadDone) {
            _firstLoadDone = true;

            if (_selectedWidth == null) {
              _applyOriginalAudio();
              _applyOriginalSubtitles();
              if (widget.isOffline && _currentExternalSubtitlePath != null) {
                player.setSubtitleTrack(
                  SubtitleTrack.uri(_currentExternalSubtitlePath!),
                );
              }
            } else {
              if (!widget.isOffline) await _applyExternalSubtitles();
            }
          } else if (_pendingSeek != null) {
            final targetTime = _pendingSeek!;
            _pendingSeek = null;

            await player.seek(targetTime);
            await Future.delayed(const Duration(milliseconds: 300));

            if (_selectedWidth == null) {
              _applyOriginalAudio();
              _applyOriginalSubtitles();
              if (widget.isOffline && _currentExternalSubtitlePath != null) {
                player.setSubtitleTrack(
                  SubtitleTrack.uri(_currentExternalSubtitlePath!),
                );
              }
            } else {
              if (!widget.isOffline) await _applyExternalSubtitles();
            }
          }
        }
      });

      player.stream.completed.listen((completed) {
        if (completed && mounted) {
          _handlePlaybackCompleted();
        }
      });

      player.stream.error.listen((event) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          setState(() => _error = l10n.playerError);
          debugPrint("Player Error: $event");
        }
      });

      player.stream.playing.listen((isPlaying) async {
        if (isPlaying && mounted) {
          if (_isLoading) {
            setState(() => _isLoading = false);
          }

          if (!_hasPerformedInitialSeek && 
              widget.startPositionMs != null && 
              widget.startPositionMs! > 0) {
            
            _hasPerformedInitialSeek = true; 

            await player.pause();
            
            await Future.delayed(const Duration(milliseconds: 400));
            await player.seek(Duration(milliseconds: widget.startPositionMs!));
            debugPrint("=== SUCCESS: WZNOWIONO NA ${widget.startPositionMs} ms ===");
            
            await Future.delayed(const Duration(milliseconds: 100));
            await player.play();
          }
        }
      });
      
      await player.open(
        Media(finalSource, httpHeaders: headers), 
        play: true
      );

      if (!widget.isOffline && widget.baseUrl != null) {
        _startProgressReporting();
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() => _error = l10n.playerError);
        debugPrint("Initialize Error: $e");
      }
    }
  }

  Future<void> _handlePlaybackCompleted() async {
    final autoPlay = await StorageService().getSetting(
      'setting_autoplay',
      defaultValue: true,
    );
    if (!autoPlay) return;

    if (widget.isOffline) {
      await _playNextOffline();
    } else {
      await _playNextOnline();
    }
  }

  Future<void> _playNextOffline() async {
    try {
      final file = File(widget.url);
      final dir = file.parent;
      final fileName = file.path.split(Platform.pathSeparator).last;

      final RegExp regex = RegExp(r'_S(\d+)E(\d+)_');
      final match = regex.firstMatch(fileName);

      if (match != null) {
        final seasonStr = match.group(1)!;
        final epStr = match.group(2)!;

        final nextEpNum = int.parse(epStr) + 1;
        final nextEpStr = nextEpNum.toString().padLeft(epStr.length, '0');

        final searchPattern = '_S${seasonStr}E$nextEpStr';

        final files = dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.mp4'))
            .toList();
        File? nextFile;

        for (var f in files) {
          if (f.path.contains(searchPattern)) {
            nextFile = f;
            break;
          }
        }

        if (nextFile != null && mounted) {
          final nextTitle = nextFile.path
              .split(Platform.pathSeparator)
              .last
              .replaceAll('.mp4', '')
              .replaceAll('_', ' ');

          _isTransitioningToNext = true;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerScreen(
                url: nextFile!.path,
                title: nextTitle,
                itemId: '',
                isOffline: true,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Błąd autoodtwarzania offline: $e");
    }
  }

  Future<void> _playNextOnline() async {
    if (_itemData == null || _itemData!['Type'] != 'Episode') return;

    try {
      final seriesId = _itemData!['SeriesId'];
      final seasonId = _itemData!['SeasonId'];
      if (seriesId == null) return;

      final httpClient = HttpClient()
        ..badCertificateCallback = ((cert, host, port) => true);
      final url =
          '${widget.baseUrl}/Shows/$seriesId/Episodes?seasonId=$seasonId&UserId=${widget.userId}&api_key=${widget.token}';

      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode == 200) {
        final data = jsonDecode(await response.transform(utf8.decoder).join());
        final items = data['Items'] as List?;

        if (items != null) {
          int currentIndex = items.indexWhere(
            (item) => item['Id'] == widget.itemId,
          );

          if (currentIndex != -1 && currentIndex + 1 < items.length) {
            final nextItem = items[currentIndex + 1];

            if (mounted) {
              _isTransitioningToNext = true;

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayerScreen(
                    url:
                        '${widget.baseUrl}/Videos/${nextItem['Id']}/stream.mp4',
                    title: nextItem['Name'],
                    itemId: nextItem['Id'],
                    baseUrl: widget.baseUrl,
                    token: widget.token,
                    userId: widget.userId,
                    isOffline: false,
                  ),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Błąd autoodtwarzania online: $e");
    }
  }

  Future<void> _changeOnlineQuality(int? width, int? bitrate) async {
    if (_selectedWidth == width) return;

    _pendingSeek = player.state.position;

    if (width != null && _selectedWidth == null) {
      _selectedAudioIndex =
          _getTrueJellyfinIndexAudio(
            player.state.track.audio,
            player.state.tracks.audio,
          ) ??
          _selectedAudioIndex;
      _selectedSubtitleIndex =
          _getTrueJellyfinIndexSub(
            player.state.track.subtitle,
            player.state.tracks.subtitle,
          ) ??
          _selectedSubtitleIndex;
    }

    setState(() {
      _selectedWidth = width;
      _selectedBitrate = bitrate;
      _isLoading = true;
    });

    final newUrl = _buildCompatibleUrl(widget.url);
    final headers = widget.token != null
        ? {'X-Emby-Token': widget.token!}
        : null;

    await player.open(Media(newUrl, httpHeaders: headers), play: true);
  }

  void _startProgressReporting() {
    _progressTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (player.state.playing) {
        JellyfinApi().reportPlaybackProgress(
          baseUrl: widget.baseUrl!,
          token: widget.token!,
          userId: widget.userId!,
          itemId: widget.itemId,
          position: player.state.position,
          isPaused: false,
          isStopped: false,
        );
      }
    });
  }

  List<Widget> _buildOnlineQualityOptions() {
    final options = [
      {'label': 'Oryginał (Direct Play)', 'width': null, 'bitrate': null},
      {'label': '1080p (10 Mbps)', 'width': 1920, 'bitrate': 10000000},
      {'label': '720p (4 Mbps)', 'width': 1280, 'bitrate': 4000000},
      {'label': '480p (1.5 Mbps)', 'width': 854, 'bitrate': 1500000},
      {'label': '360p (720 kbps)', 'width': 640, 'bitrate': 720000},
    ];

    return options.map((q) {
      final w = q['width'] as int?;
      final b = q['bitrate'] as int?;
      final isSelected = _selectedWidth == w;

      return ListTile(
        title: Text(
          q['label'] as String,
          style: TextStyle(
            color: isSelected ? Colors.deepPurpleAccent : Colors.white70,
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.check, color: Colors.deepPurpleAccent)
            : null,
        onTap: () {
          _changeOnlineQuality(w, b);
          Navigator.pop(context);
        },
      );
    }).toList();
  }

  List<Widget> _buildOfflineQualityOptions() {
    return player.state.tracks.video.map((t) {
      final isSelected = player.state.track.video == t;
      String label = t.id == 'auto'
          ? 'Automatyczna'
          : t.id == 'no'
          ? 'Wyłącz wideo'
          : '${t.w ?? '?'}x${t.h ?? '?'}';
      return ListTile(
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.deepPurpleAccent : Colors.white70,
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.check, color: Colors.deepPurpleAccent)
            : null,
        onTap: () {
          player.setVideoTrack(t);
          Navigator.pop(context);
        },
      );
    }).toList();
  }

  List<Widget> _buildAudioOptions(BuildContext context, AppLocalizations l10n) {
    if (widget.isOffline) {
      return player.state.tracks.audio.map((t) {
        final isSelected = player.state.track.audio == t;
        String label = t.id == 'auto'
            ? 'Automatyczna'
            : t.id == 'no'
            ? l10n.off
            : (t.title ?? t.language ?? 'Audio ${t.id}');
        return ListTile(
          title: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.deepPurpleAccent : Colors.white70,
            ),
          ),
          trailing: isSelected
              ? const Icon(Icons.check, color: Colors.deepPurpleAccent)
              : null,
          onTap: () {
            player.setAudioTrack(t);
            Navigator.pop(context);
          },
        );
      }).toList();
    } else {
      return _jellyfinAudioStreams.map((audio) {
        final idx = audio['Index'];
        final isSelected = _selectedAudioIndex == idx;
        final label =
            audio['DisplayTitle'] ?? audio['Language'] ?? 'Audio $idx';

        return ListTile(
          title: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.deepPurpleAccent : Colors.white70,
            ),
          ),
          trailing: isSelected
              ? const Icon(Icons.check, color: Colors.deepPurpleAccent)
              : null,
          onTap: () {
            setState(() => _selectedAudioIndex = idx);
            if (_selectedWidth == null) {
              _applyOriginalAudio();
            } else {
              _changeOnlineQuality(_selectedWidth, _selectedBitrate);
            }
            Navigator.pop(context);
          },
        );
      }).toList();
    }
  }

  List<Widget> _buildSubtitleOptions(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    if (widget.isOffline) {
      List<Widget> options = [];
      final navigator = Navigator.of(context);

      // 1. Opcja "Wyłączone"
      options.add(
        ListTile(
          title: Text(
            l10n.off,
            style: TextStyle(
              color:
                  _currentExternalSubtitlePath == null &&
                      player.state.track.subtitle.id == 'no'
                  ? Colors.deepPurpleAccent
                  : Colors.white70,
            ),
          ),
          trailing:
              _currentExternalSubtitlePath == null &&
                  player.state.track.subtitle.id == 'no'
              ? const Icon(Icons.check, color: Colors.deepPurpleAccent)
              : null,
          onTap: () {
            setState(() => _currentExternalSubtitlePath = null);
            player.setSubtitleTrack(SubtitleTrack.no());
            if (context.mounted) navigator.pop();
          },
        ),
      );

      // 2. Ewentualne napisy wbudowane w plik .mp4 (jeśli są)
      final embeddedTracks = player.state.tracks.subtitle.where(
        (t) => t.id != 'no' && t.id != 'auto',
      );
      for (var t in embeddedTracks) {
        final isSelected =
            _currentExternalSubtitlePath == null &&
            player.state.track.subtitle == t;
        options.add(
          ListTile(
            title: Text(
              t.title ?? t.language ?? 'Wbudowane ${t.id}',
              style: TextStyle(
                color: isSelected ? Colors.deepPurpleAccent : Colors.white70,
              ),
            ),
            trailing: isSelected
                ? const Icon(Icons.check, color: Colors.deepPurpleAccent)
                : null,
            onTap: () {
              setState(() => _currentExternalSubtitlePath = null);
              player.setSubtitleTrack(t);
              if (context.mounted) navigator.pop();
            },
          ),
        );
      }

      for (var file in _localSubtitleFiles) {
        final fileName = file.path.split(Platform.pathSeparator).last;
        final parts = fileName.split('.');
        final label = parts.length >= 3
            ? "Napisy (${parts[parts.length - 2].toUpperCase()})"
            : "Napisy Zewnętrzne";

        final isSelected = _currentExternalSubtitlePath == file.path;

        options.add(
          ListTile(
            title: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.deepPurpleAccent : Colors.white70,
              ),
            ),
            trailing: isSelected
                ? const Icon(Icons.check, color: Colors.deepPurpleAccent)
                : null,
            onTap: () {
              setState(() => _currentExternalSubtitlePath = file.path);
              player.setSubtitleTrack(SubtitleTrack.uri(file.path));
              if (context.mounted) navigator.pop();
            },
          ),
        );
      }

      return options;
    } else {
      List<Widget> options = [];
      options.add(
        ListTile(
          title: Text(
            l10n.off,
            style: TextStyle(
              color: _selectedSubtitleIndex == null
                  ? Colors.deepPurpleAccent
                  : Colors.white70,
            ),
          ),
          trailing: _selectedSubtitleIndex == null
              ? const Icon(Icons.check, color: Colors.deepPurpleAccent)
              : null,
          onTap: () async {
            final navigator = Navigator.of(context);
            setState(() => _selectedSubtitleIndex = null);
            if (_selectedWidth == null) {
              _applyOriginalSubtitles();
            } else {
              await _applyExternalSubtitles();
            }
            if (context.mounted) navigator.pop();
          },
        ),
      );

      for (var sub in _jellyfinSubtitleStreams) {
        final idx = sub['Index'];
        final isSelected = _selectedSubtitleIndex == idx;
        final label = sub['DisplayTitle'] ?? sub['Language'] ?? 'Napisy $idx';

        options.add(
          ListTile(
            title: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.deepPurpleAccent : Colors.white70,
              ),
            ),
            trailing: isSelected
                ? const Icon(Icons.check, color: Colors.deepPurpleAccent)
                : null,
            onTap: () async {
              final navigator = Navigator.of(context);
              setState(() => _selectedSubtitleIndex = idx);
              if (_selectedWidth == null) {
                _applyOriginalSubtitles();
              } else {
                await _applyExternalSubtitles();
              }
              if (context.mounted) navigator.pop();
            },
          ),
        );
      }
      return options;
    }
  }

  void _showSettingsMenu(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF171B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                l10n.settings,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const Divider(color: Colors.white24),

            ExpansionTile(
              leading: const Icon(Icons.high_quality, color: Colors.white70),
              title: Text(
                l10n.videoQuality,
                style: const TextStyle(color: Colors.white),
              ),
              iconColor: Colors.white,
              collapsedIconColor: Colors.white70,
              children: widget.isOffline
                  ? _buildOfflineQualityOptions()
                  : _buildOnlineQualityOptions(),
            ),

            ExpansionTile(
              leading: const Icon(Icons.audiotrack, color: Colors.white70),
              title: Text(
                l10n.audioTrack,
                style: const TextStyle(color: Colors.white),
              ),
              iconColor: Colors.white,
              collapsedIconColor: Colors.white70,
              children: _buildAudioOptions(context, l10n),
            ),

            ExpansionTile(
              leading: const Icon(Icons.subtitles, color: Colors.white70),
              title: Text(
                l10n.subtitles,
                style: const TextStyle(color: Colors.white),
              ),
              iconColor: Colors.white,
              collapsedIconColor: Colors.white70,
              children: _buildSubtitleOptions(context, l10n),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();

    if (!widget.isOffline && widget.baseUrl != null) {
      JellyfinApi().reportPlaybackProgress(
        baseUrl: widget.baseUrl!,
        token: widget.token!,
        userId: widget.userId!,
        itemId: widget.itemId,
        position: player.state.position,
        isPaused: false,
        isStopped: true,
      );
    }

    if (!_isTransitioningToNext) {
      audioHandler.detachPlayer();
      audioHandler.stop();
    }

    player.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            MaterialVideoControlsTheme(
              normal: MaterialVideoControlsThemeData(
                topButtonBarMargin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                topButtonBar: [
                  const BackButton(color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.settings,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => _showSettingsMenu(context, l10n),
                  ),
                ],
              ),
              fullscreen: MaterialVideoControlsThemeData(
                topButtonBarMargin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                topButtonBar: [
                  const BackButton(color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.settings,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => _showSettingsMenu(context, l10n),
                  ),
                ],
              ),
              child: Video(
                controller: controller,
                controls: MaterialVideoControls,
                fit: BoxFit.contain,
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: () {
                      final currentPosition = player.state.position;
                      final targetPosition =
                          currentPosition - const Duration(seconds: 10);
                      player.seek(
                        targetPosition < Duration.zero
                            ? Duration.zero
                            : targetPosition,
                      );
                    },
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: () {
                      final currentPosition = player.state.position;
                      final totalDuration = player.state.duration;
                      final targetPosition =
                          currentPosition + const Duration(seconds: 10);
                      player.seek(
                        targetPosition > totalDuration
                            ? totalDuration
                            : targetPosition,
                      );
                    },
                  ),
                ),
              ],
            ),

            if (_isLoading && _error == null)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.deepPurpleAccent,
                ),
              ),

            if (_error != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent, width: 2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.redAccent,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.close),
                      ),
                    ],
                  ),
                ),
              ),

            if (_isLoading && _error == null)
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.8, end: 1.2),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: SvgPicture.asset(
                    'assets/logo.svg',
                    width: 80,
                    height: 80,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
