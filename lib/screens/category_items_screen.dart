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
              child: CachedNetworkImage(
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
            ),
          );
        },
      ),
      bottomNavigationBar: const AdBannerWidget(),
    );
  }
}
