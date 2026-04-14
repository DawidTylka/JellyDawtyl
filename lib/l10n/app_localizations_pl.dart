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
  String get continueWatching => 'Kontynuuj oglądanie';

  @override
  String get settings => 'Ustawienia';

  @override
  String get playback => 'Odtwarzanie';

  @override
  String get autoPlay => 'Autoodtwarzanie';

  @override
  String get autoPlaySub => 'Odtwarzaj automatycznie następny odcinek';

  @override
  String get downloading => 'Pobieranie';

  @override
  String get downloadWifiOnly => 'Pobieraj tylko przez Wi-Fi';

  @override
  String get downloadWifiOnlySub =>
      'Zatrzymaj pobieranie przy użyciu danych komórkowych';

  @override
  String get useNativeDownloader => 'Użyj menedżera Android';

  @override
  String get useNativeDownloaderSub => 'Pobieraj w tle przez system';

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
  String get watchOnline => 'OGLĄDAJ ONLINE';

  @override
  String get watchOffline => 'OGLĄDAJ OFFLINE';

  @override
  String get downloadToMemory => 'POBIERZ DO PAMIĘCI';

  @override
  String get downloadAgain => 'POBIERZ PONOWNIE';

  @override
  String get downloadSeason => 'Pobierz sezon';

  @override
  String queueingEpisodes(Object count) {
    return 'Kolejkowanie $count odcinków';
  }

  @override
  String get allDownloaded => 'Wszystko już pobrane!';

  @override
  String get deleteItems => 'Usuń elementy';

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
}
