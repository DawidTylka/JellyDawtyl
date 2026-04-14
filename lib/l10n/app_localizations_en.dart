// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get loginTitle => 'Connect to Jellyfin';

  @override
  String get welcome => 'Welcome';

  @override
  String get loginSubTitle => 'Log in to your Jellyfin server.';

  @override
  String get serverAddress => 'Server Address';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get loginButton => 'Login';

  @override
  String get offlineFiles => 'Downloaded Files (Offline)';

  @override
  String get libraryTitle => 'Your Libraries';

  @override
  String get categories => 'Categories';

  @override
  String get continueWatching => 'Continue Watching';

  @override
  String get settings => 'Settings';

  @override
  String get playback => 'Playback';

  @override
  String get autoPlay => 'Autoplay';

  @override
  String get autoPlaySub => 'Automatically play the next episode';

  @override
  String get downloading => 'Downloading';

  @override
  String get downloadWifiOnly => 'Download on Wi-Fi only';

  @override
  String get downloadWifiOnlySub => 'Stop downloading when using mobile data';

  @override
  String get useNativeDownloader => 'Use Android Manager';

  @override
  String get useNativeDownloaderSub =>
      'Download in background via system manager';

  @override
  String get privacy => 'Privacy';

  @override
  String get managePrivacy => 'Manage Privacy (GDPR)';

  @override
  String get downloadFolder => 'Video Storage Folder';

  @override
  String get defaultFolder => 'Default folder';

  @override
  String get searchHint => 'Search in this section...';

  @override
  String get noDescription => 'No description';

  @override
  String get watchOnline => 'WATCH ONLINE';

  @override
  String get watchOffline => 'WATCH OFFLINE';

  @override
  String get downloadToMemory => 'DOWNLOAD TO DEVICE';

  @override
  String get downloadAgain => 'DOWNLOAD AGAIN';

  @override
  String get downloadSeason => 'Download Season';

  @override
  String queueingEpisodes(Object count) {
    return 'Queueing $count episodes';
  }

  @override
  String get allDownloaded => 'Everything already downloaded!';

  @override
  String get deleteItems => 'Delete items';

  @override
  String get deleteConfirm =>
      'Are you sure you want to permanently delete selected content?';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get noOfflineFiles => 'No downloaded content';

  @override
  String get videoQuality => 'Video Quality';

  @override
  String get audioTrack => 'Audio Track';

  @override
  String get subtitles => 'Subtitles';

  @override
  String get off => 'Off';

  @override
  String get playerError => 'An error occurred while playing video';

  @override
  String get close => 'Close';

  @override
  String get selectQuality => 'Select quality';

  @override
  String get selectQualitySeries => 'Select quality for the entire series';

  @override
  String selectQualitySeason(int number) {
    return 'Season $number - select quality';
  }

  @override
  String get supportCreatorTitle => 'Support the Creator';

  @override
  String get supportCreatorBody1 =>
      'The app is 100% free. However, if you\'d like to support my work and the project\'s development, you can enable small, non-intrusive ads at the bottom of the screen.';

  @override
  String get supportCreatorBody2 =>
      'If you prefer a completely ad-free experience – no problem! The Google Ads code won\'t even be loaded.';

  @override
  String get supportCreatorAccept => 'Yes, I want to support (Enable ads)';

  @override
  String get supportCreatorDecline => 'No, thank you';

  @override
  String get supportCreatorAdsTitle => 'Creator Support (Ads)';

  @override
  String get supportCreatorAdsSubtitle =>
      'Display small, non-intrusive ads to support the project.';

  @override
  String get managePrivacySubtitle =>
      'Change consent for displaying personalized ads';

  @override
  String get loadingPrivacyOptions => 'Loading privacy options...';

  @override
  String get toWatch => 'To Watch';

  @override
  String get lasttlyAdded => 'Lastly Added';

  @override
  String get sdCardPermissionDenied =>
      'No permission to write to SD card. Allow in system settings.';

  @override
  String get storagePermissionDenied => 'Storage access denied.';

  @override
  String get downloadPathUpdated => 'Download path updated.';

  @override
  String get privacySettingsUpdated => 'Privacy settings have been updated.';

  @override
  String get pickDownloadFolderTitle =>
      'Select download folder (e.g. on SD card)';

  @override
  String get logoutTooltip => 'Log out';

  @override
  String get logoutConfirmTitle => 'Log out?';

  @override
  String get logoutConfirmContent =>
      'You will need to re-enter your server details.';

  @override
  String get logout => 'Log out';

  @override
  String get restoreDefaultTooltip => 'Restore default';

  @override
  String get concurrentDownloads => 'Concurrent downloads';

  @override
  String get concurrentDownloadsSub => 'How many files to download at once';

  @override
  String get administration => 'Administration';

  @override
  String get serverPanel => 'Server panel';

  @override
  String get serverPanelSub => 'Open Jellyfin settings in the in-app browser';

  @override
  String get enterServerAndUsername =>
      'Please enter the server address and username.';

  @override
  String get invalidLoginOrPassword => 'Invalid username or password.';

  @override
  String connectionError(String url) {
    return 'Connection error: Cannot connect to $url';
  }

  @override
  String get serverAddressHint => 'e.g. http://192.168.0.11:8096';

  @override
  String get loginAction => 'Log in';

  @override
  String get loadingPanel => 'Loading panel...';

  @override
  String get fromBeginning => 'From beginning (Online)';

  @override
  String get advancedTranscoding => 'Advanced Transcoding';

  @override
  String get hwAccelTitle => 'Hardware Acceleration';

  @override
  String get hwAccelSub => 'Forces the server to use a specific decoder';

  @override
  String get autoServer => 'Auto (Server)';

  @override
  String get cpuLimitTitle => 'CPU Core Limit';

  @override
  String get cpuLimitSub => 'Limits server CPU processing power';

  @override
  String get autoNoLimit => 'Auto (No limit)';

  @override
  String get core1 => '1 core';

  @override
  String get cores2 => '2 cores';

  @override
  String get cores4 => '4 cores';

  @override
  String get cores8 => '8 cores';

  @override
  String get fpsLimitTitle => 'FPS Limit';

  @override
  String get fpsLimitSub => 'Forces dropping excess frames';

  @override
  String get autoOriginal => 'Auto (Original)';

  @override
  String get fps24 => '24 FPS (Cinematic)';

  @override
  String get fps30 => '30 FPS';

  @override
  String get fps60 => '60 FPS';

  @override
  String get audioQualityTitle => 'Audio Quality';

  @override
  String get audioQualitySub => 'Audio track bitrate';

  @override
  String get audio320 => '320 kbps (High)';

  @override
  String get audio192 => '192 kbps (Good)';

  @override
  String get audio128 => '128 kbps (Standard)';

  @override
  String get audio96 => '96 kbps (Low)';

  @override
  String get favorites => 'Favorites';
}
