import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/movie.dart';
import 'item_navigation.dart';
import '../services/jellyfin_api.dart';
import '../widgets/ad_banner_widget.dart';
import '../widgets/favorite_button.dart';
import '../widgets/item_artwork.dart';
import '../widgets/media_grid_card.dart';
import '../widgets/message_view.dart';
import '../widgets/responsive_grid_layout.dart';

enum _FavoriteFilter { all, movies, series, episodes }

enum _FavoriteSort {
  name('SortName', 'Ascending'),
  dateAdded('DateCreated', 'Descending'),
  premiere('PremiereDate', 'Descending'),
  rating('CommunityRating', 'Descending');

  final String sortBy;
  final String order;
  const _FavoriteSort(this.sortBy, this.order);
}

class FavoriteScreen extends StatefulWidget {
  final String baseUrl;
  final String token;
  final String userId;

  const FavoriteScreen({
    super.key,
    required this.baseUrl,
    required this.token,
    required this.userId,
  });

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  List<Movie> _favorites = [];
  bool _isLoading = true;
  bool _failed = false;
  _FavoriteFilter _filter = _FavoriteFilter.all;
  _FavoriteSort _sort = _FavoriteSort.name;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final favs = await JellyfinApi().fetchFavoritesOrThrow(
        widget.baseUrl,
        widget.token,
        widget.userId,
        sortBy: _sort.sortBy,
        sortOrder: _sort.order,
      );
      if (!mounted) return;
      setState(() {
        _favorites = favs;
        _isLoading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _failed = _favorites.isEmpty;
      });
      if (_favorites.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.loadError)),
        );
      }
    }
  }

  bool _matches(Movie item, _FavoriteFilter filter) {
    switch (filter) {
      case _FavoriteFilter.all:
        return true;
      case _FavoriteFilter.movies:
        return item.type == 'Movie';
      case _FavoriteFilter.series:
        return item.type == 'Series';
      case _FavoriteFilter.episodes:
        return item.type == 'Episode';
    }
  }

  String _filterLabel(AppLocalizations l10n, _FavoriteFilter filter) {
    switch (filter) {
      case _FavoriteFilter.all:
        return l10n.favoritesAll;
      case _FavoriteFilter.movies:
        return l10n.favoritesMovies;
      case _FavoriteFilter.series:
        return l10n.favoritesSeries;
      case _FavoriteFilter.episodes:
        return l10n.favoritesEpisodes;
    }
  }

  String _sortLabel(AppLocalizations l10n, _FavoriteSort sort) {
    switch (sort) {
      case _FavoriteSort.name:
        return l10n.sortName;
      case _FavoriteSort.dateAdded:
        return l10n.sortDateAdded;
      case _FavoriteSort.premiere:
        return l10n.sortPremiere;
      case _FavoriteSort.rating:
        return l10n.sortRating;
    }
  }

  Future<void> _navigateToDetails(Movie item) async {
    await openItemDetails(
      context,
      item,
      baseUrl: widget.baseUrl,
      token: widget.token,
      userId: widget.userId,
    );
    // The favorite, progress or watched state may have changed there.
    if (mounted) _loadFavorites();
  }

  Widget _buildFilters(AppLocalizations l10n) {
    final counts = {
      for (final f in _FavoriteFilter.values)
        f: _favorites.where((item) => _matches(item, f)).length,
    };
    final visible = _FavoriteFilter.values
        .where((f) => f == _FavoriteFilter.all || counts[f]! > 0)
        .toList();
    if (visible.length <= 2) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final f in visible)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${_filterLabel(l10n, f)} (${counts[f]})'),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid(AppLocalizations l10n) {
    final items = _favorites.where((i) => _matches(i, _filter)).toList();
    if (items.isEmpty) {
      return MessageView(
        icon: Icons.filter_alt_off,
        title: l10n.noFavoritesInFilter,
      );
    }
    return ResponsiveGridLayout(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final positionTicks = item.userData?.playbackPositionTicks;
        final runTimeTicks = item.runTimeTicks;
        final isPlayed = item.userData?.played ?? false;
        final unplayedCount = item.userData?.unplayedItemCount;
        final isSeries = item.type == 'Series';

        var progress = 0.0;
        if (positionTicks != null && runTimeTicks != null && runTimeTicks > 0) {
          progress = (positionTicks / runTimeTicks).clamp(0.0, 1.0);
        }
        final isWatched = isPlayed || progress >= 0.95;

        return MediaGridCard(
          title: item.name,
          subtitle: item.type == 'Episode'
              ? l10n.episodeOf(
                  item.seriesName ?? '',
                  item.parentIndexNumber ?? 0,
                  item.indexNumber ?? 0,
                )
              : null,
          image: ItemArtwork(
            item: item,
            baseUrl: widget.baseUrl,
            token: widget.token,
            placeholder: (context) => Container(color: Colors.grey[900]),
            error: (context) => Container(
              color: Colors.grey[800],
              child: const Icon(Icons.movie, color: Colors.white30, size: 40),
            ),
          ),
          badgeIcon: switch (item.type) {
            'Series' => Icons.tv,
            'Episode' => Icons.video_library_outlined,
            _ => Icons.local_movies,
          },
          onTap: () => _navigateToDetails(item),
          progress: isSeries ? null : progress,
          isWatched: isSeries ? null : isWatched,
          unplayedCount: isSeries ? unplayedCount : null,
          topLeftAction: FavoriteButton(
            baseUrl: widget.baseUrl,
            token: widget.token,
            userId: widget.userId,
            itemId: item.id,
            initialIsFavorite: true,
            iconSize: 18,
            onChanged: (isFavorite) {
              if (isFavorite || !mounted) return;
              setState(
                () => _favorites.removeWhere((fav) => fav.id == item.id),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.removeFromFavorites),
                  action: SnackBarAction(
                    label: l10n.undo,
                    onPressed: () async {
                      final ok = await JellyfinApi().setFavorite(
                        baseUrl: widget.baseUrl,
                        token: widget.token,
                        userId: widget.userId,
                        itemId: item.id,
                        isFavorite: true,
                      );
                      if (ok && mounted) _loadFavorites();
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final Widget body;
    if (_isLoading) {
      body = const Center(
        child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
      );
    } else if (_failed) {
      body = MessageView(
        icon: Icons.cloud_off,
        title: l10n.loadError,
        actionLabel: l10n.retry,
        onAction: () {
          setState(() => _isLoading = true);
          _loadFavorites();
        },
      );
    } else if (_favorites.isEmpty) {
      body = RefreshIndicator(
        onRefresh: _loadFavorites,
        child: MessageView(
          icon: Icons.favorite_border,
          title: l10n.noFavorites,
          hint: l10n.noFavoritesHint,
        ),
      );
    } else {
      body = Column(
        children: [
          _buildFilters(l10n),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadFavorites,
              child: _buildGrid(l10n),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(l10n.favorites),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<_FavoriteSort>(
            tooltip: l10n.sortBy,
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (sort) {
              setState(() => _sort = sort);
              _loadFavorites();
            },
            itemBuilder: (context) => [
              for (final sort in _FavoriteSort.values)
                CheckedPopupMenuItem(
                  value: sort,
                  checked: sort == _sort,
                  child: Text(_sortLabel(l10n, sort)),
                ),
            ],
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: const AdBannerWidget(),
    );
  }
}
