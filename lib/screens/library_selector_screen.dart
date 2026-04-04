import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/app_localizations.dart';
import '../models/jellyfin_item.dart';
import '../models/library.dart';
import '../services/jellyfin_api.dart';
import '../widgets/desktop_horizontal_list_view.dart';
import 'details_screen.dart';
import 'home_screen.dart';
import 'downloads_screen.dart';
import 'series_details_screen.dart';
import 'settings_screen.dart';
import '../widgets/ad_banner_widget.dart';

class LibrarySelectorScreen extends StatefulWidget {
  final List<Library> libraries;
  final String baseUrl;
  final String token;
  final String userId;

  const LibrarySelectorScreen({
    super.key,
    required this.libraries,
    required this.baseUrl,
    required this.token,
    required this.userId,
  });

  @override
  State<LibrarySelectorScreen> createState() => _LibrarySelectorScreenState();
}

class _LibrarySelectorScreenState extends State<LibrarySelectorScreen> {
  List<JellyfinItem> _resumeItems = [];
  bool _isLoadingResume = true;

  @override
  void initState() {
    super.initState();
    _loadResumeItems();
  }

  Future<void> _loadResumeItems() async {
    final api = JellyfinApi();
    try {
      final resume = await api.fetchResumeItems(
        widget.baseUrl,
        widget.token,
        widget.userId,
      );
      if (mounted) {
        setState(() {
          _resumeItems = resume;
          _isLoadingResume = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingResume = false);
    }
  }

  void _openLibrary(BuildContext context, Library lib) async {
    final api = JellyfinApi();
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final resume = await api.fetchResumeItems(
        widget.baseUrl,
        widget.token,
        widget.userId,
      );
      final latest = await api.fetchLatestItems(
        widget.baseUrl,
        widget.token,
        widget.userId,
        lib.id,
      );
      final all = await api.fetchAllInLibrary(
        widget.baseUrl,
        widget.token,
        widget.userId,
        lib.id,
      );

      if (!context.mounted) return;
      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            resumeMovies: resume,
            latestMovies: latest,
            allMovies: all,
            baseUrl: widget.baseUrl,
            token: widget.token,
            userId: widget.userId,
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("${l10n.noDescription}: $e")));
    }
  }

  int _getGridColumnCount(double width) {
    if (width >= 1400) return 5;
    if (width >= 1100) return 4;
    if (width >= 800) return 3;
    return 2;
  }

  double _getResumeCardWidth(double width) {
    if (width >= 1400) return 280;
    if (width >= 1000) return 240;
    return 190;
  }

  Widget _buildResumeSection(double screenWidth, AppLocalizations l10n) {
    final cleanUrl = widget.baseUrl.startsWith('http')
        ? widget.baseUrl
        : 'https://${widget.baseUrl}';
    final cardWidth = _getResumeCardWidth(screenWidth);
    final sectionPadding = screenWidth >= 1000 ? 24.0 : 15.0;
    final sectionHeight = screenWidth >= 1000 ? 220.0 : 160.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: sectionPadding,
            top: 20,
            bottom: 10,
            right: sectionPadding,
          ),
          child: Text(
            l10n.continueWatching,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        DesktopHorizontalListView(
          height: sectionHeight,
          thumbVisibility: screenWidth >= 1000,
          padding: EdgeInsets.symmetric(horizontal: sectionPadding - 5),
          itemCount: _resumeItems.length,
          itemBuilder: (context, index) {
            final movie = _resumeItems[index];
            final imageUrl =
                "$cleanUrl/Items/${movie.id}/Images/Primary?quality=80&fillWidth=400";

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  if (movie.type == "Series") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SeriesDetailsScreen(
                          series: movie,
                          baseUrl: cleanUrl,
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
                          baseUrl: cleanUrl,
                          token: widget.token,
                          userId: widget.userId,
                        ),
                      ),
                    );
                  }
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
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            httpHeaders: {"X-Emby-Token": widget.token},
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.libraryTitle),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.download_done_rounded,
              color: Colors.greenAccent,
            ),
            tooltip: l10n.offlineFiles,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DownloadsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white70),
            tooltip: l10n.settings,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final horizontalPadding = screenWidth >= 1000 ? 24.0 : 15.0;
          final gridColumns = _getGridColumnCount(screenWidth);
          final gridAspectRatio = screenWidth >= 1000 ? 1.75 : 1.5;
          final contentMaxWidth = screenWidth >= 1500
              ? 1400.0
              : double.infinity;

          return Scrollbar(
            thumbVisibility: screenWidth >= 1000,
            child: SingleChildScrollView(
              primary: true,
              padding: const EdgeInsets.only(bottom: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isLoadingResume)
                        const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_resumeItems.isNotEmpty)
                        _buildResumeSection(screenWidth, l10n),

                      Padding(
                        padding: EdgeInsets.only(
                          left: horizontalPadding,
                          top: 20,
                          bottom: 8,
                        ),
                        child: Text(
                          l10n.categories,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridColumns,
                          mainAxisSpacing: 15,
                          crossAxisSpacing: 15,
                          childAspectRatio: gridAspectRatio,
                        ),
                        itemCount: widget.libraries.length,
                        itemBuilder: (context, index) {
                          final lib = widget.libraries[index];
                          final baseUrl = widget.baseUrl.startsWith('http')
                              ? widget.baseUrl
                              : 'https://${widget.baseUrl}';
                          final imageUrl =
                              "$baseUrl/Items/${lib.id}/Images/Primary?quality=90";

                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => _openLibrary(context, lib),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      httpHeaders: {
                                        "X-Emby-Token": widget.token,
                                      },
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.blueGrey[900],
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                            color: Colors.grey[900],
                                            child: const Icon(
                                              Icons.folder,
                                              color: Colors.white,
                                              size: 34,
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
                                            Color(0x99000000),
                                            Color(0xDD000000),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Align(
                                        alignment: Alignment.bottomLeft,
                                        child: Text(
                                          lib.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: screenWidth >= 1000
                                                ? 16
                                                : 14,
                                            fontWeight: FontWeight.w700,
                                            shadows: const [
                                              Shadow(
                                                color: Colors.black87,
                                                blurRadius: 10,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: const AdBannerWidget(),
    );
  }
}
