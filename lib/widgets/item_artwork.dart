import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/jellyfin_item.dart';
import '../utils/jellyfin_auth.dart';

/// Image URLs to try for [item], best first.
///
/// An episode is represented by its season poster, then the series poster,
/// and only as a last resort by its own still: a frame from one episode
/// says little about which show it belongs to. Other items use [imageType]
/// of the item itself (or of its series when [preferSeries] is set).
List<String> itemArtworkUrls(
  JellyfinItem item,
  String baseUrl, {
  String imageType = 'Primary',
  bool preferSeries = false,
  String query = 'quality=90',
}) {
  String url(String id, String type) =>
      '$baseUrl/Items/$id/Images/$type?$query';

  if (item.type == 'Episode') {
    return [
      if (item.seasonId != null) url(item.seasonId!, 'Primary'),
      if (item.seriesId != null) url(item.seriesId!, 'Primary'),
      url(item.id, 'Primary'),
    ];
  }
  return [
    if (preferSeries && item.seriesId != null) url(item.seriesId!, imageType),
    url(item.id, imageType),
  ];
}

/// Shows the first of [urls] that loads; on 404 moves on to the next one.
class FallbackNetworkImage extends StatelessWidget {
  final List<String> urls;
  final String token;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext context) placeholder;
  final Widget Function(BuildContext context) error;

  const FallbackNetworkImage({
    super.key,
    required this.urls,
    required this.token,
    required this.placeholder,
    required this.error,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) => _build(context, 0);

  Widget _build(BuildContext context, int index) {
    if (index >= urls.length) return error(context);
    return CachedNetworkImage(
      imageUrl: urls[index],
      httpHeaders: jellyfinAuthHeaders(token),
      fit: fit,
      width: width,
      height: height,
      placeholder: (context, _) => placeholder(context),
      errorWidget: (context, _, _) => _build(context, index + 1),
    );
  }
}

/// Artwork for [item] that fills its box. When an episode's portrait poster
/// is shown in a landscape box, it is drawn whole over a blurred copy of
/// itself instead of being cropped to a strip.
class ItemArtwork extends StatelessWidget {
  final JellyfinItem item;
  final String baseUrl;
  final String token;
  final String imageType;
  final bool preferSeries;
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
    this.imageType = 'Primary',
    this.preferSeries = false,
    this.landscape = false,
    this.query = 'quality=90',
  });

  @override
  Widget build(BuildContext context) {
    final urls = itemArtworkUrls(
      item,
      baseUrl,
      imageType: imageType,
      preferSeries: preferSeries,
      query: query,
    );

    if (!landscape || item.type != 'Episode') {
      return FallbackNetworkImage(
        urls: urls,
        token: token,
        placeholder: placeholder,
        error: error,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: FallbackNetworkImage(
            urls: urls,
            token: token,
            placeholder: placeholder,
            error: error,
          ),
        ),
        Container(color: const Color(0x55000000)),
        FallbackNetworkImage(
          urls: urls,
          token: token,
          fit: BoxFit.contain,
          placeholder: (_) => const SizedBox.shrink(),
          error: (_) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
