import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/storage_service.dart';
import '../../widgets/ad_banner_widget.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../main.dart';
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
  bool _downloadWifiOnly = true;
  bool _useNativeDownloader = false;
  bool _showAds = false;
  int _maxConcurrentValue = 3;

  String? _customDownloadPath;

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
    final nativeDownloader = await _storage.getSetting(
      'setting_native_downloader',
      defaultValue: false,
    );

    final maxConcurrent = await _storage.getInt(
      'setting_max_concurrent_downloads',
      defaultValue: 1,
    );

    final hwAccel = await _storage.getString('setting_hw_accel') ?? 'auto';
    final cpuLimit = await _storage.getString('setting_cpu_limit') ?? 'auto';
    final maxFps = await _storage.getString('setting_max_fps') ?? 'auto';
    final audioBitrate = await _storage.getString('setting_audio_bitrate') ?? 'auto';



    final customPath = await _storage.getString('setting_download_path');
    final adsChoice = await _storage.getString('setting_ads_choice');

    setState(() {
      _autoPlayNext = autoPlay;
      _downloadWifiOnly = wifiOnly;
      _useNativeDownloader = nativeDownloader;
      _maxConcurrentValue = maxConcurrent;
      _customDownloadPath = customPath;
      _showAds = (adsChoice == 'yes');
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
      else if (await Permission.storage.isDenied) {
        final status = await Permission.storage.request();
        if (status.isDenied) {
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.downloadPathUpdated)),
        );
      }
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
                      child: Text(l10n.logout, style: TextStyle(color: Colors.red)),
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
                        setState(() => _maxConcurrentValue = val);
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
                
                _buildSectionTitle(l10n.advancedTranscoding),
                
                ListTile(
                  title: Text(l10n.hwAccelTitle),
                  subtitle: Text(l10n.hwAccelSub),
                  trailing: DropdownButton<String>(
                    value: _hwAccelValue,
                    dropdownColor: const Color(0xFF1C1C1E),
                    underline: const SizedBox(),
                    style: const TextStyle(color: Colors.white),
                    items: [
                      DropdownMenuItem(value: 'auto', child: Text(l10n.autoServer)),
                      const DropdownMenuItem(value: 'Vaapi', child: Text("VAAPI (Linux/Intel)")),
                      const DropdownMenuItem(value: 'Nvenc', child: Text("NVENC (Nvidia)")),
                      const DropdownMenuItem(value: 'Qsv', child: Text("QSV (Intel)")),
                      const DropdownMenuItem(value: 'VideoToolbox', child: Text("VideoToolbox (Mac)")),
                    ],
                    onChanged: (val) => _saveStringSetting('setting_hw_accel', val!, (v) => _hwAccelValue = v),
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
                      DropdownMenuItem(value: 'auto', child: Text(l10n.autoNoLimit)),
                      DropdownMenuItem(value: '1', child: Text(l10n.core1)),
                      DropdownMenuItem(value: '2', child: Text(l10n.cores2)),
                      DropdownMenuItem(value: '4', child: Text(l10n.cores4)),
                      DropdownMenuItem(value: '8', child: Text(l10n.cores8)),
                    ],
                    onChanged: (val) => _saveStringSetting('setting_cpu_limit', val!, (v) => _cpuLimitValue = v),
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
                      DropdownMenuItem(value: 'auto', child: Text(l10n.autoOriginal)),
                      DropdownMenuItem(value: '24', child: Text(l10n.fps24)),
                      DropdownMenuItem(value: '30', child: Text(l10n.fps30)),
                      DropdownMenuItem(value: '60', child: Text(l10n.fps60)),
                    ],
                    onChanged: (val) => _saveStringSetting('setting_max_fps', val!, (v) => _maxFpsValue = v),
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
                      DropdownMenuItem(value: 'auto', child: Text(l10n.autoOriginal)),
                      DropdownMenuItem(value: '320000', child: Text(l10n.audio320)),
                      DropdownMenuItem(value: '192000', child: Text(l10n.audio192)),
                      DropdownMenuItem(value: '128000', child: Text(l10n.audio128)),
                      DropdownMenuItem(value: '96000', child: Text(l10n.audio96)),
                    ],
                    onChanged: (val) => _saveStringSetting('setting_audio_bitrate', val!, (v) => _audioBitrateValue = v),
                  ),
                ),

                const Divider(height: 32, color: Colors.white24),

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

                
                _buildSectionTitle(l10n.administration),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_rounded, color: Colors.orangeAccent),
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

    final String? testDeviceId = dotenv.env['ADMOB_TEST_DEVICE_ID'];

    ConsentRequestParameters params = ConsentRequestParameters(
      consentDebugSettings: ConsentDebugSettings(
        debugGeography: DebugGeography.debugGeographyEea,
        testIdentifiers: testDeviceId != null && testDeviceId.isNotEmpty
            ? [testDeviceId]
            : [],
      ),
    );

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          ConsentForm.loadConsentForm(
            (ConsentForm consentForm) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              consentForm.show((FormError? formError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n.privacySettingsUpdated,
                    ),
                  ),
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

  Future<void> _logout() async {
    await _storage.saveString('token', '');
    await _storage.saveString('userId', '');
    
    if (mounted) {
      RestartWidget.restartApp(context);
    }
  }

  Future<void> _openAdminPanel() async {

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminWebViewScreen(),
        ),
      );
    }
  }

  Future<void> _saveStringSetting(String key, String value, Function(String) updateLocalState) async {
    await _storage.saveString(key, value);
    setState(() => updateLocalState(value));
  }
}
