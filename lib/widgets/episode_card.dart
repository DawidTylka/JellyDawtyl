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
                child: CachedNetworkImage(
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
