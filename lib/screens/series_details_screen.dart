import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/movie.dart';
import '../models/episode.dart';
import '../services/jellyfin_api.dart';
import '../services/download_service.dart';
import '../widgets/episode_card.dart';
import 'player_screen.dart';
import 'details_screen.dart';
import '../models/jellyfin_item.dart';
import '../widgets/ad_banner_widget.dart';

class SeriesDetailsScreen extends StatefulWidget {
  final JellyfinItem series;
  final String baseUrl;
  final String token;
  final String userId;

  const SeriesDetailsScreen({
    super.key,
    required this.series,
    required this.baseUrl,
    required this.token,
    required this.userId,
  });

  @override
  State<SeriesDetailsScreen> createState() => _SeriesDetailsScreenState();
}

class _SeriesDetailsScreenState extends State<SeriesDetailsScreen> {
  List<Episode> _episodes = [];
  bool _isLoading = true;
  Map<String, String?> _isDownloadedMap = {};
  Map<String, dynamic>? _firstEpisodeMediaInfo;

  @override
  void initState() {
    super.initState();
    _loadEpisodes();
  }

  Map<int, List<Episode>> _groupEpisodesBySeason(List<Episode> episodes) {
    Map<int, List<Episode>> grouped = {};
    for (var ep in episodes) {
      int season = ep.parentIndexNumber ?? 1;
      if (!grouped.containsKey(season)) {
        grouped[season] = [];
      }
      grouped[season]!.add(ep);
    }
    return grouped;
  }

  Future<void> _scanDiskForExistingFiles(List<Episode> episodes) async {
    final service = DownloadService();
    Map<String, String?> newDownloadedMap = {};

    for (var episode in episodes) {
      final path = await service.findLocalFile(
        episode,
        seriesOverrideName: widget.series.name,
      );
      newDownloadedMap[episode.id] = path;
    }

    if (mounted) {
      setState(() => _isDownloadedMap = newDownloadedMap);
    }
  }

  void _loadEpisodes() async {
    final api = JellyfinApi();
    try {
      final eps = await api.fetchEpisodes(
        widget.baseUrl,
        widget.token,
        widget.userId,
        widget.series.id,
      );
      _scanDiskForExistingFiles(eps);

      if (eps.isNotEmpty) {
        final mediaInfo = await api.fetchItemMediaInfo(
          widget.baseUrl,
          widget.token,
          eps[0].id,
        );
        if (mounted) {
          setState(() => _firstEpisodeMediaInfo = mediaInfo);
        }
      }

      setState(() {
        _episodes = eps;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Błąd ładowania odcinków: $e");
      setState(() => _isLoading = false);
    }
  }

  void _navigateToEpisodeDetails(Episode episode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailsScreen(
          item: episode,
          baseUrl: widget.baseUrl,
          token: widget.token,
          userId: widget.userId,
        ),
      ),
    );
  }

  void _startDownloadOffline(
    Episode episode,
    int? maxWidth,
    int? bitrate,
    String qualityLabel,
  ) async {
    final service = DownloadService();

    await service.startDownload(
      item: episode,
      baseUrl: widget.baseUrl,
      token: widget.token,
      qualityLabel: qualityLabel,
      maxWidth: maxWidth,
      bitrate: bitrate,
      seriesOverrideName: widget.series.name,
    );
  }

