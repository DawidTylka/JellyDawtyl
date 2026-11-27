import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/episode.dart';
import '../models/jellyfin_item.dart';
import '../models/movie.dart';
import '../services/download_service.dart';
import '../services/jellyfin_api.dart';
import '../utils/html_description.dart';
import '../utils/jellyfin_auth.dart';
import '../widgets/ad_banner_widget.dart';
import '../widgets/favorite_button.dart';
import '../widgets/quality_picker.dart';
import 'item_navigation.dart';
import '../widgets/unwanted_actions.dart';
import 'player/player_screen.dart';
import 'series_details_screen.dart';

/// Details of a movie or a single episode.
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

const _accent = Colors.deepPurpleAccent;

class _DetailsScreenState extends State<DetailsScreen> {
  String? _localFilePath;
  Map<String, dynamic>? _details;
  Map<String, dynamic>? _mediaInfo;
  List<Episode> _adjacent = const [];
  late bool _isPlayed;
  bool _isFavorite = false;
  bool _isUpdatingPlayed = false;
  bool _playedWasManuallyChanged = false;
  bool _overviewExpanded = false;
  int _favoriteButtonKey = 0;

  JellyfinItem get item => widget.item;
  bool get _isEpisode => item.type == 'Episode';

  @override
  void initState() {
    super.initState();
    _isPlayed = item.userData?.played ?? false;
    _isFavorite = item.userData?.isFavorite ?? false;
    _loadFullDetails();
    _loadMediaInfo();
    _loadAdjacentEpisodes();
    _scanDiskForExistingFile();
    DownloadService().activeDownloads.addListener(_onDownloadStatusChanged);
  }

  @override
  void dispose() {
    DownloadService().activeDownloads.removeListener(_onDownloadStatusChanged);
    super.dispose();
  }

  void _onDownloadStatusChanged() {
    if (!DownloadService().activeDownloads.value.containsKey(item.id)) {
      _scanDiskForExistingFile();
    }
  }

  Future<void> _loadFullDetails() async {
    final data = await JellyfinApi().fetchItemDetails(
      baseUrl: widget.baseUrl,
      token: widget.token,
      userId: widget.userId,
      itemId: item.id,
    );
    if (data == null || !mounted) return;
    setState(() {
      _details = data;
      final userData = data['UserData'];
      if (userData is Map) {
        if (!_playedWasManuallyChanged && userData['Played'] is bool) {
          _isPlayed = userData['Played'] as bool;
        }
        final favorite = userData['IsFavorite'] == true;
        if (favorite != _isFavorite) {
          _isFavorite = favorite;
          _favoriteButtonKey++;
        }
      }
    });
  }

  Future<void> _loadMediaInfo() async {
    final info = await JellyfinApi().fetchItemMediaInfo(
      widget.baseUrl,
      widget.token,
      item.id,
    );
    if (mounted) setState(() => _mediaInfo = info);
  }

  Future<void> _loadAdjacentEpisodes() async {
    if (!_isEpisode || item.seriesId == null) return;
    final episodes = await JellyfinApi().fetchAdjacentEpisodes(
      baseUrl: widget.baseUrl,
      token: widget.token,
      userId: widget.userId,
      seriesId: item.seriesId!,
      episodeId: item.id,
    );
    if (mounted) setState(() => _adjacent = episodes);
  }

