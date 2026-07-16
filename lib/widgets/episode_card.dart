import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/episode.dart';

class EpisodeCard extends StatelessWidget {
  final Episode episode;
  final String baseUrl;
  final String token;
  final VoidCallback onDownload;

  const EpisodeCard({
    super.key,
    required this.episode,
    required this.baseUrl,
    required this.token,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        "$baseUrl/Items/${episode.id}/Images/Primary?fillWidth=300&quality=80";

    // Obliczanie postępu
    final num? positionTicks = episode.userData?.playbackPositionTicks;
    final num? runTimeTicks = episode.runTimeTicks;
    final bool isPlayed = episode.userData?.played ?? false;

    double progress = 0.0;
    if (positionTicks != null && runTimeTicks != null && runTimeTicks > 0) {
      progress = (positionTicks / runTimeTicks).clamp(0.0, 1.0);
    }

    final bool isWatched = isPlayed || progress >= 0.95;
    final bool isInProgress = progress > 0.0 && !isWatched;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Miniatura (Lewa strona)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      httpHeaders: {"X-Emby-Token": token},
                      width: 140,
                      height: 90,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: Colors.black26,
                        child: const Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    // --- PASEK POSTĘPU (jeśli w trakcie) ---
                    if (isInProgress)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white24,
                          color: Colors.deepPurpleAccent,
                          minHeight: 3.0,
                        ),
                      ),

                    // --- ZNACZEK "OBEJRZANE" ---
                    if (isWatched)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.deepPurpleAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),

                    // --- ZNACZEK "W TRAKCIE" (procent) ---
                    if (isInProgress)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${(progress * 100).toInt()}%",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Informacje (Prawa strona)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Odcinek ${episode.indexNumber}",
                        style: const TextStyle(
                          color: Colors.deepPurpleAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        episode.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              // Przycisk Pobierania
              IconButton(
                icon: const Icon(
                  Icons.download_for_offline,
                  color: Colors.white70,
                ),
                onPressed: onDownload,
              ),
            ],
          ),
          // Krótki opis pod spodem (opcjonalnie)
          if (episode.overview != null)
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text(
                episode.overview!,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
