// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get loginTitle => 'Połącz z Jellyfin';

  @override
  String get welcome => 'Witamy';

  @override
  String get loginSubTitle => 'Zaloguj się do swojego serwera Jellyfin.';

  @override
  String get serverAddress => 'Adres serwera';

  @override
  String get username => 'Użytkownik';

  @override
  String get password => 'Hasło';

  @override
  String get loginButton => 'Zaloguj';

  @override
  String get offlineFiles => 'Pobrane pliki (Offline)';

  @override
  String get libraryTitle => 'Twoje Biblioteki';

  @override
  String get categories => 'Kategorie';

  @override
  String get goToSeries => 'Przejdź do serialu';

  @override
  String get continueWatching => 'Kontynuuj oglądanie';

  @override
  String get settings => 'Ustawienia';

  @override
  String get language => 'Język';

  @override
  String get languageSelectionSubtitle => 'Wybierz język interfejsu aplikacji';

  @override
  String get languagePolish => 'Polski';

  @override
  String get languageEnglish => 'English';

  @override
  String get playback => 'Odtwarzanie';

  @override
  String get autoPlay => 'Autoodtwarzanie';

  @override
  String get autoPlaySub => 'Odtwarzaj automatycznie następny odcinek';

  @override
  String get backgroundPlayback => 'Odtwarzanie w tle';

  @override
  String get backgroundPlaybackSub =>
      'Kontynuuj odtwarzanie po zminimalizowaniu aplikacji';

  @override
  String get downloading => 'Pobieranie';

  @override
  String get downloadWifiOnly => 'Pobieraj tylko przez Wi-Fi';

  @override
  String get downloadWifiOnlySub =>
      'Zatrzymaj pobieranie przy użyciu danych komórkowych';

  @override
  String get useNativeDownloader => 'Powiadomienia pobierania';

  @override
  String get useNativeDownloaderSub =>
      'Pokazuj postęp pobierania w tle w powiadomieniu systemowym';

  @override
  String get privacy => 'Prywatność';

  @override
  String get managePrivacy => 'Zarządzaj prywatnością (RODO)';

  @override
  String get downloadFolder => 'Folder zapisu wideo';

  @override
  String get defaultFolder => 'Domyślny folder';

  @override
  String get searchHint => 'Szukaj w tej sekcji...';

  @override
  String get noDescription => 'Brak opisu';

  @override
  String get watchOnline => 'Oglądaj online';

  @override
  String get watchOffline => 'Oglądaj offline';

  @override
  String get downloadToMemory => 'Pobierz do pamięci';

  @override
  String get downloadAgain => 'Pobierz ponownie';

  @override
  String get downloadSeason => 'Pobierz sezon';

  @override
  String queueingEpisodes(Object count) {
    return 'Kolejkowanie $count odcinków';
  }

  @override
  String get allDownloaded => 'Wszystko już pobrane!';

  @override
  String deleteItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Usuń $count elementów',
      few: 'Usuń $count elementy',
      one: 'Usuń 1 element',
    );
    return '$_temp0';
  }

  @override
  String get deleteConfirm =>
      'Czy na pewno chcesz trwale usunąć zaznaczone treści?';

  @override
  String get cancel => 'Anuluj';

  @override
  String get delete => 'Usuń';

  @override
  String get noOfflineFiles => 'Brak pobranych treści';

  @override
  String get videoQuality => 'Jakość wideo';

  @override
  String get audioTrack => 'Ścieżka dźwiękowa';

  @override
  String get subtitles => 'Napisy';

  @override
  String get off => 'Wyłączone';

  @override
  String get playerError => 'Wystąpił błąd odtwarzania wideo';

  @override
  String get close => 'Zamknij';

  @override
  String get selectQuality => 'Wybierz jakość';

  @override
  String get selectQualitySeries => 'Wybierz jakość dla całego serialu';

  @override
  String selectQualitySeason(int number) {
    return 'Sezon $number - wybierz jakość';
  }

  @override
  String get supportCreatorTitle => 'Wsparcie Twórcy';

  @override
  String get supportCreatorBody1 =>
      'Aplikacja jest w 100% darmowa. Jeżeli jednak chcesz wesprzeć moją pracę i rozwój projektu, możesz włączyć małe, nieprzeszkadzające reklamy na dole ekranu.';

  @override
  String get supportCreatorBody2 =>
      'Jeśli wolisz aplikację całkowicie bez reklam – nie ma problemu! Kod Google Ads nie zostanie wtedy w ogóle załadowany.';

  @override
  String get supportCreatorAccept => 'Tak, chcę wspierać (Włącz reklamy)';

  @override
  String get supportCreatorDecline => 'Nie, dziękuję';

  @override
  String get supportCreatorAdsTitle => 'Wsparcie Twórcy (Reklamy)';

  @override
  String get supportCreatorAdsSubtitle =>
      'Wyświetlaj małe, nieprzeszkadzające reklamy, aby wesprzeć projekt.';

  @override
  String get managePrivacySubtitle =>
      'Zmień zgodę na wyświetlanie spersonalizowanych reklam';

  @override
  String get loadingPrivacyOptions => 'Ładowanie opcji prywatności...';

  @override
  String get toWatch => 'Do obejrzenia';

  @override
  String get lasttlyAdded => 'Ostatnio dodane';

  @override
  String get sdCardPermissionDenied =>
      'Brak uprawnień do zapisu na karcie SD. Zezwól w ustawieniach systemu.';

  @override
  String get storagePermissionDenied => 'Odmowa dostępu do pamięci.';

  @override
  String get downloadPathUpdated => 'Zaktualizowano ścieżkę pobierania.';

  @override
  String get privacySettingsUpdated =>
      'Ustawienia prywatności zostały zaktualizowane.';

  @override
  String get pickDownloadFolderTitle =>
      'Wybierz folder pobierania (np. na karcie SD)';

  @override
  String get logoutTooltip => 'Wyloguj';

  @override
  String get logoutConfirmTitle => 'Wylogować?';

  @override
  String get logoutConfirmContent =>
      'Będziesz musiał ponownie wpisać dane serwera.';

  @override
  String get logout => 'Wyloguj';

  @override
  String get restoreDefaultTooltip => 'Przywróć domyślny';

  @override
  String get concurrentDownloads => 'Jednoczesne pobierania';

  @override
  String get concurrentDownloadsSub => 'Ile plików pobierać naraz';

  @override
  String get administration => 'Administracja';

  @override
  String get serverPanel => 'Panel serwera';

  @override
  String get serverPanelSub =>
      'Otwórz ustawienia Jellyfin w przeglądarce wewnątrz aplikacji';

  @override
  String get enterServerAndUsername =>
      'Podaj adres serwera i nazwę użytkownika.';

  @override
  String get invalidLoginOrPassword => 'Błędny login lub hasło.';

  @override
  String connectionError(String url) {
    return 'Błąd połączenia: Nie można połączyć się z $url';
  }

  @override
  String get serverAddressHint => 'np. http://192.168.0.11:8096';

  @override
  String get loginAction => 'Zaloguj się';

  @override
  String get loadingPanel => 'Ładowanie panelu...';

  @override
  String get fromBeginning => 'Od początku (Online)';

  @override
  String get advancedTranscoding => 'Zaawansowane transkodowanie';

  @override
  String get hwAccelTitle => 'Akceleracja sprzętowa';

  @override
  String get hwAccelSub => 'Wymusza na serwerze konkretny dekoder';

  @override
  String get autoServer => 'Automat (Serwer)';

  @override
  String get cpuLimitTitle => 'Limit rdzeni CPU';

  @override
  String get cpuLimitSub => 'Ogranicza moc procesora serwera';

  @override
  String get autoNoLimit => 'Automat (Brak limitu)';

  @override
  String get core1 => '1 rdzeń';

  @override
  String get cores2 => '2 rdzenie';

  @override
  String get cores4 => '4 rdzenie';

  @override
  String get cores8 => '8 rdzeni';

  @override
  String get fpsLimitTitle => 'Limit FPS';

  @override
  String get fpsLimitSub => 'Wymusza zrzucanie nadmiarowych klatek';

  @override
  String get autoOriginal => 'Automat (Oryginał)';

  @override
  String get fps24 => '24 FPS (Kino)';

  @override
  String get fps30 => '30 FPS';

  @override
  String get fps60 => '60 FPS';

  @override
  String get audioQualityTitle => 'Jakość Audio';

  @override
  String get audioQualitySub => 'Bitrate ścieżki dźwiękowej';

  @override
  String get audio320 => '320 kbps (Wysoka)';

  @override
  String get audio192 => '192 kbps (Dobra)';

  @override
  String get audio128 => '128 kbps (Standard)';

  @override
  String get audio96 => '96 kbps (Niska)';

  @override
  String get favorites => 'Ulubione';

  @override
  String get addToFavorites => 'Dodaj do ulubionych';

  @override
  String get removeFromFavorites => 'Usuń z ulubionych';

  @override
  String get favoriteUpdateError => 'Nie udało się zaktualizować ulubionych.';

  @override
  String get markWatched => 'Oznacz jako obejrzane';

  @override
  String get markUnwatched => 'Oznacz jako nieobejrzane';

  @override
  String get watchedUpdateError => 'Nie udało się zmienić stanu obejrzenia.';

  @override
  String get libraryLoadError =>
      'Nie udało się wczytać biblioteki. Sprawdź połączenie z serwerem.';

  @override
  String get certificateTrustSaveError =>
      'Nie udało się zapisać ustawienia certyfikatu.';

  @override
  String get loginCertificateError =>
      'Certyfikat HTTPS serwera nie jest zaufany. Jeśli to Twój serwer z własnym certyfikatem, zaznacz „Zaufaj certyfikatowi HTTPS serwera”.';

  @override
  String get loginServerError =>
      'Serwer zwrócił nieoczekiwaną odpowiedź. Sprawdź adres serwera.';

  @override
  String get insecureHttpWarning =>
      'Ten adres używa nieszyfrowanego HTTP poza siecią lokalną. Hasło i token będą przesyłane jawnym tekstem. Użyj https://, jeśli serwer na to pozwala.';

  @override
  String get trustCertificateTitle => 'Zaufaj certyfikatowi HTTPS serwera';

  @override
  String get trustCertificateSub =>
      'Użyj tylko dla serwera z własnym lub niezaufanym certyfikatem.';

  @override
  String get credentialStorageError =>
      'Nie można odczytać zapisanych danych logowania. Twoje dane nie zostały usunięte. Spróbuj ponownie.';

  @override
  String get tryAgain => 'Spróbuj ponownie';

  @override
  String get serverUnreachable =>
      'Nie można połączyć się z serwerem. Sprawdź połączenie z internetem lub czy serwer działa. Pobrane pliki są dostępne offline.';

  @override
  String get failedDownloadTitle => 'Nieudane pobieranie';

  @override
  String failedDownloadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pobrań nie powiodło się.',
      few: '$count pobrania nie powiodły się.',
      one: '1 pobieranie nie powiodło się.',
    );
    return '$_temp0';
  }

  @override
  String get failedDownloadRetryQuestion => 'Czy chcesz ponowić pobieranie?';

  @override
  String get no => 'Nie';

  @override
  String get retry => 'Ponów';

  @override
  String get playerTlsVerify => 'Weryfikuj certyfikat TLS w odtwarzaczu';

  @override
  String get playerTlsVerifySub =>
      'Odtwarzacz sprawdza certyfikat HTTPS serwera (pomija serwery oznaczone jako zaufane). Wyłącz, jeśli odtwarzanie przez HTTPS przestało działać.';

  @override
  String get introSkipperSection => 'Pomijanie intro (Intro Skipper)';

  @override
  String get showSkipButton => 'Przycisk pomijania';

  @override
  String get showSkipButtonSub =>
      'Pokazuj „Pomiń intro” i podobne przyciski, gdy serwer zna segmenty odcinka (wtyczka Intro Skipper lub segmenty Jellyfin 10.10+)';

  @override
  String get autoSkipIntro => 'Automatycznie pomijaj intro i podsumowanie';

  @override
  String get autoSkipIntroSub => 'Przewija od razu, bez naciskania przycisku';

  @override
  String get autoSkipCredits => 'Automatycznie pomijaj napisy końcowe';

  @override
  String get autoSkipCreditsSub =>
      'Po napisach końcowych przechodzi do następnego odcinka, jeśli jest';

  @override
  String selectedCount(int count) {
    return 'Zaznaczono: $count';
  }

  @override
  String get searchDownloadsHint => 'Szukaj pobranych...';

  @override
  String get skipIntro => 'Pomiń intro';

  @override
  String get skipCredits => 'Pomiń napisy końcowe';

  @override
  String get skipRecap => 'Pomiń podsumowanie';

  @override
  String get skipPreview => 'Pomiń zapowiedź';

  @override
  String get skipCommercial => 'Pomiń reklamę';

  @override
  String get previousEpisode => 'Poprzedni odcinek';

  @override
  String get nextEpisode => 'Następny odcinek';

  @override
  String get serverPanelNoServer => 'Najpierw zaloguj się do serwera.';

  @override
  String unwantedSnoozedUntil(String date) {
    return 'do $date';
  }

  @override
  String get unwantedUntilNewEpisode => 'do nowego odcinka';

  @override
  String get unwantedSnoozed => 'Uśpiony';

  @override
  String get undo => 'Cofnij';

  @override
  String get unwantedError => 'Nie udało się zmienić listy. Spróbuj ponownie.';

  @override
  String unwantedWatchLaterAdded(String name) {
    return 'Dodano „$name” do „Na później”';
  }

  @override
  String unwantedWatchLaterRemoved(String name) {
    return 'Usunięto „$name” z „Na później”';
  }

  @override
  String unwantedMarked(String name) {
    return '„$name” → Nieulubione. Zniknie z list do oglądania.';
  }

  @override
  String unwantedRestored(String name) {
    return 'Przywrócono „$name”';
  }

  @override
  String unwantedSnoozeTitle(String name) {
    return 'Uśpij „$name”';
  }

  @override
  String get unwantedSnoozeHint =>
      'Uśpiony serial znika z „Następne” i wraca sam po wybranym czasie.';

  @override
  String get unwantedWake => 'Obudź teraz';

  @override
  String get unwantedSnoozeNewEpisode => 'Do nowego odcinka';

  @override
  String unwantedSnoozeDays(int days) {
    return 'Na $days dni';
  }

  @override
  String unwantedWoken(String name) {
    return 'Obudzono „$name”';
  }

  @override
  String unwantedSnoozedMessage(String name) {
    return 'Uśpiono „$name”';
  }

  @override
  String get unwantedWatchLater => 'Na później';

  @override
  String get unwantedSnooze => 'Uśpij';

  @override
  String get unwantedNotInterested => 'Nieulubione';

  @override
  String unwantedAppliesToSeries(String name) {
    return 'Dotyczy całego serialu „$name”';
  }

  @override
  String get unwantedSnoozedList => 'Uśpione';

  @override
  String get unwantedEmptyWatchLater =>
      'Lista „Na później” jest pusta. Dodaj film lub serial przyciskiem „Na później” na jego stronie.';

  @override
  String get unwantedEmptySnoozed =>
      'Nic nie śpi. Uśpij serial, żeby na jakiś czas zniknął z „Następne”.';

  @override
  String get unwantedEmptyUnwanted =>
      'Brak nieulubionych. Oznacz serial lub film kciukiem w dół na jego stronie.';

  @override
  String unwantedAddedOn(String date) {
    return 'Dodano $date';
  }

  @override
  String get unwantedRemoveWatchLater => 'Usuń z „Na później”';

  @override
  String get unwantedRestore => 'Przywróć';

  @override
  String get unwantedMyLists => 'Moje listy';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours godz. $minutes min';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String seasonEpisodeLabel(int season, int episode) {
    return 'Sezon $season · Odcinek $episode';
  }

  @override
  String seasonEpisodeShort(int season, int episode) {
    return 'S$season O$episode';
  }

  @override
  String endsAt(String time) {
    return 'Koniec o $time';
  }

  @override
  String timeLeft(String duration) {
    return 'Zostało $duration';
  }

  @override
  String subtitleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count napisów',
      many: '$count napisów',
      few: '$count napisy',
      one: '1 napisy',
    );
    return '$_temp0';
  }

  @override
  String get watched => 'Obejrzane';

  @override
  String get downloadedBadge => 'Pobrane';

  @override
  String get showMore => 'Pokaż więcej';

  @override
  String get showLess => 'Pokaż mniej';

  @override
  String get directedBy => 'Reżyseria';

  @override
  String get writtenBy => 'Scenariusz';

  @override
  String get studio => 'Studio';

  @override
  String get cast => 'Obsada';

  @override
  String get chapters => 'Rozdziały';

  @override
  String chapterNumber(int number) {
    return 'Rozdział $number';
  }

  @override
  String get moreEpisodes => 'Inne odcinki';

  @override
  String get technicalDetails => 'Informacje techniczne';

  @override
  String get mediaContainer => 'Kontener';

  @override
  String get mediaFileSize => 'Rozmiar';

  @override
  String get mediaBitrate => 'Bitrate';

  @override
  String get mediaVideo => 'Wideo';

  @override
  String get mediaAudio => 'Dźwięk';

  @override
  String get cancelDownload => 'Anuluj pobieranie';

  @override
  String get favoritesAll => 'Wszystkie';

  @override
  String get favoritesMovies => 'Filmy';

  @override
  String get favoritesSeries => 'Seriale';

  @override
  String get favoritesEpisodes => 'Odcinki';

  @override
  String get sortBy => 'Sortuj';

  @override
  String get sortName => 'Nazwa';

  @override
  String get sortDateAdded => 'Ostatnio dodane';

  @override
  String get sortPremiere => 'Data premiery';

  @override
  String get sortRating => 'Ocena';

  @override
  String get noFavorites => 'Brak ulubionych';

  @override
  String get noFavoritesHint =>
      'Dotknij serca na filmie, serialu lub odcinku, żeby go tu dodać.';

  @override
  String get noFavoritesInFilter => 'Brak ulubionych w tej kategorii.';

  @override
  String get loadError => 'Nie udało się wczytać danych z serwera.';

  @override
  String get search => 'Szukaj';

  @override
  String get searchEverywhereHint => 'Szukaj filmów, seriali i odcinków';

  @override
  String noSearchResults(String query) {
    return 'Nic nie znaleziono dla „$query”';
  }

  @override
  String get searchStartTyping => 'Wpisz co najmniej 2 znaki.';

  @override
  String episodeOf(String series, int season, int episode) {
    return '$series · S$season O$episode';
  }

  @override
  String get unwantedSnoozeOneDay => 'Na 1 dzień';

  @override
  String get unwantedSnoozeWeek => 'Na tydzień';

  @override
  String get unwantedSnoozeTwoWeeks => 'Na 2 tygodnie';

  @override
  String get unwantedSnoozeMonth => 'Na miesiąc';

  @override
  String get unwantedSnoozeThreeMonths => 'Na 3 miesiące';

  @override
  String get noEpisodes => 'Ten serial nie ma jeszcze odcinków.';

  @override
  String get specials => 'Odcinki specjalne';

  @override
  String seasonNumber(int number) {
    return 'Sezon $number';
  }

  @override
  String get download => 'Pobierz';

  @override
  String get playNext => 'Odtwórz';

  @override
  String episodeNumber(int number) {
    return 'Odcinek $number';
  }

  @override
  String searchInLibraryHint(String library) {
    return 'Szukaj w: $library';
  }

  @override
  String downloadsInProgress(int count) {
    return 'Pobieranie ($count)';
  }

  @override
  String get selectAll => 'Zaznacz wszystko';

  @override
  String get selectItems => 'Zaznacz do usunięcia';

  @override
  String get refresh => 'Odśwież';

  @override
  String get noOfflineFilesHint =>
      'Na stronie filmu lub odcinka wybierz „Pobierz do pamięci”, a na stronie serialu „Pobierz sezon”.';

  @override
  String get general => 'Ogólne';
}
