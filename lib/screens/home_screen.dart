import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../widgets/ad_banner_widget.dart';
import '../l10n/app_localizations.dart';
import '../widgets/jellyfin_section.dart';
import '../services/jellyfin_api.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  final List<Movie> resumeMovies;
  final List<Movie> latestMovies;
  final List<Movie> allMovies;
  final String baseUrl;
  final String token;
  final String userId;
  final String? libraryId;
  final String? libraryName;

  const HomeScreen({
    super.key,
    required this.resumeMovies,
    required this.latestMovies,
    required this.allMovies,
    required this.baseUrl,
    required this.token,
    required this.userId,
    this.libraryId,
    this.libraryName,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = baseUrl;
    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final contentMaxWidth = screenWidth >= 1500 ? 1400.0 : double.infinity;

        return Scaffold(
          appBar: AppBar(
            title: Text(libraryName ?? "JellyDawtyl"),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: l10n.search,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SearchScreen(
                      baseUrl: cleanUrl,
                      token: token,
                      userId: userId,
                      libraryId: libraryId,
                      libraryName: libraryName,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
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
                          JellyfinSection(
                            title: l10n.continueWatching,
                            items: resumeMovies,
                            baseUrl: cleanUrl,
                            token: token,
                            userId: userId,
                            aspectRatio: 16 / 9,
                            showShowAllButton: false,
                          ),
                        JellyfinSection(
                          title: l10n.lasttlyAdded,
                          items: latestMovies,
                          baseUrl: cleanUrl,
                          token: token,
                          userId: userId,
                        ),
                        JellyfinSection(
                          title: l10n.libraryTitle,
                          items: allMovies,
                          baseUrl: cleanUrl,
                          token: token,
                          userId: userId,
                          pageLoader: libraryId == null
                              ? null
                              : (startIndex, searchTerm) =>
                                    JellyfinApi().fetchAllInLibrary(
                                      cleanUrl,
                                      token,
                                      userId,
                                      libraryId!,
                                      startIndex: startIndex,
                                      searchTerm: searchTerm,
                                    ),
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
}
