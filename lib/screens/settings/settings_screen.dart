import '../../services/download_service.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/storage_service.dart';
import '../../widgets/ad_banner_widget.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ads_consent.dart';
import '../../services/jellyfin_api.dart';
import '../../services/playback_sync_service.dart';
import '../../main.dart';
import '../player/player_tls.dart';
import 'admin_web_view_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storage = StorageService();

  bool _isLoading = true;

  bool _autoPlayNext = true;
  bool _backgroundPlayback = false;
  bool _downloadWifiOnly = true;
  bool _useNativeDownloader = false;
  bool _showAds = false;
  bool _showSkipButton = true;
  bool _autoSkipIntro = false;
  bool _autoSkipCredits = false;
  bool _playerTlsVerify = true;
  int _maxConcurrentValue = 3;

  String? _customDownloadPath;
  String _selectedLanguage = 'pl';

  String? _hwAccelValue = 'auto';
  String? _cpuLimitValue = 'auto';
  String? _maxFpsValue = 'auto';
  String? _audioBitrateValue = 'auto';

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
    final backgroundPlayback = await _storage.getSetting(
      'setting_background_playback',
      defaultValue: false,
    );
    final nativeDownloader = await _storage.getSetting(
      'setting_native_downloader',
      defaultValue: false,
    );

    final showSkipButton = await _storage.getSetting(
      'setting_show_skip_button',
      defaultValue: true,
    );
    final autoSkipIntro = await _storage.getSetting(
      'setting_auto_skip_intro',
      defaultValue: false,
    );
    final autoSkipCredits = await _storage.getSetting(
      'setting_auto_skip_credits',
      defaultValue: false,
    );
    final playerTlsVerify = await _storage.getSetting(
      playerTlsVerifySettingKey,
      defaultValue: playerTlsVerifyDefault,
    );

    final maxConcurrent = await _storage.getInt(
      'setting_max_concurrent_downloads',
      defaultValue: 1,
    );

    final hwAccel = await _storage.getString('setting_hw_accel') ?? 'auto';
    final cpuLimit = await _storage.getString('setting_cpu_limit') ?? 'auto';
    final maxFps = await _storage.getString('setting_max_fps') ?? 'auto';
    final audioBitrate =
        await _storage.getString('setting_audio_bitrate') ?? 'auto';

    final customPath = await _storage.getString('setting_download_path');
    final adsChoice = await _storage.getString('setting_ads_choice');
    final languageCode = await _storage.getString('setting_language') ?? 'pl';

    if (!mounted) return;
    setState(() {
      _showSkipButton = showSkipButton;
      _autoSkipIntro = autoSkipIntro;
      _autoSkipCredits = autoSkipCredits;
      _playerTlsVerify = playerTlsVerify;
      _autoPlayNext = autoPlay;
      _backgroundPlayback = backgroundPlayback;
      _downloadWifiOnly = wifiOnly;
      _useNativeDownloader = nativeDownloader;
      _maxConcurrentValue = maxConcurrent;
      _customDownloadPath = customPath;
      _showAds = (adsChoice == 'yes');
      _selectedLanguage = ['pl', 'en'].contains(languageCode)
          ? languageCode
          : 'pl';
      _hwAccelValue = hwAccel;
      _cpuLimitValue = cpuLimit;
      _maxFpsValue = maxFps;
      _audioBitrateValue = audioBitrate;
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

  Future<void> _updateBackgroundPlayback(bool value) async {
    if (value && Platform.isAndroid) {
      await Permission.notification.request();
    }
    await _updateSetting(
      'setting_background_playback',
      value,
      (v) => _backgroundPlayback = v,
    );
  }

  Future<void> _pickDirectory() async {
    final l10n = AppLocalizations.of(context)!;
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isDenied) {
        final status = await Permission.manageExternalStorage.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.sdCardPermissionDenied)),
            );
          }
          return;
        }
      }
    }

    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.pickDownloadFolderTitle,
    );

    if (selectedDirectory != null) {
      setState(() {
        _customDownloadPath = selectedDirectory;
      });
      await _storage.saveString('setting_download_path', selectedDirectory);
      DownloadService().invalidateDirectoryPathCache();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.downloadPathUpdated)));
      }
    }
  }

  Future<void> _resetDirectory() async {
    setState(() {
      _customDownloadPath = null;
    });
    await _storage.saveString('setting_download_path', '');
    DownloadService().invalidateDirectoryPathCache();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: l10n.logoutTooltip,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.logoutConfirmTitle),
                  content: Text(l10n.logoutConfirmContent),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.cancel),
                    ),
                    TextButton(
                      onPressed: _logout,
                      child: Text(
                        l10n.logout,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildSectionTitle(l10n.general),
                ListTile(
                  title: Text(l10n.language),
                  subtitle: Text(l10n.languageSelectionSubtitle),
                  trailing: DropdownButton<String>(
                    value: _selectedLanguage,
                    dropdownColor: const Color(0xFF1C1C1E),
                    underline: const SizedBox(),
                    style: const TextStyle(color: Colors.white),
                    items: [
                      DropdownMenuItem(
                        value: 'pl',
                        child: Text(l10n.languagePolish),
                      ),
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(l10n.languageEnglish),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;

                      final currentContext = context;
                      await _storage.saveString('setting_language', value);

                      if (!mounted) return;

                      setState(() => _selectedLanguage = value);

                      if (currentContext.mounted) {
                        RestartWidget.restartApp(currentContext);
                      }
                    },
                  ),
                ),

                _buildSectionTitle(l10n.playback),
                SwitchListTile(
                  title: Text(l10n.autoPlay),
                  subtitle: Text(l10n.autoPlaySub),
                  activeThumbColor: Colors.deepPurpleAccent,
                  value: _autoPlayNext,
                  onChanged: (val) => _updateSetting(
                    'setting_autoplay',
                    val,
                    (v) => _autoPlayNext = v,
                  ),
                ),
                SwitchListTile(
                  title: Text(l10n.backgroundPlayback),
                  subtitle: Text(l10n.backgroundPlaybackSub),
                  activeThumbColor: Colors.deepPurpleAccent,
                  value: _backgroundPlayback,
                  onChanged: _updateBackgroundPlayback,
                ),
                SwitchListTile(
                  title: Text(l10n.playerTlsVerify),
                  subtitle: Text(l10n.playerTlsVerifySub),
                  activeThumbColor: Colors.deepPurpleAccent,
                  value: _playerTlsVerify,
                  onChanged: (val) => _updateSetting(
                    playerTlsVerifySettingKey,
                    val,
                    (v) => _playerTlsVerify = v,
                  ),
                ),

                const Divider(height: 32, color: Colors.white24),

                _buildSectionTitle(l10n.introSkipperSection),
                SwitchListTile(
                  title: Text(l10n.showSkipButton),
                  subtitle: Text(l10n.showSkipButtonSub),
                  activeThumbColor: Colors.deepPurpleAccent,
                  value: _showSkipButton,
                  onChanged: (val) => _updateSetting(
                    'setting_show_skip_button',
                    val,
                    (v) => _showSkipButton = v,
                  ),
                ),
                SwitchListTile(
                  title: Text(l10n.autoSkipIntro),
                  subtitle: Text(l10n.autoSkipIntroSub),
                  activeThumbColor: Colors.deepPurpleAccent,
                  value: _autoSkipIntro,
                  onChanged: (val) => _updateSetting(
                    'setting_auto_skip_intro',
                    val,
                    (v) => _autoSkipIntro = v,
                  ),
                ),
                SwitchListTile(
                  title: Text(l10n.autoSkipCredits),
                  subtitle: Text(l10n.autoSkipCreditsSub),
                  activeThumbColor: Colors.deepPurpleAccent,
                  value: _autoSkipCredits,
                  onChanged: (val) => _updateSetting(
                    'setting_auto_skip_credits',
                    val,
                    (v) => _autoSkipCredits = v,
                  ),
                ),

                const Divider(height: 32, color: Colors.white24),

                _buildSectionTitle(l10n.downloading),

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
                          tooltip: l10n.restoreDefaultTooltip,
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

                ListTile(
                  title: Text(l10n.concurrentDownloads),
                  subtitle: Text(l10n.concurrentDownloadsSub),
                  trailing: DropdownButton<int>(
                    value: _maxConcurrentValue,
                    dropdownColor: const Color(0xFF1C1C1E),
                    underline: const SizedBox(),
                    items: [1, 2, 3, 4, 5]
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e.toString(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) async {
                      if (val != null) {
                        await _storage.saveInt(
                          'setting_max_concurrent_downloads',
                          val,
                        );
                        await DownloadService().updateConcurrencyLimit();
                        if (mounted) setState(() => _maxConcurrentValue = val);
                      }
                    },
                  ),
                ),

                SwitchListTile(
                  title: Text(l10n.downloadWifiOnly),
                  subtitle: Text(l10n.downloadWifiOnlySub),
                  activeThumbColor: Colors.deepPurpleAccent,
                  value: _downloadWifiOnly,
                  onChanged: (val) => _updateSetting(
                    'setting_wifionly',
                    val,
                    (v) => _downloadWifiOnly = v,
                  ),
                ),

                if (Platform.isAndroid)
                  SwitchListTile(
                    title: Text(l10n.useNativeDownloader),
                    subtitle: Text(l10n.useNativeDownloaderSub),
                    activeThumbColor: Colors.deepPurpleAccent,
                    value: _useNativeDownloader,
                    onChanged: (val) => _updateSetting(
                      'setting_native_downloader',
                      val,
                      (v) => _useNativeDownloader = v,
                    ),
                  ),

                // Server-side transcoding knobs: rarely needed, so collapsed.
                ExpansionTile(
                  leading: const Icon(Icons.tune),
                  title: Text(l10n.advancedTranscoding),
                  children: [
                    ListTile(
                      title: Text(l10n.hwAccelTitle),
                      subtitle: Text(l10n.hwAccelSub),
                      trailing: DropdownButton<String>(
                        value: _hwAccelValue,
                        dropdownColor: const Color(0xFF1C1C1E),
                        underline: const SizedBox(),
                        style: const TextStyle(color: Colors.white),
                        items: [
                          DropdownMenuItem(
                            value: 'auto',
                            child: Text(l10n.autoServer),
                          ),
                          const DropdownMenuItem(
                            value: 'Vaapi',
                            child: Text("VAAPI (Linux/Intel)"),
                          ),
                          const DropdownMenuItem(
                            value: 'Nvenc',
                            child: Text("NVENC (Nvidia)"),
                          ),
                          const DropdownMenuItem(
                            value: 'Qsv',
                            child: Text("QSV (Intel)"),
                          ),
                          const DropdownMenuItem(
                            value: 'VideoToolbox',
                            child: Text("VideoToolbox (Mac)"),
                          ),
                        ],
                        onChanged: (val) => _saveStringSetting(
                          'setting_hw_accel',
                          val!,
                          (v) => _hwAccelValue = v,
                        ),
                      ),
                    ),

                    ListTile(
                      title: Text(l10n.cpuLimitTitle),
                      subtitle: Text(l10n.cpuLimitSub),
                      trailing: DropdownButton<String>(
                        value: _cpuLimitValue,
                        dropdownColor: const Color(0xFF1C1C1E),
                        underline: const SizedBox(),
                        style: const TextStyle(color: Colors.white),
                        items: [
                          DropdownMenuItem(
                            value: 'auto',
                            child: Text(l10n.autoNoLimit),
                          ),
                          DropdownMenuItem(value: '1', child: Text(l10n.core1)),
                          DropdownMenuItem(
                            value: '2',
                            child: Text(l10n.cores2),
                          ),
                          DropdownMenuItem(
                            value: '4',
                            child: Text(l10n.cores4),
                          ),
                          DropdownMenuItem(
                            value: '8',
                            child: Text(l10n.cores8),
                          ),
                        ],
                        onChanged: (val) => _saveStringSetting(
                          'setting_cpu_limit',
                          val!,
                          (v) => _cpuLimitValue = v,
                        ),
                      ),
                    ),

                    ListTile(
                      title: Text(l10n.fpsLimitTitle),
                      subtitle: Text(l10n.fpsLimitSub),
                      trailing: DropdownButton<String>(
                        value: _maxFpsValue,
                        dropdownColor: const Color(0xFF1C1C1E),
                        underline: const SizedBox(),
                        style: const TextStyle(color: Colors.white),
                        items: [
                          DropdownMenuItem(
                            value: 'auto',
                            child: Text(l10n.autoOriginal),
                          ),
                          DropdownMenuItem(
                            value: '24',
                            child: Text(l10n.fps24),
                          ),
                          DropdownMenuItem(
                            value: '30',
                            child: Text(l10n.fps30),
                          ),
                          DropdownMenuItem(
                            value: '60',
                            child: Text(l10n.fps60),
                          ),
                        ],
                        onChanged: (val) => _saveStringSetting(
                          'setting_max_fps',
                          val!,
                          (v) => _maxFpsValue = v,
                        ),
                      ),
                    ),

                    ListTile(
                      title: Text(l10n.audioQualityTitle),
                      subtitle: Text(l10n.audioQualitySub),
                      trailing: DropdownButton<String>(
                        value: _audioBitrateValue,
                        dropdownColor: const Color(0xFF1C1C1E),
                        underline: const SizedBox(),
                        style: const TextStyle(color: Colors.white),
                        items: [
                          DropdownMenuItem(
                            value: 'auto',
                            child: Text(l10n.autoOriginal),
                          ),
                          DropdownMenuItem(
                            value: '320000',
                            child: Text(l10n.audio320),
                          ),
                          DropdownMenuItem(
                            value: '192000',
                            child: Text(l10n.audio192),
                          ),
                          DropdownMenuItem(
                            value: '128000',
                            child: Text(l10n.audio128),
                          ),
                          DropdownMenuItem(
                            value: '96000',
                            child: Text(l10n.audio96),
                          ),
                        ],
                        onChanged: (val) => _saveStringSetting(
                          'setting_audio_bitrate',
                          val!,
                          (v) => _audioBitrateValue = v,
                        ),
                      ),
                    ),
                  ],
                ),

                const Divider(height: 32, color: Colors.white24),

                if (adsSupportedOnThisPlatform) ...[
                  _buildSectionTitle(l10n.privacy),
                  SwitchListTile(
                    title: Text(l10n.supportCreatorAdsTitle),
                    subtitle: Text(l10n.supportCreatorAdsSubtitle),
                    activeThumbColor: Colors.deepPurpleAccent,
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
                    onTap: _showPrivacyManager,
                  ),
                ],

                _buildSectionTitle(l10n.administration),
                ListTile(
                  leading: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.orangeAccent,
                  ),
                  title: Text(l10n.serverPanel),
                  subtitle: Text(l10n.serverPanelSub),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                  onTap: _openAdminPanel,
                ),
              ],
            ),
      bottomNavigationBar: const AdBannerWidget(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.deepPurpleAccent,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showPrivacyManager() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.loadingPrivacyOptions)));

    ConsentInformation.instance.reset();

    final params = buildConsentRequestParameters();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          ConsentForm.loadConsentForm(
            (ConsentForm consentForm) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              consentForm.show((FormError? formError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.privacySettingsUpdated)),
                );
              });
            },
            (FormError formError) {
              debugPrint("Błąd ładowania formularza UMP: ${formError.message}");
            },
          );
        }
      },
      (FormError error) {
        debugPrint("Błąd sprawdzania statusu UMP: ${error.message}");
      },
    );
  }

  /// Ends the session on the server, stops downloads that carry the token,
  /// and forgets the credentials. Offline playback changes stay queued with
  /// their user ID and are sent only after the same user logs in again.
  Future<void> _logout() async {
    // Server-side cleanup is best effort: whatever fails here, the local
    // login is still removed below.
    try {
      final creds = await _storage.getCredentials();
      if (creds != null && creds['token'] != null) {
        await PlaybackSyncService.instance.syncPending();
        await JellyfinApi().logout(creds['baseUrl']!, creds['token']!);
      }
    } catch (error) {
      debugPrint('Wylogowanie na serwerze nie powiodło się (${error.runtimeType}).');
    }
    try {
      await DownloadService().cancelAllAndForgetTokens();
    } catch (error) {
      debugPrint('Nie udało się zatrzymać pobrań (${error.runtimeType}).');
    }
    await _storage.clearCredentials();
    PlaybackSyncService.instance.onCredentialsChanged();

    if (!mounted) return;
    RestartWidget.restartAppFromRootNavigator();
  }

  Future<void> _openAdminPanel() async {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AdminWebViewScreen()),
      );
    }
  }

  Future<void> _saveStringSetting(
    String key,
    String value,
    Function(String) updateLocalState,
  ) async {
    await _storage.saveString(key, value);
    setState(() => updateLocalState(value));
  }
}
