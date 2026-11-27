import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/storage_service.dart';
import '../../utils/server_url.dart';
import '../../l10n/app_localizations.dart';

class AdminWebViewScreen extends StatefulWidget {
  const AdminWebViewScreen({super.key});

  @override
  State<AdminWebViewScreen> createState() => _AdminWebViewScreenState();
}

class _AdminWebViewScreenState extends State<AdminWebViewScreen> {
  final StorageService _storage = StorageService();

  // True until the first page has loaded, so the overlay is visible.
  bool _isLoading = true;
  bool _isLoggedIn = false;

  WebViewController? _controller;
  String _serverUrl = "";

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    final serverUrl = normalizeServerUrl(
      await _storage.getString('baseUrl') ?? '',
    );
    if (!mounted) return;

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

  Future<void> _initWebView() async {
    final adminUrl = Uri.parse('$_serverUrl/web/#/mypreferencesmenu');

    final controller = WebViewController();

    // The Jellyfin web client is a JavaScript application, so JavaScript
    // stays enabled. The page is loaded directly: no intermediate HTML with
    // the address pasted into a script. The user signs in to the web client
    // separately; the app's token is not passed to the page.
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onUrlChange: (UrlChange change) {
            final currentUrl = change.url ?? '';

            if (currentUrl.contains('#/home') ||
                currentUrl.contains('home.html')) {
              controller.runJavaScript(
                "window.location.hash = '#/mypreferencesmenu';",
              );
            }
          },
        ),
      );

    if (mounted) {
      setState(() => _controller = controller);
    }

    await controller.loadRequest(adminUrl);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.serverPanel)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    if (!_isLoggedIn) {
      return _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(child: Text(l10n.serverPanelNoServer));
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
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    l10n.loadingPanel,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
