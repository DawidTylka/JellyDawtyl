import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/jellyfin_item.dart';
import '../utils/jellyfin_auth.dart';

/// One image to try for an item, and whether it is a portrait poster.
class ArtworkCandidate {
  final String url;
  final bool portrait;

  const ArtworkCandidate(this.url, {required this.portrait});

  @override
  bool operator ==(Object other) =>
      other is ArtworkCandidate &&
      other.url == url &&
      other.portrait == portrait;

  @override
  int get hashCode => Object.hash(url, portrait);

  @override
  String toString() => '$url${portrait ? ' (portrait)' : ''}';
}

/// Images to try for [item] in a card of the given shape, best first.
///
/// Landscape (16:9) cards try landscape art first: `Thumb`, then `Backdrop`.
/// Portrait cards use the `Primary` poster. An episode is represented by its
/// season, then its series, and only as a last resort by its own still: a
/// frame from one episode says little about which show it belongs to.
List<ArtworkCandidate> itemArtworkCandidates(
  JellyfinItem item,
  String baseUrl, {
  bool landscape = false,
  String query = 'quality=90',
}) {
  ArtworkCandidate image(String id, String type) => ArtworkCandidate(
    '$baseUrl/Items/$id/Images/$type?$query',
    portrait: type == 'Primary',
  );

  if (item.type == 'Episode') {
    final parents = [?item.seasonId, ?item.seriesId];
    return [
      if (landscape) ...[
        for (final id in parents) image(id, 'Thumb'),
        if (item.seriesId != null) image(item.seriesId!, 'Backdrop'),
      ],
      for (final id in parents) image(id, 'Primary'),
      ArtworkCandidate(
        '$baseUrl/Items/${item.id}/Images/Primary?$query',
        portrait: false,
      ),
    ];
  }

  return [
    if (landscape) ...[image(item.id, 'Thumb'), image(item.id, 'Backdrop')],
    image(item.id, 'Primary'),
  ];
}

/// Artwork for [item] that fills its box, matched to the box's shape.
///
/// Candidates that fail to load (Jellyfin answers 404 when an item has no
/// image of that type) are skipped. A portrait poster that ends up in a
/// landscape box is drawn whole over a blurred copy of itself instead of
/// being cropped to a strip.
class ItemArtwork extends StatelessWidget {
  final JellyfinItem item;
  final String baseUrl;
  final String token;
  final bool landscape;
  final String query;
  final Widget Function(BuildContext context) placeholder;
  final Widget Function(BuildContext context) error;

  const ItemArtwork({
    super.key,
    required this.item,
    required this.baseUrl,
    required this.token,
    required this.placeholder,
    required this.error,
    this.landscape = false,
    this.query = 'quality=90',
  });

  @override
  Widget build(BuildContext context) {
    final candidates = itemArtworkCandidates(
      item,
      baseUrl,
      landscape: landscape,
      query: query,
    );
    return _build(context, candidates, 0);
  }

  Widget _build(
    BuildContext context,
    List<ArtworkCandidate> candidates,
    int index,
  ) {
    if (index >= candidates.length) return error(context);
    final candidate = candidates[index];
    return CachedNetworkImage(
      imageUrl: candidate.url,
      httpHeaders: jellyfinAuthHeaders(token),
      placeholder: (context, _) => placeholder(context),
      errorWidget: (context, _, _) => _build(context, candidates, index + 1),
      imageBuilder: (context, provider) {
        if (!(landscape && candidate.portrait)) {
          return Image(image: provider, fit: BoxFit.cover);
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Image(image: provider, fit: BoxFit.cover),
            ),
            Container(color: const Color(0x55000000)),
            Image(image: provider, fit: BoxFit.contain),
          ],
        );
      },
    );
  }
}
