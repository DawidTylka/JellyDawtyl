import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/app_localizations.dart';
import '../models/jellyfin_item.dart';
import 'series_details_screen.dart';
import 'details_screen.dart';
import '../widgets/ad_banner_widget.dart';

class CategoryItemsScreen extends StatefulWidget {
  final List<JellyfinItem> items;
  final String title;
  final String baseUrl;
  final String token;
  final String userId;

  const CategoryItemsScreen({
    super.key,
    required this.items,
    required this.title,
    required this.baseUrl,
    required this.token,
    required this.userId,
  });

  @override
  State<CategoryItemsScreen> createState() => _CategoryItemsScreenState();
}

class _CategoryItemsScreenState extends State<CategoryItemsScreen> {
  late List<JellyfinItem> _filteredItems;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  void _filterItems(String query) {
    setState(() {
      _filteredItems = widget.items
          .where((m) => m.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  double _getProgress(JellyfinItem item) {
    final num? positionTicks = item.userData?.playbackPositionTicks;
    final num? runTimeTicks = item.runTimeTicks;
    if (positionTicks != null && runTimeTicks != null && runTimeTicks > 0) {
      return (positionTicks / runTimeTicks).clamp(0.0, 1.0).toDouble();
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _filterItems,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search, color: Colors.white30),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(15),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _filteredItems.length,
        itemBuilder: (context, index) {
          final movie = _filteredItems[index];

          return GestureDetector(
            onTap: () {
              if (movie.type == "Series") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SeriesDetailsScreen(
                      series: movie,
                      baseUrl: widget.baseUrl,
                      token: widget.token,
                      userId: widget.userId,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailsScreen(
                      item: movie,
                      baseUrl: widget.baseUrl,
                      token: widget.token,
                      userId: widget.userId,
                    ),
                  ),
                );
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl:
                        "${widget.baseUrl}/Items/${movie.id}/Images/Primary?quality=50&fillWidth=200",
                    httpHeaders: {"X-Emby-Token": widget.token},
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.movie,
                        color: Colors.white30,
                        size: 40,
                      ),
                    ),
                  ),

                  // Badge serialu (liczba nieobejrzanych)
                  if (movie.type == "Series" &&
                      movie.userData?.unplayedItemCount != null &&
                      movie.userData!.unplayedItemCount! > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurpleAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.visibility_off,
                              color: Colors.white,
                              size: 11,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              "${movie.userData!.unplayedItemCount}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Badge obejrzane (dla filmów / odcinków)
                  if (movie.type != "Series" &&
                      (movie.userData?.played == true ||
                          _getProgress(movie) >= 0.95))
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.deepPurpleAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),

                  // Pasek postępu (dla filmów / odcinków w trakcie)
                  if (movie.type != "Series")
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _ProgressBar(item: movie),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: const AdBannerWidget(),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final JellyfinItem item;
  const _ProgressBar({required this.item});

  @override
  Widget build(BuildContext context) {
    final num? positionTicks = item.userData?.playbackPositionTicks;
    final num? runTimeTicks = item.runTimeTicks;
    if (positionTicks == null || runTimeTicks == null || runTimeTicks <= 0) {
      return const SizedBox.shrink();
    }
    final progress = (positionTicks / runTimeTicks).clamp(0.0, 1.0);
    if (progress <= 0.0 || progress >= 0.95) {
      return const SizedBox.shrink();
    }
    return LinearProgressIndicator(
      value: progress.toDouble(),
      backgroundColor: Colors.white24,
      color: Colors.deepPurpleAccent,
      minHeight: 3.0,
    );
  }
}
