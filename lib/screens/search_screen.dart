import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/movie.dart';
import '../services/jellyfin_api.dart';
import '../widgets/item_artwork.dart';
import '../widgets/media_grid_card.dart';
import '../widgets/message_view.dart';
import '../widgets/responsive_grid_layout.dart';
import 'item_navigation.dart';

/// Search across all libraries. Before this the only search was inside one
/// library's "show all" list.
class SearchScreen extends StatefulWidget {
  final String baseUrl;
  final String token;
  final String userId;

  /// Limits the search to one library.
  final String? libraryId;
  final String? libraryName;

  const SearchScreen({
    super.key,
    required this.baseUrl,
    required this.token,
    required this.userId,
    this.libraryId,
    this.libraryName,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Movie> _results = const [];
  String _query = '';
  bool _loading = false;
  bool _failed = false;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    final requestId = ++_requestId;
    if (query.length < 2) {
      setState(() {
        _query = query;
        _results = const [];
        _loading = false;
        _failed = false;
      });
      return;
    }
    setState(() {
      _query = query;
      _loading = true;
      _failed = false;
    });
    try {
      final results = await JellyfinApi().searchItems(
        baseUrl: widget.baseUrl,
        token: widget.token,
        userId: widget.userId,
        query: query,
        parentId: widget.libraryId,
      );
      // Ignore answers to queries the user has already typed past.
      if (!mounted || requestId != _requestId) return;
      // Series and movies first: they are what people usually look for.
      int rank(Movie m) => switch (m.type) {
        'Series' => 0,
        'Movie' => 1,
        _ => 2,
      };
      final sorted = [...results]..sort((a, b) => rank(a).compareTo(rank(b)));
      setState(() {
        _results = sorted;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _open(Movie item) => openItemDetails(
    context,
    item,
    baseUrl: widget.baseUrl,
    token: widget.token,
    userId: widget.userId,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget body;
    if (_loading && _results.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_failed) {
      body = MessageView(
        icon: Icons.cloud_off,
        title: l10n.loadError,
        actionLabel: l10n.retry,
        onAction: () => _search(_controller.text),
      );
    } else if (_query.length < 2) {
      body = MessageView(icon: Icons.search, title: l10n.searchStartTyping);
    } else if (_results.isEmpty) {
      body = MessageView(
        icon: Icons.search_off,
        title: l10n.noSearchResults(_query),
      );
    } else {
      body = ResponsiveGridLayout(
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final item = _results[index];
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
                child: const Icon(Icons.movie, color: Colors.white30),
              ),
            ),
            badgeIcon: switch (item.type) {
              'Series' => Icons.tv,
              'Episode' => Icons.video_library_outlined,
              _ => Icons.local_movies,
            },
            isWatched: item.type == 'Series'
                ? null
                : (item.userData?.played ?? false),
            unplayedCount: item.type == 'Series'
                ? item.userData?.unplayedItemCount
                : null,
            onTap: () => _open(item),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: _search,
          decoration: InputDecoration(
            hintText: widget.libraryName != null
                ? l10n.searchInLibraryHint(widget.libraryName!)
                : l10n.searchEverywhereHint,
            border: InputBorder.none,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      _search('');
                    },
                  ),
          ),
        ),
        bottom: _loading && _results.isNotEmpty
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: body,
    );
  }
}
