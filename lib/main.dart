import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:media_kit/media_kit.dart';

import 'l10n/app_localizations.dart';
import 'screens/downloads_screen.dart';
import 'screens/library_selector_screen.dart';
import 'screens/login_screen.dart';
import 'services/ads_consent.dart';
import 'services/download_service.dart';
import 'services/jellyfin_api.dart';
import 'services/my_audio_handler.dart';
import 'services/playback_sync_service.dart';
import 'services/server_certificate_trust.dart';
import 'services/storage_service.dart';
import 'models/library.dart';

late MyAudioHandler audioHandler;
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ServerCertificateTrust.install();
  await ServerCertificateTrust.restore(StorageService());
  MediaKit.ensureInitialized();
  await PlaybackSyncService.instance.initialize();

  await DownloadService().initialize();

  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.dawtyl.jellydawtyl.audio',
      androidNotificationChannelName: 'Odtwarzanie w tle',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
      androidNotificationIcon: 'drawable/ic_player_notification',
    ),
  );

  if (Platform.isAndroid || Platform.isIOS) {
    await FlutterDownloader.initialize(debug: kDebugMode, ignoreSsl: false);
    await ServerCertificateTrust.syncAndroidDownloaderTrust();
    if (Platform.isAndroid) {
      await DownloadService().initializeBackgroundDownloads();
    }
  }

  runApp(RestartWidget(child: JellyfinApp()));
}

class JellyfinApp extends StatefulWidget {
  const JellyfinApp({super.key});

  @override
  State<JellyfinApp> createState() => _JellyfinAppState();
}

class _JellyfinAppState extends State<JellyfinApp> with WidgetsBindingObserver {
  bool _isLoadingPref = true;
  bool _showAdPrompt = false;
  Locale _locale = const Locale('pl');
  final Set<String> _promptedFailureIds = {};
  bool _showingFailurePrompt = false;

  /// Kept in a field: creating the future in `build` restarted the storage
  /// read and the library request on every `setState`.
  late Future<Map<String, dynamic>?> _appData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appData = checkAppData();
    _loadLocalePreference();
    _checkAdPreference();
    DownloadService().failedDownloads.addListener(_maybePromptFailedDownloads);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybePromptFailedDownloads(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DownloadService().failedDownloads.removeListener(
      _maybePromptFailedDownloads,
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PlaybackSyncService.instance.onAppResumed();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      PlaybackSyncService.instance.onAppPaused();
    }
  }

  void _maybePromptFailedDownloads() {
    if (_showingFailurePrompt) return;
    final failures = DownloadService().failedDownloads.value;
    final pending = failures
        .where((failure) => !_promptedFailureIds.contains(failure['itemId']))
        .toList();
    if (pending.isEmpty) return;
    final dialogContext = rootNavigatorKey.currentContext;
    if (dialogContext == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybePromptFailedDownloads(),
      );
      return;
    }

