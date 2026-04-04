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
  String selectQualitySeason(Object number) {
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
}
