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
  String get goToSeries => 'Go to series';

  @override
  String get continueWatching => 'Continue Watching';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get languageSelectionSubtitle => 'Choose the app interface language';

  @override
  String get languagePolish => 'Polski';

  @override
  String get languageEnglish => 'English';

  @override
  String get playback => 'Playback';

  @override
  String get autoPlay => 'Autoplay';

  @override
  String get autoPlaySub => 'Automatically play the next episode';

  @override
  String get backgroundPlayback => 'Background playback';

  @override
  String get backgroundPlaybackSub => 'Keep playing when the app is minimized';

  @override
  String get downloading => 'Downloading';

  @override
  String get downloadWifiOnly => 'Download on Wi-Fi only';

  @override
  String get downloadWifiOnlySub => 'Stop downloading when using mobile data';

  @override
  String get useNativeDownloader => 'Download notifications';

  @override
  String get useNativeDownloaderSub =>
      'Show background download progress in a system notification';

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
  String get watchOnline => 'Watch online';

  @override
  String get watchOffline => 'Watch offline';

  @override
  String get downloadToMemory => 'Download to device';

  @override
  String get downloadAgain => 'Download again';

  @override
  String get downloadSeason => 'Download Season';

  @override
  String queueingEpisodes(Object count) {
    return 'Queueing $count episodes';
  }

  @override
  String get allDownloaded => 'Everything already downloaded!';

  @override
  String deleteItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count items',
      one: 'Delete 1 item',
    );
    return '$_temp0';
  }

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

  @override
  String get addToFavorites => 'Add to favorites';

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get favoriteUpdateError => 'Could not update favorites.';

  @override
  String get markWatched => 'Mark as watched';

  @override
  String get markUnwatched => 'Mark as unwatched';

  @override
  String get watchedUpdateError => 'Could not update watched status.';

  @override
  String get libraryLoadError =>
      'Could not load the library. Check the connection to the server.';

  @override
  String get certificateTrustSaveError =>
      'Could not save the certificate setting.';

  @override
  String get loginCertificateError =>
      'The server\'s HTTPS certificate is not trusted. If this is your server with its own certificate, tick “Trust the server\'s HTTPS certificate”.';

  @override
  String get loginServerError =>
      'The server returned an unexpected response. Check the server address.';

  @override
  String get insecureHttpWarning =>
      'This address uses unencrypted HTTP outside the local network. Your password and token will be sent in plain text. Use https:// if the server supports it.';

  @override
  String get trustCertificateTitle => 'Trust the server\'s HTTPS certificate';

  @override
  String get trustCertificateSub =>
      'Use only for a server with a self-signed or untrusted certificate.';

  @override
  String get credentialStorageError =>
      'The saved login data cannot be read. Your data has not been deleted. Please try again.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get serverUnreachable =>
      'Cannot connect to the server. Check your internet connection or whether the server is running. Downloaded files are available offline.';

  @override
  String get failedDownloadTitle => 'Download failed';

  @override
  String failedDownloadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloads failed.',
      one: '1 download failed.',
    );
    return '$_temp0';
  }

  @override
  String get failedDownloadRetryQuestion => 'Do you want to retry?';

  @override
  String get no => 'No';

  @override
  String get retry => 'Retry';

  @override
  String get playerTlsVerify => 'Verify TLS certificate in the player';

  @override
  String get playerTlsVerifySub =>
      'The player checks the server\'s HTTPS certificate (servers marked as trusted are skipped). Turn off if HTTPS playback stops working.';

  @override
  String get introSkipperSection => 'Skipping intros (Intro Skipper)';

  @override
  String get showSkipButton => 'Skip button';

  @override
  String get showSkipButtonSub =>
      'Show “Skip intro” and similar buttons when the server knows the episode\'s segments (Intro Skipper plugin or Jellyfin 10.10+ segments)';

  @override
  String get autoSkipIntro => 'Automatically skip intro and recap';

  @override
  String get autoSkipIntroSub =>
      'Skips right away, without pressing the button';

  @override
  String get autoSkipCredits => 'Automatically skip credits';

  @override
  String get autoSkipCreditsSub =>
      'After the credits, moves on to the next episode if there is one';

  @override
  String selectedCount(int count) {
    return 'Selected: $count';
  }

  @override
  String get searchDownloadsHint => 'Search downloads...';

  @override
  String get skipIntro => 'Skip intro';

  @override
  String get skipCredits => 'Skip credits';

  @override
  String get skipRecap => 'Skip recap';

  @override
  String get skipPreview => 'Skip preview';

  @override
  String get skipCommercial => 'Skip commercial';

  @override
  String get previousEpisode => 'Previous episode';

  @override
  String get nextEpisode => 'Next episode';

  @override
  String get serverPanelNoServer => 'Log in to a server first.';

  @override
  String unwantedSnoozedUntil(String date) {
    return 'until $date';
  }

  @override
  String get unwantedUntilNewEpisode => 'until a new episode';

  @override
  String get unwantedSnoozed => 'Snoozed';

  @override
  String get undo => 'Undo';

  @override
  String get unwantedError => 'Could not update the list. Try again.';

  @override
  String unwantedWatchLaterAdded(String name) {
    return 'Added “$name” to Watch later';
  }

  @override
  String unwantedWatchLaterRemoved(String name) {
    return 'Removed “$name” from Watch later';
  }

  @override
  String unwantedMarked(String name) {
    return '“$name” marked Not interested. It will disappear from watch lists.';
  }

  @override
  String unwantedRestored(String name) {
    return 'Restored “$name”';
  }

  @override
  String unwantedSnoozeTitle(String name) {
    return 'Snooze “$name”';
  }

  @override
  String get unwantedSnoozeHint =>
      'A snoozed series leaves Next up and comes back on its own after the chosen time.';

  @override
  String get unwantedWake => 'Wake now';

  @override
  String get unwantedSnoozeNewEpisode => 'Until a new episode';

  @override
  String unwantedSnoozeDays(int days) {
    return 'For $days days';
  }

  @override
  String unwantedWoken(String name) {
    return 'Woke “$name”';
  }

  @override
  String unwantedSnoozedMessage(String name) {
    return 'Snoozed “$name”';
  }

  @override
  String get unwantedWatchLater => 'Watch later';

  @override
  String get unwantedSnooze => 'Snooze';

  @override
  String get unwantedNotInterested => 'Not interested';

  @override
  String unwantedAppliesToSeries(String name) {
    return 'Applies to the whole series “$name”';
  }

  @override
  String get unwantedSnoozedList => 'Snoozed';

  @override
  String get unwantedEmptyWatchLater =>
      'Watch later is empty. Add a movie or series with the Watch later button on its page.';

  @override
  String get unwantedEmptySnoozed =>
      'Nothing is snoozed. Snooze a series to hide it from Next up for a while.';

  @override
  String get unwantedEmptyUnwanted =>
      'Nothing here. Mark a series or movie with the thumbs down on its page.';

  @override
  String unwantedAddedOn(String date) {
    return 'Added $date';
  }

  @override
  String get unwantedRemoveWatchLater => 'Remove from Watch later';

  @override
  String get unwantedRestore => 'Restore';

  @override
  String get unwantedMyLists => 'My lists';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String seasonEpisodeLabel(int season, int episode) {
    return 'Season $season · Episode $episode';
  }

  @override
  String seasonEpisodeShort(int season, int episode) {
    return 'S$season E$episode';
  }

  @override
  String endsAt(String time) {
    return 'Ends at $time';
  }

  @override
  String timeLeft(String duration) {
    return '$duration left';
  }

  @override
  String subtitleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subtitles',
      one: '1 subtitle',
    );
    return '$_temp0';
  }

  @override
  String get watched => 'Watched';

  @override
  String get downloadedBadge => 'Downloaded';

  @override
  String get showMore => 'Show more';

  @override
  String get showLess => 'Show less';

  @override
  String get directedBy => 'Directed by';

  @override
  String get writtenBy => 'Written by';

  @override
  String get studio => 'Studio';

  @override
  String get cast => 'Cast';

  @override
  String get chapters => 'Chapters';

  @override
  String chapterNumber(int number) {
    return 'Chapter $number';
  }

  @override
  String get moreEpisodes => 'More episodes';

  @override
  String get technicalDetails => 'Technical details';

  @override
  String get mediaContainer => 'Container';

  @override
  String get mediaFileSize => 'Size';

  @override
  String get mediaBitrate => 'Bitrate';

  @override
  String get mediaVideo => 'Video';

  @override
  String get mediaAudio => 'Audio';

  @override
  String get cancelDownload => 'Cancel download';

  @override
  String get favoritesAll => 'All';

  @override
  String get favoritesMovies => 'Movies';

  @override
  String get favoritesSeries => 'Series';

  @override
  String get favoritesEpisodes => 'Episodes';

  @override
  String get sortBy => 'Sort';

  @override
  String get sortName => 'Name';

  @override
  String get sortDateAdded => 'Recently added';

  @override
  String get sortPremiere => 'Release date';

  @override
  String get sortRating => 'Rating';

  @override
  String get noFavorites => 'No favorites yet';

  @override
  String get noFavoritesHint =>
      'Tap the heart on a movie, series or episode to add it here.';

  @override
  String get noFavoritesInFilter => 'No favorites in this category.';

  @override
  String get loadError => 'Could not load data from the server.';

  @override
  String get search => 'Search';

  @override
  String get searchEverywhereHint => 'Search movies, series and episodes';

  @override
  String noSearchResults(String query) {
    return 'Nothing found for “$query”';
  }

  @override
  String get searchStartTyping => 'Type at least 2 characters.';

  @override
  String episodeOf(String series, int season, int episode) {
    return '$series · S$season E$episode';
  }

  @override
  String get unwantedSnoozeOneDay => 'For 1 day';

  @override
  String get unwantedSnoozeWeek => 'For a week';

  @override
  String get unwantedSnoozeTwoWeeks => 'For 2 weeks';

  @override
  String get unwantedSnoozeMonth => 'For a month';

  @override
  String get unwantedSnoozeThreeMonths => 'For 3 months';

  @override
  String get noEpisodes => 'This series has no episodes yet.';

  @override
  String get specials => 'Specials';

  @override
  String seasonNumber(int number) {
    return 'Season $number';
  }

  @override
  String get download => 'Download';

  @override
  String get playNext => 'Play';

  @override
  String episodeNumber(int number) {
    return 'Episode $number';
  }

  @override
  String searchInLibraryHint(String library) {
    return 'Search in $library';
  }

  @override
  String downloadsInProgress(int count) {
    return 'Downloading ($count)';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get selectItems => 'Select to delete';

  @override
  String get refresh => 'Refresh';

  @override
  String get noOfflineFilesHint =>
      'Use “Download” on a movie or episode page, or “Download season” on a series page.';

  @override
  String get general => 'General';
}