  void _downloadSeasonWithQuality(
    List<Episode> seasonEpisodes,
    int? maxWidth,
    int? bitrate,
    String qualityLabel,
    AppLocalizations l10n,
  ) {
    int added = 0;
    for (var ep in seasonEpisodes) {
      final isDownloaded = _isDownloadedMap[ep.id] != null;
      if (!isDownloaded) {
        _startDownloadOffline(ep, maxWidth, bitrate, qualityLabel);
        added++;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added > 0
              ? "Kolejkowanie $added odcinków (sezon ${seasonEpisodes.first.parentIndexNumber})"
              : "Wszystko już pobrane!",
        ),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }

  void _showDownloadSeasonOptions(
    BuildContext context,
    List<Episode> seasonEpisodes,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Sezon ${seasonEpisodes.first.parentIndexNumber} - wybierz jakość",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ..._buildQualityOptions(
            context,
            (w, b, l) =>
                _downloadSeasonWithQuality(seasonEpisodes, w, b, l, l10n),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildQualityOptions(
    BuildContext context,
    void Function(int?, int?, String) onSelect,
  ) {
    final qualityOptions = DownloadService.getQualityOptions(
      _firstEpisodeMediaInfo,
    );

    return qualityOptions
        .map(
          (quality) => _qTile(
            context,
            quality['label'] as String,
            quality['icon'] as IconData,
            quality['color'] as Color,
            quality['width'] as int?,
            quality['bitrate'] as int?,
            quality['qualityLabel'] as String,
            onSelect,
          ),
        )
        .toList();
  }

  Widget _qTile(context, title, icon, color, w, b, label, onSelect) => ListTile(
    leading: Icon(icon, color: color),
    title: Text(title, style: const TextStyle(color: Colors.white)),
    onTap: () {
      Navigator.pop(context);
      onSelect(w, b, label);
    },
  );

  void _playOnline(Episode episode) {
    String streamUrl =
        "${widget.baseUrl}/Videos/${episode.id}/stream.mp4"
        "?Static=false&VideoCodec=h265&AudioCodec=aac";
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          url: streamUrl,
          title:
              "S${episode.parentIndexNumber}E${episode.indexNumber} - ${episode.name}",
          token: widget.token,
          userId: widget.userId,
          itemId: episode.id,
          baseUrl: widget.baseUrl,
          isOffline: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final downloadService = DownloadService();
    final Map<int, List<Episode>> groupedEpisodes = _groupEpisodesBySeason(
      _episodes,
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.series.name)),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            )
          : ListView(
              children: groupedEpisodes.entries.map((entry) {
                final seasonEpisodes = entry.value;
                final bool expandedByDefault =
                    groupedEpisodes.keys.first == entry.key;
                return ExpansionTile(
                  initiallyExpanded: expandedByDefault,
                  collapsedBackgroundColor: Colors.white12,
                  backgroundColor: Colors.white10,
                  leading: const Icon(
                    Icons.video_collection,
                    color: Colors.white,
                  ),
                  title: Row(
                    children: [
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "SEZON ${entry.key}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  controlAffinity: ListTileControlAffinity.platform,

                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showDownloadSeasonOptions(
                            context,
                            seasonEpisodes,
                            l10n,
                          ),
                          icon: const Icon(
                            Icons.download_for_offline,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: Text(
                            "Pobierz sezon",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    ...seasonEpisodes.map((episode) {
                      return ValueListenableBuilder<
                        Map<String, DownloadStatus>
                      >(
                        valueListenable: downloadService.activeDownloads,
                        builder: (context, activeDownloadsMap, _) {
                          final String? localPath =
                              _isDownloadedMap[episode.id];
                          final activeDl = activeDownloadsMap[episode.id];

                          return Column(
                            children: [
                              GestureDetector(
                                onTap: () => _navigateToEpisodeDetails(episode),
                                child: EpisodeCard(
                                  episode: episode,
                                  baseUrl: widget.baseUrl,
                                  token: widget.token,
                                  onDownload: () =>
                                      _navigateToEpisodeDetails(episode),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextButton.icon(
                                        onPressed: () => _playOnline(episode),
                                        icon: const Icon(
                                          Icons.play_arrow,
                                          color: Colors.white,
                                        ),
                                        label: Text(
                                          l10n.watchOnline,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: localPath != null
                                          ? TextButton.icon(
                                              onPressed: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      PlayerScreen(
                                                        url: localPath,
                                                        title: episode.name,
                                                        itemId: episode.id,
                                                        baseUrl: widget.baseUrl,
                                                        token: widget.token,
                                                        userId: widget.userId,
                                                        isOffline: true,
                                                      ),
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.download_done,
                                                color: Colors.greenAccent,
                                              ),
                                              label: const Text(
                                                "OFFLINE",
                                                style: TextStyle(
                                                  color: Colors.greenAccent,
                                                ),
                                              ),
                                            )
                                          : activeDl != null
                                          ? Center(
                                              child: Text(
                                                activeDl.progressText,
                                                style: const TextStyle(
                                                  color: Colors.greenAccent,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            )
                                          : TextButton.icon(
                                              onPressed: () {
                                                _showDownloadSeasonOptions(
                                                  context,
                                                  [episode],
                                                  l10n,
                                                );
                                              },
                                              icon: const Icon(
                                                Icons.download,
                                                color: Colors.white54,
                                              ),
                                              label: Text(
                                                "POBIERZ", // Do dodania w .arb
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                              if (activeDl != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 5,
                                  ),
                                  child: LinearProgressIndicator(
                                    value: activeDl.progressValue < 0
                                        ? null
                                        : activeDl.progressValue,
                                    color: Colors.greenAccent,
                                    backgroundColor: Colors.white10,
                                  ),
                                ),
                              const Divider(color: Colors.white10, height: 1),
                            ],
                          );
                        },
                      );
                    }).toList(),
                  ],
                );
              }).toList(),
            ),
      bottomNavigationBar: const AdBannerWidget(),
    );
  }
}
