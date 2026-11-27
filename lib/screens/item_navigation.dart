import 'package:flutter/material.dart';

import '../models/jellyfin_item.dart';
import 'details_screen.dart';
import 'series_details_screen.dart';

/// Opens the right screen for [item]: series get the season list, movies and
/// episodes the details screen. Completes when the user comes back.
Future<void> openItemDetails(
  BuildContext context,
  JellyfinItem item, {
  required String baseUrl,
  required String token,
  required String userId,
  bool replace = false,
}) {
  final route = MaterialPageRoute<void>(
    builder: (_) => item.type == 'Series'
        ? SeriesDetailsScreen(
            series: item,
            baseUrl: baseUrl,
            token: token,
            userId: userId,
          )
        : DetailsScreen(
            item: item,
            baseUrl: baseUrl,
            token: token,
            userId: userId,
          ),
  );
  return replace
      ? Navigator.pushReplacement(context, route)
      : Navigator.push(context, route);
}

/// Online playback address used by the details screens.
String onlineStreamUrl(String baseUrl, String itemId) =>
    '$baseUrl/Videos/$itemId/stream.mp4?Static=false&VideoCodec=h265&AudioCodec=aac';
