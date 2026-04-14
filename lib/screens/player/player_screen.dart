import 'package:flutter/material.dart';

// --- IMPORTY TWOICH NOWYCH MODUŁÓW ---
// Upewnij się, że ścieżki (foldery) się zgadzają z Twoją strukturą projektu
import 'player_view_model.dart';
import 'widgets/video_display.dart';
import 'widgets/settings_bottom_sheet.dart';
import 'widgets/status_overlays.dart';

class PlayerScreen extends StatefulWidget {
  final String url;
  final String title;
  final String itemId;
  final String? baseUrl;
  final String? token;
  final String? userId;
  final bool isOffline;
  final int? startPositionMs;

  const PlayerScreen({
    super.key,
    required this.url,
    required this.title,
    required this.itemId,
    this.baseUrl,
    this.token,
    this.userId,
    this.isOffline = false,
    this.startPositionMs,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // 1. Inicjujemy nasz nowy mózg operacyjny - ViewModel
  late final PlayerViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    
    // Przekazujemy absolutnie wszystkie dane z oryginalnego widgetu do ViewModelu
    _viewModel = PlayerViewModel(
      originalUrl: widget.url,
      title: widget.title,
      itemId: widget.itemId,
      baseUrl: widget.baseUrl,
      token: widget.token,
      userId: widget.userId,
      isOffline: widget.isOffline,
      startPositionMs: widget.startPositionMs,
      
      // Callback, który wywoła się, gdy ViewModel wykryje, że trzeba włączyć kolejny odcinek
      onPlayNext: _handlePlayNext,
    );
    
    // Odpalamy całą logikę startową (Wakelock, API, Player, Subtitles)
    _viewModel.init();
  }

  // Funkcja odpowiedzialna za płynne przejście do kolejnego odcinka
  void _handlePlayNext(String nextUrl, String nextTitle, String nextItemId, bool isOffline) {
    if (!mounted) return;
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          url: nextUrl,
          title: nextTitle,
          itemId: nextItemId,
          baseUrl: widget.baseUrl,
          token: widget.token,
          userId: widget.userId,
          isOffline: isOffline,
        ),
      ),
    );
  }

  @override
  void dispose() {
    // ViewModel automatycznie posprząta: Wakelock, Timery, Playera i API
    _viewModel.dispose();
    super.dispose();
  }

  // Pokazywanie menu ustawień (używa Twojego nowego modułu)
  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF171B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PlayerSettingsSheet(viewModel: _viewModel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        // ListenableBuilder nasłuchuje zmian z ViewModelu i odświeża interfejs (np. błędy, ładowanie)
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                
                // --- 1. ODTWARZACZ WIDEO, PASEK GÓRNY I GESTY ---
                // (Wszystko z Twojego pliku video_display.dart)
                PlayerVideoDisplay(
                  viewModel: _viewModel,
                  title: widget.title,
                  onSettingsPressed: _showSettingsMenu,
                ),

                // --- 2. NAKŁADKA ŁADOWANIA ---
                // (Animowane logo SVG z Twojego pliku status_overlays.dart)
                if (_viewModel.isLoading && _viewModel.error == null)
                  const PlayerLoadingView(),

                // --- 3. NAKŁADKA BŁĘDU ---
                // (Ostrzeżenie z przyciskiem z Twojego pliku status_overlays.dart)
                if (_viewModel.error != null)
                  PlayerErrorView(
                    error: _viewModel.error!,
                    onClose: () => Navigator.pop(context),
                  ),
                  
              ],
            );
          },
        ),
      ),
    );
  }
}