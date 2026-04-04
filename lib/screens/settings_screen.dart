import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/storage_service.dart';
import '../widgets/ad_banner_widget.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storage = StorageService();

  bool _isLoading = true;

  bool _autoPlayNext = true;
  bool _downloadWifiOnly = true;
  bool _useNativeDownloader = false;
  bool _showAds = false;

  String? _customDownloadPath;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final autoPlay = await _storage.getSetting(
      'setting_autoplay',
      defaultValue: true,
    );
    final wifiOnly = await _storage.getSetting(
      'setting_wifionly',
      defaultValue: true,
    );
    final nativeDownloader = await _storage.getSetting(
      'setting_native_downloader',
      defaultValue: false,
    );

    final customPath = await _storage.getString('setting_download_path');
    final adsChoice = await _storage.getString('setting_ads_choice');

    setState(() {
      _autoPlayNext = autoPlay;
      _downloadWifiOnly = wifiOnly;
      _useNativeDownloader = nativeDownloader;
      _customDownloadPath = customPath;
      _showAds = (adsChoice == 'yes');
      _isLoading = false;
    });
  }

  Future<void> _updateSetting(
    String key,
    bool value,
    Function(bool) updateLocalState,
  ) async {
    setState(() {
      updateLocalState(value);
    });
    await _storage.saveSetting(key, value);
  }

  Future<void> _updateAdsSetting(bool value) async {
    setState(() {
      _showAds = value;
    });

    await _storage.saveString('setting_ads_choice', value ? 'yes' : 'no');

    if (mounted) {
      RestartWidget.restartApp(context);
    }
  }

  Future<void> _pickDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: "Wybierz folder pobierania",
    );

    if (selectedDirectory != null) {
      setState(() {
        _customDownloadPath = selectedDirectory;
      });
      await _storage.saveString('setting_download_path', selectedDirectory);
    }
  }

  Future<void> _resetDirectory() async {
    setState(() {
      _customDownloadPath = null;
    });
    await _storage.saveString('setting_download_path', '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    l10n.playback,
                    style: const TextStyle(
                      color: Colors.deepPurpleAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: Text(l10n.autoPlay),
                  subtitle: Text(l10n.autoPlaySub),
                  activeColor: Colors.deepPurpleAccent,
                  value: _autoPlayNext,
                  onChanged: (val) => _updateSetting(
                    'setting_autoplay',
                    val,
                    (v) => _autoPlayNext = v,
                  ),
                ),

                const Divider(height: 32, color: Colors.white24),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    l10n.downloading,
                    style: const TextStyle(
                      color: Colors.deepPurpleAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                ListTile(
                  title: Text(l10n.downloadFolder),
                  subtitle: Text(
                    _customDownloadPath != null &&
                            _customDownloadPath!.isNotEmpty
                        ? _customDownloadPath!
                        : l10n.defaultFolder,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_customDownloadPath != null &&
                          _customDownloadPath!.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.grey,
                          ),
                          tooltip: "Przywróć domyślny",
                          onPressed: _resetDirectory,
                        ),
                      const Icon(
                        Icons.folder_open_rounded,
                        color: Colors.deepPurpleAccent,
                      ),
                    ],
                  ),
                  onTap: _pickDirectory,
                ),

                SwitchListTile(
                  title: Text(l10n.downloadWifiOnly),
                  subtitle: Text(l10n.downloadWifiOnlySub),
                  activeColor: Colors.deepPurpleAccent,
                  value: _downloadWifiOnly,
                  onChanged: (val) => _updateSetting(
                    'setting_wifionly',
                    val,
                    (v) => _downloadWifiOnly = v,
                  ),
                ),
                SwitchListTile(
                  title: Text(l10n.useNativeDownloader),
                  subtitle: Text(l10n.useNativeDownloaderSub),
                  activeColor: Colors.deepPurpleAccent,
                  value: _useNativeDownloader,
                  onChanged: (val) => _updateSetting(
                    'setting_native_downloader',
                    val,
                    (v) => _useNativeDownloader = v,
                  ),
                ),

                const Divider(height: 32, color: Colors.white24),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    l10n.privacy,
                    style: const TextStyle(
                      color: Colors.deepPurpleAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // --- OPCJA: Wsparcie Twórcy (Reklamy) ---
                SwitchListTile(
                  title: Text(l10n.supportCreatorAdsTitle),
                  subtitle: Text(l10n.supportCreatorAdsSubtitle),
                  activeColor: Colors.deepPurpleAccent,
                  value: _showAds,
                  onChanged: _updateAdsSetting,
                ),

                ListTile(
                  title: Text(l10n.managePrivacy),
                  subtitle: Text(l10n.managePrivacySubtitle),
                  trailing: const Icon(
                    Icons.privacy_tip_outlined,
                    color: Colors.deepPurpleAccent,
                  ),
                  enabled: _showAds,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.loadingPrivacyOptions)),
                    );

                    ConsentInformation.instance.reset();

                    final String? testDeviceId =
                        dotenv.env['ADMOB_TEST_DEVICE_ID'];

                    ConsentRequestParameters params = ConsentRequestParameters(
                      consentDebugSettings: ConsentDebugSettings(
                        debugGeography: DebugGeography.debugGeographyEea,
                        testIdentifiers:
                            testDeviceId != null && testDeviceId.isNotEmpty
                            ? [testDeviceId]
                            : [],
                      ),
                    );

                    ConsentInformation.instance.requestConsentInfoUpdate(
                      params,
                      () async {
                        if (await ConsentInformation.instance
                            .isConsentFormAvailable()) {
                          ConsentForm.loadConsentForm(
                            (ConsentForm consentForm) {
                              ScaffoldMessenger.of(
                                context,
                              ).hideCurrentSnackBar();

                              consentForm.show((FormError? formError) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Ustawienia prywatności zostały zaktualizowane.",
                                    ),
                                  ),
                                );
                              });
                            },
                            (FormError formError) {
                              debugPrint(
                                "Błąd ładowania formularza UMP: ${formError.message}",
                              );
                            },
                          );
                        }
                      },
                      (FormError error) {
                        debugPrint(
                          "Błąd sprawdzania statusu UMP: ${error.message}",
                        );
                      },
                    );
                  },
                ),
              ],
            ),
      bottomNavigationBar: const AdBannerWidget(),
    );
  }
}
