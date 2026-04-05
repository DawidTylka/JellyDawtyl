import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../widgets/ad_banner_widget.dart';
import '../l10n/app_localizations.dart';
import '../widgets/jellyfin_section.dart';

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
