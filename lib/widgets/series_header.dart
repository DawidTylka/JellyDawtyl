import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/episode.dart';
import '../utils/html_description.dart';
import '../utils/jellyfin_auth.dart';
import 'unwanted_actions.dart';

/// Top of the series screen: backdrop, facts, overview, the episode to
/// watch next and the plugin lists.
class SeriesHeader extends StatefulWidget {
  final String seriesId;
  final Map<String, dynamic>? details;
  final String baseUrl;
  final String token;
  final Episode? nextEpisode;
  final VoidCallback? onPlayNext;
  final VoidCallback? onUnwantedChanged;

  const SeriesHeader({
    super.key,
    required this.seriesId,
    required this.details,
    required this.baseUrl,
    required this.token,
    this.nextEpisode,
    this.onPlayNext,
    this.onUnwantedChanged,
  });

  @override
  State<SeriesHeader> createState() => _SeriesHeaderState();
}

class _SeriesHeaderState extends State<SeriesHeader> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final details = widget.details;
    final width = MediaQuery.sizeOf(context).width;
    final overview = cleanHtmlDescription(details?['Overview'] as String?);
    final genres =
        (details?['Genres'] as List?)
            ?.whereType<String>()
            .take(4)
            .join(' · ') ??
        '';
    final year = details?['ProductionYear'];
    final endYear = DateTime.tryParse(
      details?['EndDate'] as String? ?? '',
    )?.year;
    final continuing = details?['Status'] == 'Continuing';
    final years = year == null
        ? ''
        : continuing
        ? '$year–'
        : (endYear != null && endYear != year ? '$year–$endYear' : '$year');
    final rating = details?['CommunityRating'];
    final facts = [
      if (years.isNotEmpty) years,
      if (rating is num && rating > 0) '★ ${rating.toStringAsFixed(1)}',
      ?details?['OfficialRating'] as String?,
      if (genres.isNotEmpty) genres,
    ];
    final next = widget.nextEpisode;
    final nextInProgress = (next?.userData?.playbackPositionTicks ?? 0) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: (width * 9 / 16).clamp(160.0, 340.0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl:
                    '${widget.baseUrl}/Items/${widget.seriesId}/Images/Backdrop?fillWidth=1280&quality=85',
                httpHeaders: jellyfinAuthHeaders(widget.token),
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => CachedNetworkImage(
                  imageUrl:
                      '${widget.baseUrl}/Items/${widget.seriesId}/Images/Primary?fillWidth=800&quality=85',
                  httpHeaders: jellyfinAuthHeaders(widget.token),
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(color: Colors.grey[900]),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.5, 1],
                    colors: [Colors.transparent, Colors.black],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (facts.isNotEmpty)
                Text(
                  facts.join('  ·  '),
                  style: const TextStyle(color: Colors.white60),
                ),
              if (next != null && widget.onPlayNext != null) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: width >= 700 ? 420 : double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.onPlayNext,
                    icon: const Icon(Icons.play_arrow_rounded, size: 26),
                    label: Text(
                      '${nextInProgress ? l10n.continueWatching : l10n.playNext}: '
                      '${l10n.seasonEpisodeShort(next.parentIndexNumber ?? 0, next.indexNumber ?? 0)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    next.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              UnwantedActions(
                baseUrl: widget.baseUrl,
                token: widget.token,
                itemId: widget.seriesId,
                onChanged: (_) => widget.onUnwantedChanged?.call(),
              ),
              if (overview.isNotEmpty) ...[
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: Text(
                      overview,
                      maxLines: _expanded ? null : 3,
                      overflow: _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                if (overview.length > 160)
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: Colors.deepPurpleAccent,
                    ),
                    child: Text(_expanded ? l10n.showLess : l10n.showMore),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
