import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/episode.dart';
import '../services/jellyfin_api.dart';
import '../services/download_service.dart';
import '../widgets/episode_card.dart';
import 'player/player_screen.dart';
import 'details_screen.dart';
import '../models/jellyfin_item.dart';
import '../widgets/ad_banner_widget.dart';
import '../widgets/favorite_button.dart';
import '../widgets/quality_picker.dart';
import 'item_navigation.dart';
import '../widgets/series_header.dart';

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
  Map<String, dynamic>? _seriesDetails;

  @override
  void initState() {
    super.initState();
    _loadEpisodes();
    _loadSeriesDetails();
  }

  Future<void> _loadSeriesDetails() async {
    final data = await JellyfinApi().fetchItemDetails(
      baseUrl: widget.baseUrl,
      token: widget.token,
      userId: widget.userId,
      itemId: widget.series.id,
    );
    if (mounted && data != null) setState(() => _seriesDetails = data);
  }

  /// The episode to offer first: one in progress, else the first unwatched
  /// one after the last watched.
  Episode? get _nextEpisode {
    if (_episodes.isEmpty) return null;
    bool watched(Episode e) {
      if (e.userData?.played ?? false) return true;
      final ticks = e.userData?.playbackPositionTicks;
      final runtime = e.runTimeTicks;
      return ticks != null &&
          runtime != null &&
          runtime > 0 &&
          ticks / runtime >= 0.95;
    }

    for (final e in _episodes) {
      final ticks = e.userData?.playbackPositionTicks ?? 0;
      if (ticks > 0 && !watched(e)) return e;
    }
    final lastWatched = _episodes.lastIndexWhere(watched);
    for (var i = lastWatched + 1; i < _episodes.length; i++) {
      if (!watched(_episodes[i])) return _episodes[i];
    }
    return _episodes.firstWhere(
      (e) => !watched(e),
      orElse: () => _episodes.first,
    );
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
      if (!mounted) return;
      setState(() {
        _episodes = eps;
        _isLoading = false;
      });
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
    } catch (e) {
      debugPrint("Błąd ładowania odcinków (${e.runtimeType}).");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToEpisodeDetails(Episode episode) async {
    await Navigator.push(
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
    if (mounted) {
      _loadEpisodes();
    }
  }

  Future<void> _startDownloadOffline(
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

  Future<void> _downloadSeasonWithQuality(
    List<Episode> seasonEpisodes,
    int? maxWidth,
    int? bitrate,
    String qualityLabel,
    AppLocalizations l10n,
  ) async {
    final missing = seasonEpisodes
        .where((ep) => _isDownloadedMap[ep.id] == null)
        .toList();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          missing.isNotEmpty
              ? l10n.queueingEpisodes(missing.length)
              : l10n.allDownloaded,
        ),
      ),
    );
    // One after another: queuing a whole season at once used to start every
    // preparation in parallel and could overload the app.
    for (final ep in missing) {
      try {
        await _startDownloadOffline(ep, maxWidth, bitrate, qualityLabel);
      } catch (error) {
        debugPrint('Nie udało się dodać odcinka (${error.runtimeType}).');
      }
    }
  }

  void _showDownloadSeasonOptions(
    BuildContext context,
    List<Episode> seasonEpisodes,
    AppLocalizations l10n,
  ) {
    showQualityPicker(
      context,
      title: seasonEpisodes.length == 1
          ? l10n.selectQuality
          : l10n.selectQualitySeason(
              seasonEpisodes.first.parentIndexNumber ?? 0,
            ),
      mediaInfo: _firstEpisodeMediaInfo,
      onSelect: (w, b, l) =>
          _downloadSeasonWithQuality(seasonEpisodes, w, b, l, l10n),
    );
  }

  void _playOnline(Episode episode) {
    final streamUrl = onlineStreamUrl(widget.baseUrl, episode.id);
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

    final nextEpisode = _nextEpisode;
    final isFavorite =
        (_seriesDetails?['UserData'] as Map?)?['IsFavorite'] == true ||
        (widget.series.userData?.isFavorite ?? false);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.series.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FavoriteButton(
              key: ValueKey('fav-$isFavorite'),
              baseUrl: widget.baseUrl,
              token: widget.token,
              userId: widget.userId,
              itemId: widget.series.id,
              initialIsFavorite: isFavorite,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            )
          : RefreshIndicator(
              onRefresh: () async {
                _loadEpisodes();
                await _loadSeriesDetails();
              },
              child: ListView(
                children: [
                  SeriesHeader(
                    seriesId: widget.series.id,
                    details: _seriesDetails,
                    baseUrl: widget.baseUrl,
                    token: widget.token,
                    nextEpisode: nextEpisode,
                    onPlayNext: nextEpisode == null
                        ? null
                        : () => _navigateToEpisodeDetails(nextEpisode),
                    onUnwantedChanged: _loadSeriesDetails,
                  ),
                  if (_episodes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.noEpisodes,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  ...groupedEpisodes.entries.map((entry) {
                    final seasonEpisodes = entry.value;
                    final bool expandedByDefault =
                        groupedEpisodes.keys.first == entry.key;
                    return ExpansionTile(
                      key: PageStorageKey<int>(entry.key),
                      initiallyExpanded: expandedByDefault,
                      collapsedBackgroundColor: Colors.white12,
                      backgroundColor: Colors.white10,
                      leading: const Icon(
                        Icons.video_collection,
                        color: Colors.white,
                      ),
                      title: Row(
                        children: [
                          Text(
                            entry.key == 0
                                ? l10n.specials
                                : l10n.seasonNumber(entry.key),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Badge postępu sezonu
                          _SeasonBadge(episodes: seasonEpisodes),
                        ],
                      ),
                      controlAffinity: ListTileControlAffinity.platform,

                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: Column(
                            children: [
                              SizedBox(
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
                                    l10n.downloadSeason,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Colors.white24,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
                                    onTap: () =>
                                        _navigateToEpisodeDetails(episode),
                                    child: EpisodeCard(
                                      episode: episode,
                                      baseUrl: widget.baseUrl,
                                      token: widget.token,
                                      userId: widget.userId,
                                      onDownload: () =>
                                          _showDownloadSeasonOptions(context, [
                                            episode,
                                          ], l10n),
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
                                            onPressed: () =>
                                                _playOnline(episode),
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
                                                  onPressed: () =>
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              PlayerScreen(
                                                                url: localPath,
                                                                title: episode
                                                                    .name,
                                                                itemId:
                                                                    episode.id,
                                                                baseUrl: widget
                                                                    .baseUrl,
                                                                token: widget
                                                                    .token,
                                                                userId: widget
                                                                    .userId,
                                                                isOffline: true,
                                                              ),
                                                        ),
                                                      ),
                                                  icon: const Icon(
                                                    Icons.download_done,
                                                    color: Colors.greenAccent,
                                                  ),
                                                  label: Text(
                                                    l10n.watchOffline,
                                                    style: const TextStyle(
                                                      color: Colors.greenAccent,
                                                    ),
                                                  ),
                                                )
                                              : activeDl != null
                                              ? Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        activeDl.progressText,
                                                        style: const TextStyle(
                                                          color: Colors
                                                              .greenAccent,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    if (!activeDl.isDownloaded)
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.close,
                                                          size: 18,
                                                          color: Colors.white54,
                                                        ),
                                                        tooltip:
                                                            l10n.cancelDownload,
                                                        onPressed: () =>
                                                            downloadService
                                                                .cancelDownload(
                                                                  episode.id,
                                                                ),
                                                      ),
                                                  ],
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
                                                    l10n.download,
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
                                  const Divider(
                                    color: Colors.white10,
                                    height: 1,
                                  ),
                                ],
                              );
                            },
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),
      bottomNavigationBar: const AdBannerWidget(),
    );
  }
}

class _SeasonBadge extends StatelessWidget {
  final List<Episode> episodes;
  const _SeasonBadge({required this.episodes});

  @override
  Widget build(BuildContext context) {
    int total = episodes.length;
    int watched = episodes.where((ep) {
      final isPlayed = ep.userData?.played ?? false;
      if (isPlayed) return true;
      final num? ticks = ep.userData?.playbackPositionTicks;
      final num? runtime = ep.runTimeTicks;
      if (ticks != null && runtime != null && runtime > 0) {
        return (ticks / runtime) >= 0.95;
      }
      return false;
    }).length;

    if (total == 0) return const SizedBox.shrink();

    final bool allWatched = watched >= total;
    final Color color = allWatched
        ? Colors.greenAccent
        : Colors.deepPurpleAccent;
    final IconData icon = allWatched
        ? Icons.check_circle
        : Icons.visibility_off;
    final String text = "$watched/$total";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
