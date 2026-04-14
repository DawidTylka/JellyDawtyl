import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/jellyfin_api.dart';
import '../widgets/ad_banner_widget.dart';
import '../l10n/app_localizations.dart';
import '../screens/details_screen.dart';
import '../screens/series_details_screen.dart';
import '../widgets/responsive_grid_layout.dart';
import '../widgets/media_grid_card.dart';

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

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final api = JellyfinApi();
    final favs = await api.fetchFavorites(
      widget.baseUrl,
      widget.token,
      widget.userId,
    );
    
    if (mounted) {
      setState(() {
        _favorites = favs;
        _isLoading = false;
      });
    }
  }

  void _navigateToDetails(Movie item) {
    // Sprawdzamy, czy ulubiony element to serial, czy pojedynczy film/odcinek
    if (item.type == 'Series') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SeriesDetailsScreen(
            series: item, // item to Movie, które dziedziczy z JellyfinItem - będzie pasować!
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
          builder: (_) => DetailsScreen(
            item: item, // Podobnie tutaj, to zadziała bez problemu.
            baseUrl: widget.baseUrl,
            token: widget.token,
            userId: widget.userId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(l10n.favorites),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
          : _favorites.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 80, color: Colors.white24),
                      SizedBox(height: 16),
                      Text("Brak ulubionych", style: TextStyle(color: Colors.white54, fontSize: 18)),
                    ],
                  ),
                )
              // --- TUTAJ UŻYWAMY NASZYCH NOWYCH WIDŻETÓW ---
              : ResponsiveGridLayout(
                  itemCount: _favorites.length,
                  itemBuilder: (context, index) {
                    final item = _favorites[index];
                    final imageUrl = "${widget.baseUrl}/Items/${item.id}/Images/Primary?quality=90";

                    return MediaGridCard(
                      title: item.name ?? "Brak tytułu",
                      // Używamy CachedNetworkImageProvider do ładowania z sieci z tokenem
                      imageProvider: CachedNetworkImageProvider(
                        imageUrl,
                        headers: {"X-Emby-Token": widget.token},
                      ),
                      badgeIcon: item.type == 'Series' ? Icons.tv : Icons.local_movies,
                      onTap: () => _navigateToDetails(item),
                    );
                  },
                ),
      bottomNavigationBar: const AdBannerWidget(),
    );
  }
}