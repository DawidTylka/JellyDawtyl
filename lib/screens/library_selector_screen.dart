import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/app_localizations.dart';
import '../models/jellyfin_item.dart';
import '../models/library.dart';
import '../services/jellyfin_api.dart';
import 'home_screen.dart';
import 'downloads_screen.dart';
import 'settings/settings_screen.dart';
import '../widgets/ad_banner_widget.dart';
import '../widgets/jellyfin_section.dart';
import 'favorites_screen.dart';
import 'search_screen.dart';
import 'unwanted_lists_screen.dart';
import '../services/unwanted_api.dart';
import '../utils/jellyfin_auth.dart';

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
  List<JellyfinItem> _nextUpItems = [];
  bool _isLoadingResume = true;
  bool _isLoadingNextUpItems = true;
  bool _hasUnwantedPlugin = false;

  @override
  void initState() {
    super.initState();
    _loadResumeItems();
    _loadNextUpItems();
    _checkUnwantedPlugin();
    // Snoozing or hiding a series changes "Next up".
    UnwantedApi().changes.addListener(_loadNextUpItems);
  }

  @override
  void dispose() {
    UnwantedApi().changes.removeListener(_loadNextUpItems);
    super.dispose();
  }

  Future<void> _checkUnwantedPlugin() async {
    final available = await UnwantedApi().isAvailable(
      widget.baseUrl,
      widget.token,
    );
    if (mounted) setState(() => _hasUnwantedPlugin = available);
  }

  Future<void> _refreshSelectorData() async {
    await Future.wait([_loadResumeItems(), _loadNextUpItems()]);
  }

  /// Opens [screen] and refreshes "Continue watching" and "Next up" after,
  /// since watching or favoriting there changes both.
  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _refreshSelectorData();
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

  Future<void> _loadNextUpItems() async {
    final api = JellyfinApi();
    try {
      final nextToWatch = await api.fetchNextUp(
        widget.baseUrl,
        widget.token,
        widget.userId,
      );
      if (mounted) {
        setState(() {
          _nextUpItems = nextToWatch;
          _isLoadingNextUpItems = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingNextUpItems = false);
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
      // The three lists are independent, so they load in parallel.
      final results = await Future.wait([
        api.fetchResumeItems(
          widget.baseUrl,
          widget.token,
          widget.userId,
          parentId: lib.id,
        ),
        api.fetchLatestItems(
          widget.baseUrl,
          widget.token,
          widget.userId,
          lib.id,
        ),
        api.fetchAllInLibrary(
          widget.baseUrl,
          widget.token,
          widget.userId,
          lib.id,
        ),
      ]);
      final resume = results[0];
      final latest = results[1];
      final all = results[2];
      if (!context.mounted) return;
      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            resumeMovies: resume,
            latestMovies: latest,
            allMovies: all,
            libraryId: lib.id,
            libraryName: lib.name,
            baseUrl: widget.baseUrl,
            token: widget.token,
            userId: widget.userId,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Błąd otwierania biblioteki (${e.runtimeType}).');
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.libraryLoadError)));
    }
  }

  int _getGridColumnCount(double width) {
    if (width >= 1400) return 5;
    if (width >= 1100) return 4;
    if (width >= 800) return 3;
    return 2;
  }

  Widget _buildResumeSection(double screenWidth, AppLocalizations l10n) {
    final cleanUrl = widget.baseUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JellyfinSection(
          title: l10n.continueWatching,
          items: _resumeItems,
          aspectRatio: 16 / 9,
          baseUrl: cleanUrl,
          token: widget.token,
          userId: widget.userId,
          onRefresh: _refreshSelectorData,
          showShowAllButton: false,
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildNextUpSection(double screenWidth, AppLocalizations l10n) {
    final cleanUrl = widget.baseUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JellyfinSection(
          title: l10n.toWatch,
          items: _nextUpItems,
          aspectRatio: 16 / 9,
          baseUrl: cleanUrl,
          token: widget.token,
          userId: widget.userId,
          onRefresh: _refreshSelectorData,
          showShowAllButton: false,
        ),

        const SizedBox(height: 20),
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
            icon: const Icon(Icons.search),
            tooltip: l10n.search,
            onPressed: () => _push(
              SearchScreen(
                baseUrl: widget.baseUrl,
                token: widget.token,
                userId: widget.userId,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.favorite_outline, color: Colors.redAccent),
            tooltip: l10n.favorites,
            onPressed: () => _push(
              FavoriteScreen(
                baseUrl: widget.baseUrl,
                token: widget.token,
                userId: widget.userId,
              ),
            ),
          ),
          if (_hasUnwantedPlugin)
            IconButton(
              icon: const Icon(Icons.playlist_play, color: Colors.amberAccent),
              tooltip: l10n.unwantedMyLists,
              onPressed: () => _push(
                UnwantedListsScreen(
                  baseUrl: widget.baseUrl,
                  token: widget.token,
                  userId: widget.userId,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(
              Icons.folder_copy_outlined,
              color: Colors.greenAccent,
            ),
            tooltip: l10n.offlineFiles,
            onPressed: () => _push(const DownloadsScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white70),
            tooltip: l10n.settings,
            onPressed: () => _push(const SettingsScreen()),
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

          return RefreshIndicator(
            onRefresh: _refreshSelectorData,
            child: Scrollbar(
              thumbVisibility: screenWidth >= 1000,
              child: SingleChildScrollView(
                primary: true,
                physics: const AlwaysScrollableScrollPhysics(),
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

                        if (_isLoadingNextUpItems)
                          const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_nextUpItems.isNotEmpty)
                          _buildNextUpSection(screenWidth, l10n),

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
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: gridColumns,
                                mainAxisSpacing: 15,
                                crossAxisSpacing: 15,
                                childAspectRatio: gridAspectRatio,
                              ),
                          itemCount: widget.libraries.length,
                          itemBuilder: (context, index) {
                            final lib = widget.libraries[index];
                            final baseUrl = widget.baseUrl;
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
                                        httpHeaders: jellyfinAuthHeaders(
                                          widget.token,
                                        ),
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
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
            ),
          );
        },
      ),
      bottomNavigationBar: const AdBannerWidget(),
    );
  }
}
