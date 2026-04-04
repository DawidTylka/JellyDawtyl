import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application_1/screens/details_screen.dart';
import '../models/movie.dart';
import '../models/jellyfin_item.dart';
import '../widgets/desktop_horizontal_list_view.dart';
import 'category_items_screen.dart';
import 'series_details_screen.dart';
import '../widgets/ad_banner_widget.dart';
import '../l10n/app_localizations.dart';

class HomeScreen extends StatelessWidget {
  final List<Movie> resumeMovies;
  final List<Movie> latestMovies;
  final List<Movie> allMovies;
  final String baseUrl;
  final String token;
  final String userId;

  const HomeScreen({
    super.key,
    required this.resumeMovies,
    required this.latestMovies,
    required this.allMovies,
    required this.baseUrl,
    required this.token,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = baseUrl.startsWith('http') ? baseUrl : 'https://$baseUrl';
    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final contentMaxWidth = screenWidth >= 1500 ? 1400.0 : double.infinity;

        return Scaffold(
          appBar: AppBar(title: const Text("Jellyfin")),
          body: Scrollbar(
            thumbVisibility: screenWidth >= 1000,
            child: ListView(
              primary: true,
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (resumeMovies.isNotEmpty)
                          _buildCategoryRow(
                            context,
                            l10n.continueWatching,
                            resumeMovies,
                            cleanUrl,
                            true,
                            screenWidth,
                            l10n,
                          ),
                        _buildCategoryRow(
                          context,
                          "Ostatnio dodane",
                          latestMovies,
                          cleanUrl,
                          false,
                          screenWidth,
                          l10n,
                        ),
                        _buildCategoryRow(
                          context,
                          l10n.libraryTitle,
                          allMovies,
                          cleanUrl,
                          false,
                          screenWidth,
                          l10n,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: const AdBannerWidget(),
        );
      },
    );
  }

  Widget _buildCategoryRow(
    BuildContext context,
    String title,
    List<JellyfinItem> items,
    String cleanUrl,
    bool isResumeSection,
    double screenWidth,
    AppLocalizations l10n,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();

    final sectionPadding = screenWidth >= 1000 ? 24.0 : 15.0;
    final rowHeight = isResumeSection
        ? (screenWidth >= 1000 ? 220.0 : 160.0)
        : (screenWidth >= 1000 ? 250.0 : 220.0);
    final itemWidth = isResumeSection
        ? (screenWidth >= 1000 ? 240.0 : 190.0)
        : (screenWidth >= 1000 ? 170.0 : 140.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: sectionPadding,
            top: 20,
            bottom: 10,
            right: sectionPadding - 4,
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
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 18),
                color: Colors.white70,
                tooltip: 'Pokaż wszystko',
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
          height: rowHeight,
          thumbVisibility: screenWidth >= 1000,
          padding: EdgeInsets.symmetric(horizontal: sectionPadding - 5),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final movie = items[index];
            final imageUrl =
                "$cleanUrl/Items/${movie.id}/Images/Primary?quality=80&fillWidth=400";

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  if (movie.type == "Episode" || movie.type == "Movie") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailsScreen(
                          item: movie,
                          baseUrl: cleanUrl,
                          token: token,
                          userId: userId,
                        ),
                      ),
                    );
                  } else if (movie.type == "Series") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SeriesDetailsScreen(
                          series: movie,
                          baseUrl: cleanUrl,
                          token: token,
                          userId: userId,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  width: itemWidth,
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
                                placeholder: (context, url) =>
                                    Container(color: Colors.grey[900]),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.play_circle_outline,
                                    color: Colors.white30,
                                    size: 40,
                                  ),
                                ),
                              ),
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Color(0x88000000),
                                      Color(0xCC000000),
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
                        movie.name,
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