    final ids = pending.map((failure) => failure['itemId'] as String).toList();
    _promptedFailureIds.addAll(ids);
    _showingFailurePrompt = true;
    final names = pending
        .map((failure) => failure['fileName'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .take(3)
        .map((name) => name.replaceAll('.mp4', '').replaceAll('_', ' '))
        .join(', ');
    showDialog<void>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(dialogContext)!.failedDownloadTitle),
        content: Text(
          '${AppLocalizations.of(dialogContext)!.failedDownloadCount(pending.length)}${names.isEmpty ? '' : '\n$names'}\n\n${AppLocalizations.of(dialogContext)!.failedDownloadRetryQuestion}',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await DownloadService().dismissFailedDownloads(ids);
              _showingFailurePrompt = false;
              _maybePromptFailedDownloads();
            },
            child: Text(AppLocalizations.of(dialogContext)!.no),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _showingFailurePrompt = false;
              unawaited(
                DownloadService().retryFailedDownloads(ids).whenComplete(() {
                  _promptedFailureIds.removeAll(ids);
                  _maybePromptFailedDownloads();
                }),
              );
            },
            child: Text(AppLocalizations.of(dialogContext)!.retry),
          ),
        ],
      ),
    ).then((_) {
      _showingFailurePrompt = false;
      _maybePromptFailedDownloads();
    });
  }

  Future<void> _loadLocalePreference() async {
    final languageCode = await StorageService().getString('setting_language');
    final locale = languageCode != null && ['pl', 'en'].contains(languageCode)
        ? Locale(languageCode)
        : const Locale('pl');

    if (mounted) {
      setState(() => _locale = locale);
    }
  }

  void _reloadAppData() {
    setState(() => _appData = checkAppData());
  }

  Future<void> _checkAdPreference() async {
    final storage = StorageService();

    // AdMob exists only on Android and iOS; desktop builds never ask.
    if (!adsSupportedOnThisPlatform) {
      await storage.saveString('setting_ads_choice', 'no');
    }

    final adsChoice = await storage.getString('setting_ads_choice');
    if (!mounted) return;

    _isLoadingPref = false;
    _showAdPrompt = adsChoice == null;
    _reloadAppData();
    if (adsChoice == 'yes') {
      _gatherConsentAndInitAds();
    }
  }

  Future<void> _saveAdPreference(bool allowAds) async {
    await StorageService().saveString(
      'setting_ads_choice',
      allowAds ? 'yes' : 'no',
    );
    _showAdPrompt = false;
    _reloadAppData();

    if (allowAds) {
      _gatherConsentAndInitAds();
    } else {
      debugPrint('Użytkownik odmówił reklam. AdMob nie zostanie załadowany.');
    }
  }

  Future<void> _gatherConsentAndInitAds() async {
    final params = buildConsentRequestParameters();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          _loadConsentForm();
        } else {
          _initializeAds();
        }
      },
      (FormError error) {
        debugPrint("Błąd sprawdzania zgody: ${error.message}");
        _initializeAds();
      },
    );
  }

  void _loadConsentForm() {
    ConsentForm.loadConsentForm(
      (ConsentForm consentForm) async {
        var status = await ConsentInformation.instance.getConsentStatus();
        if (status == ConsentStatus.required) {
          consentForm.show((FormError? formError) {
            _loadConsentForm();
          });
        } else {
          _initializeAds();
        }
      },
      (FormError formError) {
        debugPrint("Błąd ładowania formularza: ${formError.message}");
        _initializeAds();
      },
    );
  }

  void _initializeAds() async {
    await MobileAds.instance.initialize();
    debugPrint('AdMob załadowany.');
  }

  Future<Map<String, dynamic>?> checkAppData() async {
    final storage = StorageService();

    Map<String, String>? creds;
    try {
      creds = await storage.getCredentials();
    } catch (error) {
      debugPrint(
        'Nie udało się odczytać danych z bezpiecznego magazynu (${error.runtimeType}).',
      );
      return {'credentialStorageError': true};
    }

    if (_isLoadingPref) {
      return {'loadingPreference': true};
    }

    if (_showAdPrompt) {
      return {'needsAdsPrompt': true};
    }

    if (creds == null || creds['token'] == null) {
      return creds == null ? null : {'creds': creds};
    }

    try {
      final libraries = await JellyfinApi().fetchUserLibrariesOrThrow(
        creds['baseUrl']!,
        creds['token']!,
        creds['userId']!,
      );
      return {'creds': creds, 'libraries': libraries};
    } on JellyfinUnauthorizedException {
      // The token expired or was revoked: forget it, keep the address.
      debugPrint('Zapisany token jest nieważny.');
      await storage.clearCredentials();
      return {
        'creds': {'baseUrl': creds['baseUrl']!},
      };
    } catch (error) {
      // No network or the server is down: the session may still be valid.
      debugPrint('Serwer jest nieosiągalny (${error.runtimeType}).');
      return {'creds': creds, 'serverUnreachable': true};
    }
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF0F1115);
    const surface = Color(0xFF171B22);
    const accent = Color(0xFF8B5CF6);
    const secondary = Color(0xFF22D3EE);

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      home: FutureBuilder<Map<String, dynamic>?>(
        future: _appData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final data = snapshot.data;

          if (data?['loadingPreference'] == true) {
            return const Scaffold(
              backgroundColor: background,
              body: Center(child: CircularProgressIndicator(color: accent)),
            );
          }

          if (data?['needsAdsPrompt'] == true) {
            return _buildAdPromptScreen(context, background, surface, accent);
          }

          if (data?['credentialStorageError'] == true) {
            return Scaffold(
              backgroundColor: background,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, color: accent, size: 40),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.credentialStorageError,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _reloadAppData,
                        child: Text(AppLocalizations.of(context)!.tryAgain),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (data?['serverUnreachable'] == true) {
            return _buildServerUnreachableScreen(context, background, accent);
          }

          final libraries = data?['libraries'];

          if (data != null && libraries is List<Library>) {
            final creds = data['creds'] as Map<String, String>;

            return LibrarySelectorScreen(
              libraries: libraries,
              baseUrl: creds['baseUrl']!,
              token: creds['token']!,
              userId: creds['userId']!,
            );
          }

          return LoginScreen(initialUrl: data?['creds']?['baseUrl']);
        },
      ),
      debugShowCheckedModeBanner: false,
      title: 'JellyDawtyl',
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
          PointerDeviceKind.unknown,
        },
      ),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: secondary,
          surface: surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2B3240)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: accent, width: 1.4),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }

  Widget _buildServerUnreachableScreen(
    BuildContext context,
    Color background,
    Color accent,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, color: accent, size: 48),
              const SizedBox(height: 16),
              Text(
                l10n.serverUnreachable,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _reloadAppData,
                child: Text(l10n.tryAgain),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.download_done_rounded),
                label: Text(l10n.offlineFiles),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const DownloadsScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdPromptScreen(
    BuildContext context,
    Color bg,
    Color surface,
    Color accent,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              color: surface,
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.redAccent,
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tytuł
                    Text(
                      l10n.supportCreatorTitle,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Główny tekst
                    Text(
                      l10n.supportCreatorBody1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Pudełko informacyjne o braku reklam
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            color: Colors.white54,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.supportCreatorBody2,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white60,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Przycisk "Tak"
                    ElevatedButton(
                      onPressed: () => _saveAdPreference(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        elevation: 6,
                        shadowColor: accent.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        minimumSize: const Size.fromHeight(54),
                      ),
                      child: Text(
                        l10n.supportCreatorAccept,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Przycisk "Nie"
                    OutlinedButton(
                      onPressed: () => _saveAdPreference(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: const BorderSide(color: Colors.white12),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        l10n.supportCreatorDecline,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RestartWidget extends StatefulWidget {
  final Widget child;

  const RestartWidget({super.key, required this.child});

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restartApp();
  }

  static void restartAppFromRootNavigator() {
    rootNavigatorKey.currentContext
        ?.findAncestorStateOfType<_RestartWidgetState>()
        ?.restartApp();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (context.mounted) {
      return KeyedSubtree(key: key, child: widget.child);
    }
    return widget.child;
  }
}