  Future<void> _togglePlayed() async {
    if (_isUpdatingPlayed) return;
    final nextValue = !_isPlayed;
    setState(() {
      _isPlayed = nextValue;
      _isUpdatingPlayed = true;
      _playedWasManuallyChanged = true;
    });

    final success = await JellyfinApi().setPlayed(
      baseUrl: widget.baseUrl,
      token: widget.token,
      userId: widget.userId,
      itemId: item.id,
      played: nextValue,
    );

    if (!mounted) return;
    setState(() {
      _isUpdatingPlayed = false;
      if (!success) {
        _isPlayed = !nextValue;
        _playedWasManuallyChanged = false;
      }
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.watchedUpdateError),
        ),
      );
    }
  }

  Future<void> _scanDiskForExistingFile() async {
    final path = await DownloadService().findLocalFile(item);
    if (mounted) setState(() => _localFilePath = path);
  }

  void _startDownloadOffline(int? maxWidth, int? bitrate, String qualityLabel) {
    DownloadService().startDownload(
      item: item,
      baseUrl: widget.baseUrl,
      token: widget.token,
      qualityLabel: qualityLabel,
      maxWidth: maxWidth,
      bitrate: bitrate,
      // "Download again" replaces the existing copy of this item.
      force: _localFilePath != null,
    );
  }

  void _openSeries() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeriesDetailsScreen(
          series: Movie(
            id: item.seriesId!,
            name: item.seriesName ?? _details?['SeriesName'] as String? ?? '',
            type: 'Series',
          ),
          baseUrl: widget.baseUrl,
          token: widget.token,
          userId: widget.userId,
        ),
      ),
    );
  }

  void _openEpisode(Episode episode) => openItemDetails(
    context,
    episode,
    baseUrl: widget.baseUrl,
    token: widget.token,
    userId: widget.userId,
    replace: true,
  );

  void _playVideo(bool offline, {int? startPositionMs}) {
    final url = offline
        ? _localFilePath!
        : onlineStreamUrl(widget.baseUrl, item.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          url: url,
          title: item.name,
          itemId: item.id,
          baseUrl: widget.baseUrl,
          token: widget.token,
          userId: widget.userId,
          isOffline: offline,
          startPositionMs: startPositionMs,
        ),
      ),
    ).then((_) {
      // Progress and watched state change while playing.
      if (mounted) _loadFullDetails();
    });
  }

  // ---------------------------------------------------------------- data

  int? get _positionTicks {
    final userData = _details?['UserData'];
    if (userData is Map && userData['PlaybackPositionTicks'] is int) {
      return userData['PlaybackPositionTicks'] as int;
    }
    return item.userData?.playbackPositionTicks;
  }

  int? get _runTimeTicks =>
      (_details?['RunTimeTicks'] as int?) ?? item.runTimeTicks;

  Map<String, dynamic>? get _mediaSource {
    final raw = _mediaInfo?['raw'];
    final sources =
        _details?['MediaSources'] ?? (raw is Map ? raw['MediaSources'] : null);
    if (sources is List && sources.isNotEmpty && sources.first is Map) {
      return Map<String, dynamic>.from(sources.first as Map);
    }
    return null;
  }

  List<Map<String, dynamic>> _streams(String type) {
    final streams = _mediaSource?['MediaStreams'] ?? _details?['MediaStreams'];
    if (streams is! List) return const [];
    return streams
        .whereType<Map<dynamic, dynamic>>()
        .map(Map<String, dynamic>.from)
        .where((s) => s['Type'] == type)
        .toList();
  }

  static String formatDuration(AppLocalizations l10n, Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) return l10n.durationHoursMinutes(hours, minutes);
    return l10n.durationMinutes(d.inMinutes < 1 ? 1 : d.inMinutes);
  }

  static Duration _ticks(int ticks) => Duration(microseconds: ticks ~/ 10);

  static String resolutionLabel(int? width, int? height) {
    final w = width ?? 0;
    final h = height ?? 0;
    if (w >= 3200 || h >= 2000) return '4K';
    if (w >= 2400 || h >= 1400) return '1440p';
    if (w >= 1800 || h >= 1000) return '1080p';
    if (w >= 1200 || h >= 700) return '720p';
    if (h > 0) return '${h}p';
    return '';
  }

  static String channelsLabel(int? channels) {
    switch (channels) {
      case null:
        return '';
      case 1:
        return 'Mono';
      case 2:
        return 'Stereo';
      case 6:
        return '5.1';
      case 8:
        return '7.1';
      default:
        return '${channels}ch';
    }
  }

  static String _fileSize(int bytes) {
    if (bytes >= 1 << 30) {
      return '${(bytes / (1 << 30)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1 << 20)).toStringAsFixed(0)} MB';
  }

  static String _streamLabel(Map<String, dynamic> stream) {
    return stream['DisplayTitle'] as String? ??
        stream['Title'] as String? ??
        stream['Language'] as String? ??
        '?';
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final description = cleanHtmlDescription(
      _details?['Overview'] as String? ??
          item.overview ??
          _details?['SeriesOverview'] as String?,
    );

    final positionTicks = _positionTicks;
    final runTimeTicks = _runTimeTicks;
    var resumePositionMs = 0;
    var progress = 0.0;
    var canResume = false;
    var isCompletelyWatched = _isPlayed;
    if (positionTicks != null && positionTicks > 0) {
      resumePositionMs = positionTicks ~/ 10000;
      if (runTimeTicks != null && runTimeTicks > 0) {
        progress = positionTicks / runTimeTicks;
        if (progress > 0.01 && progress < 0.95) canResume = true;
        if (progress >= 0.95 && !_playedWasManuallyChanged) {
          isCompletelyWatched = true;
        }
      } else {
        canResume = true;
      }
    }
    final showResume = canResume && !isCompletelyWatched;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _isPlayed ? l10n.markUnwatched : l10n.markWatched,
            onPressed: _isUpdatingPlayed ? null : _togglePlayed,
            icon: _isUpdatingPlayed
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isPlayed ? Icons.check_circle : Icons.check_circle_outline,
                    color: _isPlayed ? Colors.greenAccent : Colors.white,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FavoriteButton(
              key: ValueKey(_favoriteButtonKey),
              baseUrl: widget.baseUrl,
              token: widget.token,
              userId: widget.userId,
              itemId: item.id,
              initialIsFavorite: _isFavorite,
              onChanged: (value) => _isFavorite = value,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          _loadFullDetails(),
          _loadAdjacentEpisodes(),
          _scanDiskForExistingFile(),
        ]),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHero(context),
              if (showResume && progress > 0)
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[900],
                  color: _accent,
                  minHeight: 4,
                ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._buildHeading(l10n),
                        const SizedBox(height: 12),
                        _buildMetaRow(
                          context,
                          l10n,
                          isCompletelyWatched: isCompletelyWatched,
                          remainingTicks: showResume && runTimeTicks != null
                              ? runTimeTicks - (positionTicks ?? 0)
                              : null,
                        ),
                        const SizedBox(height: 20),
                        _buildActions(
                          l10n,
                          canResume: showResume,
                          resumePositionMs: resumePositionMs,
                        ),
                        const SizedBox(height: 16),
                        UnwantedActions(
                          baseUrl: widget.baseUrl,
                          token: widget.token,
                          itemId: item.id,
                          onChanged: (status) {
                            // "Nieulubione" also removes the favorite.
                            if (status.unwanted) _loadFullDetails();
                          },
                        ),
                        ..._buildTagline(),
                        const SizedBox(height: 20),
                        _buildOverview(l10n, description),
                        ..._buildGenresAndCrew(l10n),
                        ..._buildCast(l10n),
                        ..._buildChapters(l10n),
                        ..._buildAdjacent(l10n),
                        _buildTechnicalDetails(l10n),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AdBannerWidget(),
    );
  }

  Widget _buildHero(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 9 / 16).clamp(220.0, 420.0);
    final base = widget.baseUrl;
    final primary =
        '$base/Items/${item.id}/Images/Primary?quality=90&fillWidth=1280';
    final backdrop =
        '$base/Items/${item.id}/Images/Backdrop?quality=90&fillWidth=1280';
    final seriesBackdrop = item.seriesId == null
        ? null
        : '$base/Items/${item.seriesId}/Images/Backdrop?quality=90&fillWidth=1280';
    final candidates = _isEpisode
        ? [primary, ?seriesBackdrop]
        : [backdrop, primary];

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _FallbackImage(
            urls: candidates,
            token: widget.token,
            fallback: Container(
              color: Colors.grey[900],
              child: const Icon(Icons.movie, color: Colors.white24, size: 80),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.25, 0.7, 1],
                colors: [
                  Color(0x99000000),
                  Colors.transparent,
                  Color(0x66000000),
                  Colors.black,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHeading(AppLocalizations l10n) {
    final seriesName = item.seriesName ?? _details?['SeriesName'] as String?;
    final season =
        item.parentIndexNumber ?? _details?['ParentIndexNumber'] as int?;
    final episode = item.indexNumber ?? _details?['IndexNumber'] as int?;
    return [
      if (_isEpisode && item.seriesId != null)
        InkWell(
          onTap: _openSeries,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tv, size: 18, color: _accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    seriesName ?? l10n.goToSeries,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18, color: _accent),
              ],
            ),
          ),
        ),
      if (_isEpisode)
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 4),
          child: Text(
            l10n.seasonEpisodeLabel(season ?? 0, episode ?? 0),
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
        ),
      SelectableText(
        item.name,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
      ),
    ];
  }

  Widget _buildMetaRow(
    BuildContext context,
    AppLocalizations l10n, {
    required bool isCompletelyWatched,
    int? remainingTicks,
  }) {
    final chips = <Widget>[];
    void add(IconData? icon, String text, {Color? color}) {
      if (text.isEmpty) return;
      chips.add(_MetaChip(icon: icon, text: text, color: color));
    }

    final premiere = DateTime.tryParse(
      _details?['PremiereDate'] as String? ?? '',
    );
    if (_isEpisode && premiere != null) {
      add(Icons.event, formatShortDate(context, premiere.toLocal()));
    } else if (_details?['ProductionYear'] != null) {
      add(Icons.event, '${_details!['ProductionYear']}');
    }
    final runTime = _runTimeTicks;
    if (runTime != null && runTime > 0) {
      add(Icons.schedule, formatDuration(l10n, _ticks(runTime)));
      final hasRemaining = remainingTicks != null && remainingTicks > 0;
      final remaining = hasRemaining ? _ticks(remainingTicks) : _ticks(runTime);
      final endsAt = TimeOfDay.fromDateTime(DateTime.now().add(remaining));
      add(
        Icons.flag_outlined,
        l10n.endsAt(
          MaterialLocalizations.of(context).formatTimeOfDay(
            endsAt,
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          ),
        ),
      );
      if (hasRemaining) {
        add(
          Icons.timelapse,
          l10n.timeLeft(formatDuration(l10n, remaining)),
          color: _accent,
        );
      }
    }
    final rating = _details?['CommunityRating'];
    if (rating is num && rating > 0) {
      add(Icons.star_rounded, rating.toStringAsFixed(1), color: Colors.amber);
    }
    final official = _details?['OfficialRating'] as String?;
    if (official != null) add(null, official);

    final video = _streams('Video').firstOrNull;
    if (video != null) {
      final range = (video['VideoRangeType'] ?? video['VideoRange']) as String?;
      add(
        Icons.high_quality_outlined,
        [
          resolutionLabel(video['Width'] as int?, video['Height'] as int?),
          if (range != null && range != 'SDR' && range != 'Unknown') range,
        ].where((e) => e.isNotEmpty).join(' '),
      );
    }
    final audio = _streams('Audio');
    final defaultAudio =
        audio.where((s) => s['IsDefault'] == true).firstOrNull ??
        audio.firstOrNull;
    if (defaultAudio != null) {
      add(
        Icons.surround_sound_outlined,
        [
          channelsLabel(defaultAudio['Channels'] as int?),
          (defaultAudio['Codec'] as String? ?? '').toUpperCase(),
        ].where((e) => e.isNotEmpty).join(' '),
      );
    }
    final subtitles = _streams('Subtitle');
    if (subtitles.isNotEmpty) {
      add(Icons.closed_caption_outlined, l10n.subtitleCount(subtitles.length));
    }
    if (isCompletelyWatched) {
      add(Icons.check_circle, l10n.watched, color: Colors.greenAccent);
    }
    if (_localFilePath != null) {
      add(Icons.download_done, l10n.downloadedBadge, color: Colors.greenAccent);
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _buildActions(
    AppLocalizations l10n, {
    required bool canResume,
    required int resumePositionMs,
  }) {
    return ValueListenableBuilder<Map<String, DownloadStatus>>(
      valueListenable: DownloadService().activeDownloads,
      builder: (context, activeDownloadsMap, _) {
        final activeDownload = activeDownloadsMap[item.id];
        final wide = MediaQuery.sizeOf(context).width >= 700;
        final offline = _localFilePath != null;
        final primary = canResume
            ? _PrimaryButton(
                label: l10n.continueWatching,
                icon: Icons.play_arrow_rounded,
                color: _accent,
                foreground: Colors.white,
                onTap: () =>
                    _playVideo(offline, startPositionMs: resumePositionMs),
              )
            : _PrimaryButton(
                label: offline ? l10n.watchOffline : l10n.watchOnline,
                icon: Icons.play_arrow_rounded,
                color: Colors.white,
                foreground: Colors.black,
                onTap: () => _playVideo(offline),
              );
        final secondary = <Widget>[
          if (canResume)
            _SecondaryButton(
              label: l10n.fromBeginning,
              icon: Icons.replay,
              onTap: () => _playVideo(offline, startPositionMs: 0),
            ),
          if (offline)
            _SecondaryButton(
              label: l10n.watchOnline,
              icon: Icons.cloud_outlined,
              onTap: () => _playVideo(false),
            ),
          _SecondaryButton(
            label: offline ? l10n.downloadAgain : l10n.downloadToMemory,
            icon: offline ? Icons.refresh : Icons.download,
            onTap: activeDownload == null
                ? () => _showDownloadOptions(context, l10n)
                : null,
          ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              // Equal widths, so the row reads as one group of buttons.
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final button in [primary, ...secondary])
                    SizedBox(width: 280, child: button),
                ],
              )
            else
              // On a phone every button spans the full width.
              for (final (index, button) in [primary, ...secondary].indexed)
                Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
                  child: SizedBox(width: double.infinity, child: button),
                ),
            if (activeDownload != null) ...[
              const SizedBox(height: 14),
              _buildProgressBar(activeDownload, l10n),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _buildTagline() {
    final taglines = _details?['Taglines'];
    if (taglines is! List || taglines.isEmpty) return const [];
    return [
      const SizedBox(height: 20),
      Text(
        '${taglines.first}',
        style: const TextStyle(
          color: Colors.white70,
          fontStyle: FontStyle.italic,
          fontSize: 15,
        ),
      ),
    ];
  }

  Widget _buildOverview(AppLocalizations l10n, String description) {
    if (description.isEmpty) {
      return Text(
        _details == null ? '' : l10n.noDescription,
        style: const TextStyle(color: Colors.white38),
      );
    }
    final isLong = description.length > 280;
    final expanded = _overviewExpanded || !isLong;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: Text(
            description,
            maxLines: expanded ? null : 5,
            overflow: expanded ? TextOverflow.visible : TextOverflow.fade,
            style: const TextStyle(color: Colors.white70, height: 1.45),
          ),
        ),
        if (isLong)
          TextButton(
            onPressed: () =>
                setState(() => _overviewExpanded = !_overviewExpanded),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: _accent,
            ),
            child: Text(_overviewExpanded ? l10n.showLess : l10n.showMore),
          ),
      ],
    );
  }

  List<Map<dynamic, dynamic>> get _people =>
      (_details?['People'] as List?)
          ?.whereType<Map<dynamic, dynamic>>()
          .toList() ??
      const [];

  List<Widget> _buildGenresAndCrew(AppLocalizations l10n) {
    final genres =
        (_details?['Genres'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    String names(String type) => _people
        .where((p) => p['Type'] == type)
        .map((p) => p['Name'])
        .whereType<String>()
        .take(4)
        .join(', ');
    final studios =
        (_details?['Studios'] as List?)
            ?.whereType<Map<dynamic, dynamic>>()
            .map((s) => s['Name'])
            .whereType<String>()
            .take(3)
            .join(', ') ??
        '';
    final rows = <MapEntry<String, String>>[
      MapEntry(l10n.directedBy, names('Director')),
      MapEntry(l10n.writtenBy, names('Writer')),
      MapEntry(l10n.studio, studios),
    ].where((e) => e.value.isNotEmpty).toList();
    if (genres.isEmpty && rows.isEmpty) return const [];
    return [
      const SizedBox(height: 20),
      if (genres.isNotEmpty)
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final genre in genres)
              Chip(
                label: Text(genre),
                visualDensity: VisualDensity.compact,
                backgroundColor: Colors.white10,
                side: BorderSide.none,
              ),
          ],
        ),
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${row.key}: ',
                  style: const TextStyle(color: Colors.white38),
                ),
                TextSpan(text: row.value),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildCast(AppLocalizations l10n) {
    final people = _people
        .where((p) => p['Type'] == 'Actor' || p['Type'] == 'GuestStar')
        .take(30)
        .toList();
    if (people.isEmpty) return const [];
    return [
      _SectionTitle(l10n.cast),
      SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: people.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final person = people[index];
            final hasImage = person['PrimaryImageTag'] != null;
            final role = person['Role'] as String? ?? '';
            return SizedBox(
              width: 84,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.white10,
                    foregroundImage: hasImage
                        ? CachedNetworkImageProvider(
                            '${widget.baseUrl}/Items/${person['Id']}/Images/Primary?fillWidth=160&quality=80',
                            headers: jellyfinAuthHeaders(widget.token),
                          )
                        : null,
                    child: const Icon(Icons.person, color: Colors.white30),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${person['Name'] ?? ''}',
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (role.isNotEmpty)
                    Text(
                      role,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _buildChapters(AppLocalizations l10n) {
    final chapters =
        (_details?['Chapters'] as List?)
            ?.whereType<Map<dynamic, dynamic>>()
            .toList() ??
        const [];
    if (chapters.length < 2) return const [];
    return [
      _SectionTitle(l10n.chapters),
      SizedBox(
        height: 140,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: chapters.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final chapter = chapters[index];
            final start = chapter['StartPositionTicks'] as int? ?? 0;
            final position = _ticks(start);
            String two(int n) => n.toString().padLeft(2, '0');
            final time = position.inHours > 0
                ? '${position.inHours}:${two(position.inMinutes.remainder(60))}:${two(position.inSeconds.remainder(60))}'
                : '${two(position.inMinutes)}:${two(position.inSeconds.remainder(60))}';
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _playVideo(
                _localFilePath != null,
                startPositionMs: start ~/ 10000,
              ),
              child: SizedBox(
                width: 170,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: chapter['ImageTag'] != null
                            ? CachedNetworkImage(
                                imageUrl:
                                    '${widget.baseUrl}/Items/${item.id}/Images/Chapter/$index?fillWidth=340&quality=80',
                                httpHeaders: jellyfinAuthHeaders(widget.token),
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) =>
                                    Container(color: Colors.white10),
                              )
                            : Container(
                                color: Colors.white10,
                                child: const Icon(
                                  Icons.bookmark_outline,
                                  color: Colors.white24,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      chapter['Name'] as String? ??
                          l10n.chapterNumber(index + 1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _buildAdjacent(AppLocalizations l10n) {
    final index = _adjacent.indexWhere((e) => e.id == item.id);
    if (index < 0) return const [];
    final previous = index > 0 ? _adjacent[index - 1] : null;
    final next = index + 1 < _adjacent.length ? _adjacent[index + 1] : null;
    if (previous == null && next == null) return const [];

    Widget card(Episode episode, String label, IconData icon) => InkWell(
      onTap: () => _openEpisode(episode),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 96,
                height: 54,
                child: CachedNetworkImage(
                  imageUrl:
                      '${widget.baseUrl}/Items/${episode.id}/Images/Primary?fillWidth=200&quality=80',
                  httpHeaders: jellyfinAuthHeaders(widget.token),
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    color: Colors.white10,
                    child: Icon(icon, color: Colors.white24),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                  Text(
                    l10n.seasonEpisodeShort(
                      episode.parentIndexNumber ?? 0,
                      episode.indexNumber ?? 0,
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  Text(
                    episode.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (episode.userData?.played == true)
              const Icon(
                Icons.check_circle,
                size: 16,
                color: Colors.greenAccent,
              ),
          ],
        ),
      ),
    );

    final cards = [
      if (previous != null)
        card(previous, l10n.previousEpisode, Icons.skip_previous),
      if (next != null) card(next, l10n.nextEpisode, Icons.skip_next),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return [
      _SectionTitle(l10n.moreEpisodes),
      if (wide)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: cards[i]),
            ],
          ],
        )
      else
        Column(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              cards[i],
            ],
          ],
        ),
    ];
  }

  Widget _buildTechnicalDetails(AppLocalizations l10n) {
    final source = _mediaSource;
    final video = _streams('Video');
    final audio = _streams('Audio');
    final subtitles = _streams('Subtitle');
    if (source == null && video.isEmpty) return const SizedBox.shrink();
    final size = source?['Size'];
    final bitrate = source?['Bitrate'];
    final rows = <MapEntry<String, String>>[
      if (source?['Container'] != null)
        MapEntry(l10n.mediaContainer, '${source!['Container']}'.toUpperCase()),
      if (size is int) MapEntry(l10n.mediaFileSize, _fileSize(size)),
      if (bitrate is int)
        MapEntry(
          l10n.mediaBitrate,
          '${(bitrate / 1000000).toStringAsFixed(1)} Mb/s',
        ),
      for (final v in video)
        MapEntry(
          l10n.mediaVideo,
          [
            (v['Codec'] as String? ?? '').toUpperCase(),
            if (v['Width'] != null) '${v['Width']}×${v['Height']}',
            if (v['RealFrameRate'] is num)
              '${(v['RealFrameRate'] as num).toStringAsFixed(2)} fps',
            ?v['VideoRangeType'] as String?,
          ].where((e) => e.isNotEmpty).join(' · '),
        ),
      for (final a in audio) MapEntry(l10n.mediaAudio, _streamLabel(a)),
      for (final s in subtitles) MapEntry(l10n.subtitles, _streamLabel(s)),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline, color: Colors.white54),
          title: Text(
            l10n.technicalDetails,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        row.key,
                        style: const TextStyle(color: Colors.white38),
                      ),
                    ),
                    Expanded(child: SelectableText(row.value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- download

  void _showDownloadOptions(BuildContext context, AppLocalizations l10n) {
    showQualityPicker(
      context,
      title: l10n.selectQuality,
      mediaInfo: _mediaInfo,
      onSelect: _startDownloadOffline,
    );
  }

  Widget _buildProgressBar(DownloadStatus status, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "${l10n.downloading}: ${status.progressText}",
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!status.isDownloaded)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                tooltip: l10n.cancelDownload,
                onPressed: () => DownloadService().cancelDownload(item.id),
              ),
          ],
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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 12),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );
}

class _MetaChip extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Color? color;

  const _MetaChip({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Colors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(text, style: TextStyle(color: foreground, fontSize: 13)),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color foreground;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 26),
    label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    style: FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: foreground,
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white70,
      side: const BorderSide(color: Colors.white24),
      minimumSize: const Size(double.infinity, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Tries each URL in turn (Jellyfin answers 404 for a missing image type).
class _FallbackImage extends StatefulWidget {
  final List<String> urls;
  final String token;
  final Widget fallback;

  const _FallbackImage({
    required this.urls,
    required this.token,
    required this.fallback,
  });

  @override
  State<_FallbackImage> createState() => _FallbackImageState();
}

class _FallbackImageState extends State<_FallbackImage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.urls.length) return widget.fallback;
    return CachedNetworkImage(
      key: ValueKey(widget.urls[_index]),
      imageUrl: widget.urls[_index],
      httpHeaders: jellyfinAuthHeaders(widget.token),
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: Colors.black),
      errorWidget: (_, _, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _index++);
        });
        return Container(color: Colors.black);
      },
    );
  }
}
