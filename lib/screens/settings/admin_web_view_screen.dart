import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/storage_service.dart';
import '../../l10n/app_localizations.dart';

class AdminWebViewScreen extends StatefulWidget {
  const AdminWebViewScreen({super.key});

  @override
  State<AdminWebViewScreen> createState() => _AdminWebViewScreenState();
}

class _AdminWebViewScreenState extends State<AdminWebViewScreen> {
  final StorageService _storage = StorageService();

  bool _isLoading = false;
  bool _isLoggedIn = false;
  
  WebViewController? _controller;
  String _serverUrl = "";

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    final serverUrl = await _storage.getString('baseUrl') ?? '';
    
    if (serverUrl.isNotEmpty) {
      setState(() {
        _serverUrl = serverUrl;
        _isLoggedIn = true;
      });
      _initWebView();
    } else {
      setState(() {
        _isLoading = false;
        _isLoggedIn = false;
      });
    }
  }

  void _initWebView() async {
    final adminUrl = "$_serverUrl/web/#/mypreferencesmenu";

    final controller = WebViewController();

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (adminUrl) {
            if (mounted) setState(() => _isLoading = false);
          },
          onUrlChange: (UrlChange change) {
            final currentUrl = change.url ?? '';
            
            if (currentUrl.contains('#/home') || currentUrl.contains('home.html')) {
              controller.runJavaScript("window.location.hash = '#!/mypreferencesmenu';");
            }
          },
        ),
      );

    if (mounted) {
      setState(() => _controller = controller);
    }

    await controller.loadHtmlString(
      """
      <!DOCTYPE html>
      <html lang="pl">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            /* Reset i przygotowanie tła pod styl Jellyfina */
            body {
              margin: 0;
              padding: 0;
              background-color: #101010; /* Ciemne tło */
              display: flex;
              flex-direction: column;
              align-items: center;
              justify-content: center;
              height: 100vh;
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
              overflow: hidden;
            }

            /* Animowane kółko ładowania */
            .spinner {
              width: 48px;
              height: 48px;
              border: 4px solid rgba(255, 255, 255, 0.1);
              border-top-color: #7C4DFF; /* Kolor deepPurpleAccent */
              border-radius: 50%;
              animation: spin 1s cubic-bezier(0.55, 0.15, 0.45, 0.85) infinite;
              margin-bottom: 24px;
            }

            /* Animacja obrotu */
            @keyframes spin {
              0% { transform: rotate(0deg); }
              100% { transform: rotate(360deg); }
            }

            /* Styl tekstu */
            .text {
              color: #E0E0E0;
              font-size: 16px;
              font-weight: 500;
              letter-spacing: 0.5px;
            }
          </style>

          <script>
            // Funkcja wstrzykująca dane do localStorage
            function injectAndRedirect() {
              window.location.replace('$adminUrl');
            }

            // Dajemy WebView 300ms na płynne wyrenderowanie animacji, zanim JavaScript zablokuje wątek na przekierowanie
            window.onload = function() {
              setTimeout(injectAndRedirect, 300);
            };
          </script>
        </head>
        <body>
          <div class="spinner"></div>
          <div class="text">Autoryzacja serwera...</div>
        </body>
      </html>
      """,
      baseUrl: _serverUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.serverPanel),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading && !_isLoggedIn) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        if (_isLoading)
          Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(l10n.loadingPanel, style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}