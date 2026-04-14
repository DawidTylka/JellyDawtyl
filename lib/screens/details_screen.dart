import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/app_localizations.dart';
import '../models/jellyfin_item.dart';
import '../services/download_service.dart';
import 'player/player_screen.dart';
import 'package:dio/dio.dart';
import '../services/jellyfin_api.dart';
import '../widgets/ad_banner_widget.dart';

class DetailsScreen extends StatefulWidget {
  final JellyfinItem item;
  final String baseUrl;
  final String token;
  final String userId;

  const DetailsScreen({
    super.key,
    required this.item,
    required this.baseUrl,
    required this.token,
    required this.userId,
  });

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  String? _localFilePath;
  String? _fullOverview;
  Map<String, dynamic>? _mediaInfo;

  @override
  void initState() {
    super.initState();
    _loadFullDetails();
    _loadMediaInfo();
    _scanDiskForExistingFile();

    DownloadService().activeDownloads.addListener(_onDownloadStatusChanged);
  }

  @override
  void dispose() {
    // Pamiętaj o usunięciu nasłuchiwania przy zamykaniu ekranu
    DownloadService().activeDownloads.removeListener(_onDownloadStatusChanged);
    super.dispose();
  }

  void _onDownloadStatusChanged() {
    if (!DownloadService().activeDownloads.value.containsKey(widget.item.id)) {
      _scanDiskForExistingFile();
    }
  }

