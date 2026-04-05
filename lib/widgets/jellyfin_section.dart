import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/details_screen.dart';
import '../screens/series_details_screen.dart';
import '../screens/category_items_screen.dart';
import '../models/jellyfin_item.dart';
import 'desktop_horizontal_list_view.dart';

class JellyfinSection extends StatelessWidget {
  final String title;
  final List<JellyfinItem> items;
  final String baseUrl;
  final String token;
  final String userId;
  final VoidCallback? onRefresh;
  final double aspectRatio;
  final bool showShowAllButton;
  final bool useSeriesImages;

  const JellyfinSection({
    super.key,
    required this.title,
    required this.items,
    required this.baseUrl,
    required this.token,
    required this.userId,
    this.onRefresh,
    this.aspectRatio = 2 / 3,
    this.showShowAllButton = true,
    this.useSeriesImages = false,
  });

  double _getCardWidth(double width) {
    if (aspectRatio > 1.2) {
      if (width >= 1400) return 280;
      if (width >= 1000) return 240;
      return 190;
    } else {
      if (width >= 1000) return 170;
      return 140;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = _getCardWidth(screenWidth);
    
    final sectionHeight = (cardWidth / aspectRatio) + 45;
    final sectionPadding = screenWidth >= 1000 ? 24.0 : 16.0;

    final cleanUrl = baseUrl.endsWith('/') 
        ? baseUrl.substring(0, baseUrl.length - 1) 
        : baseUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: sectionPadding,
            right: sectionPadding - 4,
            top: 20,
            bottom: 10,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (showShowAllButton)
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 18),
                  color: Colors.white70,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryItemsScreen(
                          items: items,
                          title: title,
                          baseUrl: cleanUrl,
                          token: token,
                          userId: userId,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),

        DesktopHorizontalListView(
          height: sectionHeight,
          thumbVisibility: screenWidth >= 1000,
          padding: EdgeInsets.symmetric(horizontal: sectionPadding - 6),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            
            String imageTag = "Primary";
            String itemId = item.id;
            if (useSeriesImages) {
              itemId = item.seriesId ?? item.id;
              if (aspectRatio > 1.2) {
                imageTag = "Backdrop";
              }
            }

            final imageUrl = "$cleanUrl/Items/$itemId/Images/$imageTag?quality=90";

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () async {
                  Widget nextScreen;
                  if (item.type == "Series") {
                    nextScreen = SeriesDetailsScreen(
                      series: item, baseUrl: cleanUrl, token: token, userId: userId
                    );
                  } else {
                    nextScreen = DetailsScreen(
                      item: item, baseUrl: cleanUrl, token: token, userId: userId
                    );
                  }

                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => nextScreen),
                  );

                  if (onRefresh != null) onRefresh!();
                },
                child: Container(
                  width: cardWidth,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: imageUrl,
                                httpHeaders: {"X-Emby-Token": token},
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.grey[900]),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.play_circle_outline, color: Colors.white30, size: 40),
                                ),
                              ),
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Color(0x44000000),
                                      Color(0xAA000000),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.name,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: screenWidth >= 1000 ? 13 : 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}