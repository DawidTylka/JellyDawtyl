import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/jellyfin_item.dart';
import 'item_navigation.dart';
import '../widgets/ad_banner_widget.dart';
import '../widgets/favorite_button.dart';
import '../widgets/item_artwork.dart';

/// Loads one page of a server-side list. [searchTerm] is null when the user
/// is not searching.
typedef ItemPageLoader =
    Future<List<JellyfinItem>> Function(int startIndex, String? searchTerm);

class CategoryItemsScreen extends StatefulWidget {
  final List<JellyfinItem> items;

  /// When set, the list is paged: further pages load while scrolling and the
  /// search box queries the server instead of only the loaded items.
  final ItemPageLoader? pageLoader;
  final int pageSize;
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
    this.pageLoader,
    this.pageSize = 100,
  });

  @override
  State<CategoryItemsScreen> createState() => _CategoryItemsScreenState();
}

class _CategoryItemsScreenState extends State<CategoryItemsScreen> {
  late List<JellyfinItem> _filteredItems;
  late List<JellyfinItem> _pagedItems;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  bool _isLoadingPage = false;
  late bool _hasMore;
  int _requestGeneration = 0;

  bool get _isPaged => widget.pageLoader != null;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _pagedItems = List.of(widget.items);
    _hasMore = _isPaged && widget.items.length >= widget.pageSize;
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String? get _searchTerm {
    final query = _searchController.text.trim();
    return query.isEmpty ? null : query;
  }

  bool _pageFailed = false;

  void _maybeLoadMore() {
    if (!_isPaged || !_hasMore || _isLoadingPage || _pageFailed) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 600) {
      unawaited(_loadPage(reset: false));
    }
  }

  Future<void> _loadPage({required bool reset}) async {
    final loader = widget.pageLoader;
    if (loader == null) return;
    final generation = ++_requestGeneration;
    setState(() => _isLoadingPage = true);
    final start = reset ? 0 : _pagedItems.length;
    final List<JellyfinItem> page;
    try {
      page = await loader(start, _searchTerm);
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      // Keep what is loaded and let the user retry; scrolling does not
      // retry on its own, so an offline device is not hammered.
      setState(() {
        _isLoadingPage = false;
        _pageFailed = true;
      });
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.loadError),
          action: SnackBarAction(
            label: l10n.retry,
            onPressed: () {
              _pageFailed = false;
              unawaited(_loadPage(reset: reset));
            },
          ),
        ),
      );
      return;
    }
    if (!mounted || generation != _requestGeneration) return;
    setState(() {
      _pageFailed = false;
      _pagedItems = reset ? page : [..._pagedItems, ...page];
      _filteredItems = _pagedItems;
      _hasMore = page.length >= widget.pageSize;
      _isLoadingPage = false;
    });
  }

  void _filterItems(String query) {
    if (_isPaged) {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(
        const Duration(milliseconds: 350),
        () => unawaited(_loadPage(reset: true)),
      );
      return;
    }
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
        controller: _scrollController,
        padding: const EdgeInsets.all(15),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _filteredItems.length + (_isLoadingPage ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _filteredItems.length) {
            return const Center(child: CircularProgressIndicator());
          }
          final movie = _filteredItems[index];

          return GestureDetector(
            onTap: () => openItemDetails(
              context,
              movie,
              baseUrl: widget.baseUrl,
              token: widget.token,
              userId: widget.userId,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ItemArtwork(
                    item: movie,
                    baseUrl: widget.baseUrl,
                    token: widget.token,
                    query: 'quality=50&fillWidth=200',
                    placeholder: (context) =>
                        Container(color: Colors.grey[900]),
                    error: (context) => Container(
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.movie,
                        color: Colors.white30,
                        size: 40,
                      ),
                    ),
                  ),

                  if (movie.type == 'Series' || movie.type == 'Episode')
                    Positioned(
                      top: 6,
                      left: 6,
                      child: FavoriteButton(
                        baseUrl: widget.baseUrl,
                        token: widget.token,
                        userId: widget.userId,
                        itemId: movie.id,
                        initialIsFavorite: movie.userData?.isFavorite ?? false,
                        iconSize: 18,
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