  Future<void> _loadFullDetails() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        "${widget.baseUrl}/Items/${widget.item.id}",
        options: Options(headers: {"X-Emby-Token": widget.token}),
      );

      if (response.data != null) {
        if (mounted) {
          setState(() {
            _fullOverview =
                response.data['Overview'] ?? response.data['SeriesOverview'];
          });
        }
      }
    } catch (e) {
      debugPrint("Błąd ładowania szczegółów: $e");
    }
  }

  Future<void> _loadMediaInfo() async {
    final api = JellyfinApi();
    final info = await api.fetchItemMediaInfo(
      widget.baseUrl,
      widget.token,
      widget.item.id,
    );
    if (mounted) setState(() => _mediaInfo = info);
  }

  Future<void> _scanDiskForExistingFile() async {
    final path = await DownloadService().findLocalFile(widget.item);
    if (mounted) setState(() => _localFilePath = path);
  }

  void _startDownloadOffline(
    int? maxWidth,
    int? bitrate,
    String qualityLabel,
  ) async {
    final service = DownloadService();
    await service.startDownload(
      item: widget.item,
      baseUrl: widget.baseUrl,
      token: widget.token,
      qualityLabel: qualityLabel,
      maxWidth: maxWidth,
      bitrate: bitrate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloadService = DownloadService();
    final bool isEpisode = widget.item.type == "Episode";
    final l10n = AppLocalizations.of(context)!;

    final String imageUrl = isEpisode
        ? "${widget.baseUrl}/Items/${widget.item.id}/Images/Primary?quality=90"
        : "${widget.baseUrl}/Items/${widget.item.id}/Images/Backdrop?quality=90&EnableParentDesigns=true";

    final num? positionTicks = widget.item.userData?.playbackPositionTicks;
    final num? runTimeTicks = widget.item.runTimeTicks;
    
    int resumePositionMs = 0;
    double progress = 0.0;
    bool canResume = false;

    if (positionTicks != null && positionTicks > 0) {
      resumePositionMs = (positionTicks / 10000).floor();
      
      if (runTimeTicks != null && runTimeTicks > 0) {
        progress = positionTicks / runTimeTicks;
        if (progress > 0.01 && progress < 0.95) {
            canResume = true;
        }
      } else {
        canResume = true; 
      }
    }

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              httpHeaders: {"X-Emby-Token": widget.token},
              height: 300,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 300,
                color: Colors.black,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                height: 300,
                color: Colors.grey[900],
                child: const Icon(Icons.movie, color: Colors.white24, size: 80),
              ),
            ),

            if (canResume && progress > 0)
              LinearProgressIndicator(
                 value: progress,
                 backgroundColor: Colors.grey[900],
                 color: Colors.deepPurpleAccent,
                 minHeight: 4.0,
              ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEpisode
                        ? "S${widget.item.parentIndexNumber ?? 0}E${widget.item.indexNumber ?? 0} - ${widget.item.name}"
                        : widget.item.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _fullOverview ?? l10n.noDescription,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 30),

                  ValueListenableBuilder<Map<String, DownloadStatus>>(
                    valueListenable: downloadService.activeDownloads,
                    builder: (context, activeDownloadsMap, _) {
                      final activeDownload = activeDownloadsMap[widget.item.id];
                      return Column(
                        children: [
                          if (canResume) ...[
                            _buildActionButton(
                              l10n.continueWatching,
                              Icons.play_circle_fill,
                              Colors.deepPurpleAccent,
                              () => _playVideo(false, startPositionMs: resumePositionMs),
                            ),
                            SizedBox(height: 12),
                            _buildActionButton(
                              l10n.fromBeginning,
                              Icons.replay,
                              Colors.white,
                              () => _playVideo(false, startPositionMs: 0),
                            ),
                          ] else ...[
                            _buildActionButton(
                              l10n.watchOnline,
                              Icons.play_arrow,
                              Colors.white,
                              () => _playVideo(false),
                            ),
                          ],
                          if (activeDownload != null) ...[
                            const SizedBox(height: 12),
                            _buildProgressBar(activeDownload, l10n),
                          ],
                          if (_localFilePath != null) ...[
                            const SizedBox(height: 12),
                            _buildActionButton(
                              l10n.watchOffline,
                              Icons.download_done,
                              Colors.greenAccent,
                              () => _playVideo(true),
                            ),
                          ],
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _showDownloadOptions(context, l10n),
                            icon: Icon(
                              _localFilePath != null
                                  ? Icons.refresh
                                  : Icons.download,
                              color: Colors.white70,
                            ),
                            label: Text(
                              _localFilePath != null
                                  ? l10n.downloadAgain
                                  : l10n.downloadToMemory,
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              minimumSize: const Size(double.infinity, 45),
                              foregroundColor: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _showSubtitleDownloadOptions(context, l10n),
                            icon: const Icon(
                              Icons.subtitles_outlined,
                              color: Colors.white70,
                            ),
                            label: const Text("POBIERZ NAPISY (SRT)"),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              minimumSize: const Size(double.infinity, 45),
                              foregroundColor: Colors.white70,
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AdBannerWidget(),
    );
  }

  void _showSubtitleDownloadOptions(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    List subtitleStreams = [];

    if (_mediaInfo != null && _mediaInfo!['raw'] != null) {
      final rawData = _mediaInfo!['raw'];
      if (rawData['MediaSources'] != null) {
        final sources = rawData['MediaSources'] as List;
        if (sources.isNotEmpty) {
          final streams = sources[0]['MediaStreams'] as List?;
          if (streams != null) {
            subtitleStreams = streams
                .where((s) => s['Type'] == 'Subtitle')
                .toList();
          }
        }
      }
    }

    if (subtitleStreams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Brak dostępnych napisów dla tego materiału"),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            title: Text(
              "Wybierz napisy do pobrania",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...subtitleStreams.map((sub) {
            final String lang = sub['Language'] ?? "Nieznany";
            final String title =
                sub['DisplayTitle'] ?? "Napisy ${sub['Index']}";

            return ListTile(
              leading: const Icon(Icons.subtitles, color: Colors.blueAccent),
              title: Text(title, style: const TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await DownloadService().downloadSubtitles(
                    item: widget.item,
                    baseUrl: widget.baseUrl,
                    token: widget.token,
                    subtitleIndex: sub['Index'],
                    languageName: lang,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Pobrano: $title"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Błąd zapisu napisów"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            );
          }),
        ],
      ),
    );
  }

  void _playVideo(bool offline, {int? startPositionMs}) {
    String url = offline
        ? _localFilePath!
        : "${widget.baseUrl}/Videos/${widget.item.id}/stream.mp4"
              "?Static=false&VideoCodec=h265&AudioCodec=aac";
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          url: url,
          title: widget.item.name,
          itemId: widget.item.id,
          baseUrl: widget.baseUrl,
          token: widget.token,
          userId: widget.userId,
          isOffline: offline,
          startPositionMs: startPositionMs,
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.black),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }

  List<Widget> _buildQualityList(AppLocalizations l10n) {
    List<Widget> children = [
      ListTile(
        title: Text(
          "Wybierz jakość pobierania",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    ];

    final qualityOptions = DownloadService.getQualityOptions(_mediaInfo);
    for (final quality in qualityOptions) {
      children.add(
        _qListTile(
          context,
          quality['label'] as String,
          quality['icon'] as IconData,
          quality['color'] as Color,
          quality['width'] as int?,
          quality['bitrate'] as int?,
          quality['qualityLabel'] as String,
        ),
      );
    }
    return children;
  }

  void _showDownloadOptions(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.only(bottom: 20, top: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _buildQualityList(l10n),
        ),
      ),
    );
  }

  Widget _qListTile(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    int? w,
    int? b,
    String label,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context);
        _startDownloadOffline(w, b, label);
      },
    );
  }

  Widget _buildProgressBar(DownloadStatus status, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "${l10n.downloading}: ${status.progressText}",
          style: const TextStyle(
            color: Colors.greenAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: status.progressValue < 0 ? null : status.progressValue,
          color: Colors.greenAccent,
          backgroundColor: Colors.white10,
        ),
      ],
    );
  }
}
