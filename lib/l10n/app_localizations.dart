import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pl'),
  ];

  /// No description provided for @loginTitle.
  ///
  /// In pl, this message translates to:
  /// **'Połącz z Jellyfin'**
  String get loginTitle;

  /// No description provided for @welcome.
  ///
  /// In pl, this message translates to:
  /// **'Witamy'**
  String get welcome;

  /// No description provided for @loginSubTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zaloguj się do swojego serwera Jellyfin.'**
  String get loginSubTitle;

  /// No description provided for @serverAddress.
  ///
  /// In pl, this message translates to:
  /// **'Adres serwera'**
  String get serverAddress;

  /// No description provided for @username.
  ///
  /// In pl, this message translates to:
  /// **'Użytkownik'**
  String get username;

  /// No description provided for @password.
  ///
  /// In pl, this message translates to:
  /// **'Hasło'**
  String get password;

  /// No description provided for @loginButton.
  ///
  /// In pl, this message translates to:
  /// **'Zaloguj'**
  String get loginButton;

  /// No description provided for @offlineFiles.
  ///
  /// In pl, this message translates to:
  /// **'Pobrane pliki (Offline)'**
  String get offlineFiles;

  /// No description provided for @libraryTitle.
  ///
  /// In pl, this message translates to:
  /// **'Twoje Biblioteki'**
  String get libraryTitle;

  /// No description provided for @categories.
  ///
  /// In pl, this message translates to:
  /// **'Kategorie'**
  String get categories;

  /// No description provided for @goToSeries.
  ///
  /// In pl, this message translates to:
  /// **'Przejdź do serialu'**
  String get goToSeries;

  /// No description provided for @continueWatching.
  ///
  /// In pl, this message translates to:
  /// **'Kontynuuj oglądanie'**
  String get continueWatching;

  /// No description provided for @settings.
  ///
  /// In pl, this message translates to:
  /// **'Ustawienia'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In pl, this message translates to:
  /// **'Język'**
  String get language;

  /// No description provided for @languageSelectionSubtitle.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz język interfejsu aplikacji'**
  String get languageSelectionSubtitle;

  /// No description provided for @languagePolish.
  ///
  /// In pl, this message translates to:
  /// **'Polski'**
  String get languagePolish;

  /// No description provided for @languageEnglish.
  ///
  /// In pl, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @playback.
  ///
  /// In pl, this message translates to:
  /// **'Odtwarzanie'**
  String get playback;

  /// No description provided for @autoPlay.
  ///
  /// In pl, this message translates to:
  /// **'Autoodtwarzanie'**
  String get autoPlay;

  /// No description provided for @autoPlaySub.
  ///
  /// In pl, this message translates to:
  /// **'Odtwarzaj automatycznie następny odcinek'**
  String get autoPlaySub;

  /// No description provided for @backgroundPlayback.
  ///
  /// In pl, this message translates to:
  /// **'Odtwarzanie w tle'**
  String get backgroundPlayback;

  /// No description provided for @backgroundPlaybackSub.
  ///
  /// In pl, this message translates to:
  /// **'Kontynuuj odtwarzanie po zminimalizowaniu aplikacji'**
  String get backgroundPlaybackSub;

  /// No description provided for @downloading.
  ///
  /// In pl, this message translates to:
  /// **'Pobieranie'**
  String get downloading;

  /// No description provided for @downloadWifiOnly.
  ///
  /// In pl, this message translates to:
  /// **'Pobieraj tylko przez Wi-Fi'**
  String get downloadWifiOnly;

  /// No description provided for @downloadWifiOnlySub.
  ///
  /// In pl, this message translates to:
  /// **'Zatrzymaj pobieranie przy użyciu danych komórkowych'**
  String get downloadWifiOnlySub;

  /// No description provided for @useNativeDownloader.
  ///
  /// In pl, this message translates to:
  /// **'Powiadomienia pobierania'**
  String get useNativeDownloader;

  /// No description provided for @useNativeDownloaderSub.
  ///
  /// In pl, this message translates to:
  /// **'Pokazuj postęp pobierania w tle w powiadomieniu systemowym'**
  String get useNativeDownloaderSub;

  /// No description provided for @privacy.
  ///
  /// In pl, this message translates to:
  /// **'Prywatność'**
  String get privacy;

  /// No description provided for @managePrivacy.
  ///
  /// In pl, this message translates to:
  /// **'Zarządzaj prywatnością (RODO)'**
  String get managePrivacy;

  /// No description provided for @downloadFolder.
  ///
  /// In pl, this message translates to:
  /// **'Folder zapisu wideo'**
  String get downloadFolder;

  /// No description provided for @defaultFolder.
  ///
  /// In pl, this message translates to:
  /// **'Domyślny folder'**
  String get defaultFolder;

  /// No description provided for @searchHint.
  ///
  /// In pl, this message translates to:
  /// **'Szukaj w tej sekcji...'**
  String get searchHint;

  /// No description provided for @noDescription.
  ///
  /// In pl, this message translates to:
  /// **'Brak opisu'**
  String get noDescription;

  /// No description provided for @watchOnline.
  ///
  /// In pl, this message translates to:
  /// **'Oglądaj online'**
  String get watchOnline;

  /// No description provided for @watchOffline.
  ///
  /// In pl, this message translates to:
  /// **'Oglądaj offline'**
  String get watchOffline;

  /// No description provided for @downloadToMemory.
  ///
  /// In pl, this message translates to:
  /// **'Pobierz do pamięci'**
  String get downloadToMemory;

  /// No description provided for @downloadAgain.
  ///
  /// In pl, this message translates to:
  /// **'Pobierz ponownie'**
  String get downloadAgain;

  /// No description provided for @downloadSeason.
  ///
  /// In pl, this message translates to:
  /// **'Pobierz sezon'**
  String get downloadSeason;

  /// No description provided for @queueingEpisodes.
  ///
  /// In pl, this message translates to:
  /// **'Kolejkowanie {count} odcinków'**
  String queueingEpisodes(Object count);

  /// No description provided for @allDownloaded.
  ///
  /// In pl, this message translates to:
  /// **'Wszystko już pobrane!'**
  String get allDownloaded;

  /// No description provided for @deleteItems.
  ///
  /// In pl, this message translates to:
  /// **'{count, plural, =1{Usuń 1 element} few{Usuń {count} elementy} other{Usuń {count} elementów}}'**
  String deleteItems(int count);

  /// No description provided for @deleteConfirm.
  ///
  /// In pl, this message translates to:
  /// **'Czy na pewno chcesz trwale usunąć zaznaczone treści?'**
  String get deleteConfirm;

  /// No description provided for @cancel.
  ///
  /// In pl, this message translates to:
  /// **'Anuluj'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In pl, this message translates to:
  /// **'Usuń'**
  String get delete;

  /// No description provided for @noOfflineFiles.
  ///
  /// In pl, this message translates to:
  /// **'Brak pobranych treści'**
  String get noOfflineFiles;

  /// No description provided for @videoQuality.
  ///
  /// In pl, this message translates to:
  /// **'Jakość wideo'**
  String get videoQuality;

  /// No description provided for @audioTrack.
  ///
  /// In pl, this message translates to:
  /// **'Ścieżka dźwiękowa'**
  String get audioTrack;

  /// No description provided for @subtitles.
  ///
  /// In pl, this message translates to:
  /// **'Napisy'**
  String get subtitles;

  /// No description provided for @off.
  ///
  /// In pl, this message translates to:
  /// **'Wyłączone'**
  String get off;

  /// No description provided for @playerError.
  ///
  /// In pl, this message translates to:
  /// **'Wystąpił błąd odtwarzania wideo'**
  String get playerError;

  /// No description provided for @close.
  ///
  /// In pl, this message translates to:
  /// **'Zamknij'**
  String get close;

  /// No description provided for @selectQuality.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz jakość'**
  String get selectQuality;

  /// No description provided for @selectQualitySeries.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz jakość dla całego serialu'**
  String get selectQualitySeries;

  /// No description provided for @selectQualitySeason.
  ///
  /// In pl, this message translates to:
  /// **'Sezon {number} - wybierz jakość'**
  String selectQualitySeason(int number);

  /// No description provided for @supportCreatorTitle.
  ///
  /// In pl, this message translates to:
  /// **'Wsparcie Twórcy'**
  String get supportCreatorTitle;

  /// No description provided for @supportCreatorBody1.
  ///
  /// In pl, this message translates to:
  /// **'Aplikacja jest w 100% darmowa. Jeżeli jednak chcesz wesprzeć moją pracę i rozwój projektu, możesz włączyć małe, nieprzeszkadzające reklamy na dole ekranu.'**
  String get supportCreatorBody1;

  /// No description provided for @supportCreatorBody2.
  ///
  /// In pl, this message translates to:
  /// **'Jeśli wolisz aplikację całkowicie bez reklam – nie ma problemu! Kod Google Ads nie zostanie wtedy w ogóle załadowany.'**
  String get supportCreatorBody2;

  /// No description provided for @supportCreatorAccept.
  ///
  /// In pl, this message translates to:
  /// **'Tak, chcę wspierać (Włącz reklamy)'**
  String get supportCreatorAccept;

  /// No description provided for @supportCreatorDecline.
  ///
  /// In pl, this message translates to:
  /// **'Nie, dziękuję'**
  String get supportCreatorDecline;

  /// No description provided for @supportCreatorAdsTitle.
  ///
  /// In pl, this message translates to:
  /// **'Wsparcie Twórcy (Reklamy)'**
  String get supportCreatorAdsTitle;

  /// No description provided for @supportCreatorAdsSubtitle.
  ///
  /// In pl, this message translates to:
  /// **'Wyświetlaj małe, nieprzeszkadzające reklamy, aby wesprzeć projekt.'**
  String get supportCreatorAdsSubtitle;

  /// No description provided for @managePrivacySubtitle.
  ///
  /// In pl, this message translates to:
  /// **'Zmień zgodę na wyświetlanie spersonalizowanych reklam'**
  String get managePrivacySubtitle;

  /// No description provided for @loadingPrivacyOptions.
  ///
  /// In pl, this message translates to:
  /// **'Ładowanie opcji prywatności...'**
  String get loadingPrivacyOptions;

  /// No description provided for @toWatch.
  ///
  /// In pl, this message translates to:
  /// **'Do obejrzenia'**
  String get toWatch;

  /// No description provided for @lasttlyAdded.
  ///
  /// In pl, this message translates to:
  /// **'Ostatnio dodane'**
  String get lasttlyAdded;

  /// No description provided for @sdCardPermissionDenied.
  ///
  /// In pl, this message translates to:
  /// **'Brak uprawnień do zapisu na karcie SD. Zezwól w ustawieniach systemu.'**
  String get sdCardPermissionDenied;

  /// No description provided for @storagePermissionDenied.
  ///
  /// In pl, this message translates to:
  /// **'Odmowa dostępu do pamięci.'**
  String get storagePermissionDenied;

  /// No description provided for @downloadPathUpdated.
  ///
  /// In pl, this message translates to:
  /// **'Zaktualizowano ścieżkę pobierania.'**
  String get downloadPathUpdated;

  /// No description provided for @privacySettingsUpdated.
  ///
  /// In pl, this message translates to:
  /// **'Ustawienia prywatności zostały zaktualizowane.'**
  String get privacySettingsUpdated;

  /// No description provided for @pickDownloadFolderTitle.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz folder pobierania (np. na karcie SD)'**
  String get pickDownloadFolderTitle;

  /// No description provided for @logoutTooltip.
  ///
  /// In pl, this message translates to:
  /// **'Wyloguj'**
  String get logoutTooltip;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In pl, this message translates to:
  /// **'Wylogować?'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmContent.
  ///
  /// In pl, this message translates to:
  /// **'Będziesz musiał ponownie wpisać dane serwera.'**
  String get logoutConfirmContent;

  /// No description provided for @logout.
  ///
  /// In pl, this message translates to:
  /// **'Wyloguj'**
  String get logout;

  /// No description provided for @restoreDefaultTooltip.
  ///
  /// In pl, this message translates to:
  /// **'Przywróć domyślny'**
  String get restoreDefaultTooltip;

  /// No description provided for @concurrentDownloads.
  ///
  /// In pl, this message translates to:
  /// **'Jednoczesne pobierania'**
  String get concurrentDownloads;

  /// No description provided for @concurrentDownloadsSub.
  ///
  /// In pl, this message translates to:
  /// **'Ile plików pobierać naraz'**
  String get concurrentDownloadsSub;

  /// No description provided for @administration.
  ///
  /// In pl, this message translates to:
  /// **'Administracja'**
  String get administration;

  /// No description provided for @serverPanel.
  ///
  /// In pl, this message translates to:
  /// **'Panel serwera'**
  String get serverPanel;

  /// No description provided for @serverPanelSub.
  ///
  /// In pl, this message translates to:
  /// **'Otwórz ustawienia Jellyfin w przeglądarce wewnątrz aplikacji'**
  String get serverPanelSub;

  /// No description provided for @enterServerAndUsername.
  ///
  /// In pl, this message translates to:
  /// **'Podaj adres serwera i nazwę użytkownika.'**
  String get enterServerAndUsername;

  /// No description provided for @invalidLoginOrPassword.
  ///
  /// In pl, this message translates to:
  /// **'Błędny login lub hasło.'**
  String get invalidLoginOrPassword;

  /// No description provided for @connectionError.
  ///
  /// In pl, this message translates to:
  /// **'Błąd połączenia: Nie można połączyć się z {url}'**
  String connectionError(String url);

  /// No description provided for @serverAddressHint.
  ///
  /// In pl, this message translates to:
  /// **'np. http://192.168.0.11:8096'**
  String get serverAddressHint;

  /// No description provided for @loginAction.
  ///
  /// In pl, this message translates to:
  /// **'Zaloguj się'**
  String get loginAction;

  /// No description provided for @loadingPanel.
  ///
  /// In pl, this message translates to:
  /// **'Ładowanie panelu...'**
  String get loadingPanel;

  /// No description provided for @fromBeginning.
  ///
  /// In pl, this message translates to:
  /// **'Od początku (Online)'**
  String get fromBeginning;

  /// No description provided for @advancedTranscoding.
  ///
  /// In pl, this message translates to:
  /// **'Zaawansowane transkodowanie'**
  String get advancedTranscoding;

  /// No description provided for @hwAccelTitle.
  ///
  /// In pl, this message translates to:
  /// **'Akceleracja sprzętowa'**
  String get hwAccelTitle;

  /// No description provided for @hwAccelSub.
  ///
  /// In pl, this message translates to:
  /// **'Wymusza na serwerze konkretny dekoder'**
  String get hwAccelSub;

  /// No description provided for @autoServer.
  ///
  /// In pl, this message translates to:
  /// **'Automat (Serwer)'**
  String get autoServer;

  /// No description provided for @cpuLimitTitle.
  ///
  /// In pl, this message translates to:
  /// **'Limit rdzeni CPU'**
  String get cpuLimitTitle;

  /// No description provided for @cpuLimitSub.
  ///
  /// In pl, this message translates to:
  /// **'Ogranicza moc procesora serwera'**
  String get cpuLimitSub;

  /// No description provided for @autoNoLimit.
  ///
  /// In pl, this message translates to:
  /// **'Automat (Brak limitu)'**
  String get autoNoLimit;

  /// No description provided for @core1.
  ///
  /// In pl, this message translates to:
  /// **'1 rdzeń'**
  String get core1;

  /// No description provided for @cores2.
  ///
  /// In pl, this message translates to:
  /// **'2 rdzenie'**
  String get cores2;

  /// No description provided for @cores4.
  ///
  /// In pl, this message translates to:
  /// **'4 rdzenie'**
  String get cores4;

  /// No description provided for @cores8.
  ///
  /// In pl, this message translates to:
  /// **'8 rdzeni'**
  String get cores8;

  /// No description provided for @fpsLimitTitle.
  ///
  /// In pl, this message translates to:
  /// **'Limit FPS'**
  String get fpsLimitTitle;

  /// No description provided for @fpsLimitSub.
  ///
  /// In pl, this message translates to:
  /// **'Wymusza zrzucanie nadmiarowych klatek'**
  String get fpsLimitSub;

  /// No description provided for @autoOriginal.
  ///
  /// In pl, this message translates to:
  /// **'Automat (Oryginał)'**
  String get autoOriginal;

  /// No description provided for @fps24.
  ///
  /// In pl, this message translates to:
  /// **'24 FPS (Kino)'**
  String get fps24;

  /// No description provided for @fps30.
  ///
  /// In pl, this message translates to:
  /// **'30 FPS'**
  String get fps30;

  /// No description provided for @fps60.
  ///
  /// In pl, this message translates to:
  /// **'60 FPS'**
  String get fps60;

  /// No description provided for @audioQualityTitle.
  ///
  /// In pl, this message translates to:
  /// **'Jakość Audio'**
  String get audioQualityTitle;

  /// No description provided for @audioQualitySub.
  ///
  /// In pl, this message translates to:
  /// **'Bitrate ścieżki dźwiękowej'**
  String get audioQualitySub;

  /// No description provided for @audio320.
  ///
  /// In pl, this message translates to:
  /// **'320 kbps (Wysoka)'**
  String get audio320;

  /// No description provided for @audio192.
  ///
  /// In pl, this message translates to:
  /// **'192 kbps (Dobra)'**
  String get audio192;

  /// No description provided for @audio128.
  ///
  /// In pl, this message translates to:
  /// **'128 kbps (Standard)'**
  String get audio128;

  /// No description provided for @audio96.
  ///
  /// In pl, this message translates to:
  /// **'96 kbps (Niska)'**
  String get audio96;

  /// No description provided for @favorites.
  ///
  /// In pl, this message translates to:
  /// **'Ulubione'**
  String get favorites;

  /// No description provided for @addToFavorites.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj do ulubionych'**
  String get addToFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In pl, this message translates to:
  /// **'Usuń z ulubionych'**
  String get removeFromFavorites;

  /// No description provided for @favoriteUpdateError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zaktualizować ulubionych.'**
  String get favoriteUpdateError;

  /// No description provided for @markWatched.
  ///
  /// In pl, this message translates to:
  /// **'Oznacz jako obejrzane'**
  String get markWatched;

  /// No description provided for @markUnwatched.
  ///
  /// In pl, this message translates to:
  /// **'Oznacz jako nieobejrzane'**
  String get markUnwatched;

  /// No description provided for @watchedUpdateError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zmienić stanu obejrzenia.'**
  String get watchedUpdateError;

  /// No description provided for @libraryLoadError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wczytać biblioteki. Sprawdź połączenie z serwerem.'**
  String get libraryLoadError;

  /// No description provided for @certificateTrustSaveError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zapisać ustawienia certyfikatu.'**
  String get certificateTrustSaveError;

  /// No description provided for @loginCertificateError.
  ///
  /// In pl, this message translates to:
  /// **'Certyfikat HTTPS serwera nie jest zaufany. Jeśli to Twój serwer z własnym certyfikatem, zaznacz „Zaufaj certyfikatowi HTTPS serwera”.'**
  String get loginCertificateError;

  /// No description provided for @loginServerError.
  ///
  /// In pl, this message translates to:
  /// **'Serwer zwrócił nieoczekiwaną odpowiedź. Sprawdź adres serwera.'**
  String get loginServerError;

  /// No description provided for @insecureHttpWarning.
  ///
  /// In pl, this message translates to:
  /// **'Ten adres używa nieszyfrowanego HTTP poza siecią lokalną. Hasło i token będą przesyłane jawnym tekstem. Użyj https://, jeśli serwer na to pozwala.'**
  String get insecureHttpWarning;

  /// No description provided for @trustCertificateTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zaufaj certyfikatowi HTTPS serwera'**
  String get trustCertificateTitle;

  /// No description provided for @trustCertificateSub.
  ///
  /// In pl, this message translates to:
  /// **'Użyj tylko dla serwera z własnym lub niezaufanym certyfikatem.'**
  String get trustCertificateSub;

  /// No description provided for @credentialStorageError.
  ///
  /// In pl, this message translates to:
  /// **'Nie można odczytać zapisanych danych logowania. Twoje dane nie zostały usunięte. Spróbuj ponownie.'**
  String get credentialStorageError;

  /// No description provided for @tryAgain.
  ///
  /// In pl, this message translates to:
  /// **'Spróbuj ponownie'**
  String get tryAgain;

  /// No description provided for @serverUnreachable.
  ///
  /// In pl, this message translates to:
  /// **'Nie można połączyć się z serwerem. Sprawdź połączenie z internetem lub czy serwer działa. Pobrane pliki są dostępne offline.'**
  String get serverUnreachable;

  /// No description provided for @failedDownloadTitle.
  ///
  /// In pl, this message translates to:
  /// **'Nieudane pobieranie'**
  String get failedDownloadTitle;

  /// No description provided for @failedDownloadCount.
  ///
  /// In pl, this message translates to:
  /// **'{count, plural, =1{1 pobieranie nie powiodło się.} few{{count} pobrania nie powiodły się.} other{{count} pobrań nie powiodło się.}}'**
  String failedDownloadCount(int count);

  /// No description provided for @failedDownloadRetryQuestion.
  ///
  /// In pl, this message translates to:
  /// **'Czy chcesz ponowić pobieranie?'**
  String get failedDownloadRetryQuestion;

  /// No description provided for @no.
  ///
  /// In pl, this message translates to:
  /// **'Nie'**
  String get no;

  /// No description provided for @retry.
  ///
  /// In pl, this message translates to:
  /// **'Ponów'**
  String get retry;

  /// No description provided for @playerTlsVerify.
  ///
  /// In pl, this message translates to:
  /// **'Weryfikuj certyfikat TLS w odtwarzaczu'**
  String get playerTlsVerify;

  /// No description provided for @playerTlsVerifySub.
  ///
  /// In pl, this message translates to:
  /// **'Odtwarzacz sprawdza certyfikat HTTPS serwera (pomija serwery oznaczone jako zaufane). Wyłącz, jeśli odtwarzanie przez HTTPS przestało działać.'**
  String get playerTlsVerifySub;

  /// No description provided for @introSkipperSection.
  ///
  /// In pl, this message translates to:
  /// **'Pomijanie intro (Intro Skipper)'**
  String get introSkipperSection;

  /// No description provided for @showSkipButton.
  ///
  /// In pl, this message translates to:
  /// **'Przycisk pomijania'**
  String get showSkipButton;

  /// No description provided for @showSkipButtonSub.
  ///
  /// In pl, this message translates to:
  /// **'Pokazuj „Pomiń intro” i podobne przyciski, gdy serwer zna segmenty odcinka (wtyczka Intro Skipper lub segmenty Jellyfin 10.10+)'**
  String get showSkipButtonSub;

  /// No description provided for @autoSkipIntro.
  ///
  /// In pl, this message translates to:
  /// **'Automatycznie pomijaj intro i podsumowanie'**
  String get autoSkipIntro;

  /// No description provided for @autoSkipIntroSub.
  ///
  /// In pl, this message translates to:
  /// **'Przewija od razu, bez naciskania przycisku'**
  String get autoSkipIntroSub;

  /// No description provided for @autoSkipCredits.
  ///
  /// In pl, this message translates to:
  /// **'Automatycznie pomijaj napisy końcowe'**
  String get autoSkipCredits;

  /// No description provided for @autoSkipCreditsSub.
  ///
  /// In pl, this message translates to:
  /// **'Po napisach końcowych przechodzi do następnego odcinka, jeśli jest'**
  String get autoSkipCreditsSub;

  /// No description provided for @selectedCount.
  ///
  /// In pl, this message translates to:
  /// **'Zaznaczono: {count}'**
  String selectedCount(int count);

  /// No description provided for @searchDownloadsHint.
  ///
  /// In pl, this message translates to:
  /// **'Szukaj pobranych...'**
  String get searchDownloadsHint;

  /// No description provided for @skipIntro.
  ///
  /// In pl, this message translates to:
  /// **'Pomiń intro'**
  String get skipIntro;

  /// No description provided for @skipCredits.
  ///
  /// In pl, this message translates to:
  /// **'Pomiń napisy końcowe'**
  String get skipCredits;

  /// No description provided for @skipRecap.
  ///
  /// In pl, this message translates to:
  /// **'Pomiń podsumowanie'**
  String get skipRecap;

  /// No description provided for @skipPreview.
  ///
  /// In pl, this message translates to:
  /// **'Pomiń zapowiedź'**
  String get skipPreview;

  /// No description provided for @skipCommercial.
  ///
  /// In pl, this message translates to:
  /// **'Pomiń reklamę'**
  String get skipCommercial;

  /// No description provided for @previousEpisode.
  ///
  /// In pl, this message translates to:
  /// **'Poprzedni odcinek'**
  String get previousEpisode;

  /// No description provided for @nextEpisode.
  ///
  /// In pl, this message translates to:
  /// **'Następny odcinek'**
  String get nextEpisode;

  /// No description provided for @serverPanelNoServer.
  ///
  /// In pl, this message translates to:
  /// **'Najpierw zaloguj się do serwera.'**
  String get serverPanelNoServer;

  /// No description provided for @unwantedSnoozedUntil.
  ///
  /// In pl, this message translates to:
  /// **'do {date}'**
  String unwantedSnoozedUntil(String date);

  /// No description provided for @unwantedUntilNewEpisode.
  ///
  /// In pl, this message translates to:
  /// **'do nowego odcinka'**
  String get unwantedUntilNewEpisode;

  /// No description provided for @unwantedSnoozed.
  ///
  /// In pl, this message translates to:
  /// **'Uśpiony'**
  String get unwantedSnoozed;

  /// No description provided for @undo.
  ///
  /// In pl, this message translates to:
  /// **'Cofnij'**
  String get undo;

  /// No description provided for @unwantedError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zmienić listy. Spróbuj ponownie.'**
  String get unwantedError;

  /// No description provided for @unwantedWatchLaterAdded.
  ///
  /// In pl, this message translates to:
  /// **'Dodano „{name}” do „Na później”'**
  String unwantedWatchLaterAdded(String name);

  /// No description provided for @unwantedWatchLaterRemoved.
  ///
  /// In pl, this message translates to:
  /// **'Usunięto „{name}” z „Na później”'**
  String unwantedWatchLaterRemoved(String name);

  /// No description provided for @unwantedMarked.
  ///
  /// In pl, this message translates to:
  /// **'„{name}” → Nieulubione. Zniknie z list do oglądania.'**
  String unwantedMarked(String name);

  /// No description provided for @unwantedRestored.
  ///
  /// In pl, this message translates to:
  /// **'Przywrócono „{name}”'**
  String unwantedRestored(String name);

  /// No description provided for @unwantedSnoozeTitle.
  ///
  /// In pl, this message translates to:
  /// **'Uśpij „{name}”'**
  String unwantedSnoozeTitle(String name);

  /// No description provided for @unwantedSnoozeHint.
  ///
  /// In pl, this message translates to:
  /// **'Uśpiony serial znika z „Następne” i wraca sam po wybranym czasie.'**
  String get unwantedSnoozeHint;

  /// No description provided for @unwantedWake.
  ///
  /// In pl, this message translates to:
  /// **'Obudź teraz'**
  String get unwantedWake;

  /// No description provided for @unwantedSnoozeNewEpisode.
  ///
  /// In pl, this message translates to:
  /// **'Do nowego odcinka'**
  String get unwantedSnoozeNewEpisode;

  /// No description provided for @unwantedSnoozeDays.
  ///
  /// In pl, this message translates to:
  /// **'Na {days} dni'**
  String unwantedSnoozeDays(int days);

  /// No description provided for @unwantedWoken.
  ///
  /// In pl, this message translates to:
  /// **'Obudzono „{name}”'**
  String unwantedWoken(String name);

  /// No description provided for @unwantedSnoozedMessage.
  ///
  /// In pl, this message translates to:
  /// **'Uśpiono „{name}”'**
  String unwantedSnoozedMessage(String name);

  /// No description provided for @unwantedWatchLater.
  ///
  /// In pl, this message translates to:
  /// **'Na później'**
  String get unwantedWatchLater;

  /// No description provided for @unwantedSnooze.
  ///
  /// In pl, this message translates to:
  /// **'Uśpij'**
  String get unwantedSnooze;

  /// No description provided for @unwantedNotInterested.
  ///
  /// In pl, this message translates to:
  /// **'Nieulubione'**
  String get unwantedNotInterested;

  /// No description provided for @unwantedAppliesToSeries.
  ///
  /// In pl, this message translates to:
  /// **'Dotyczy całego serialu „{name}”'**
  String unwantedAppliesToSeries(String name);

  /// No description provided for @unwantedSnoozedList.
  ///
  /// In pl, this message translates to:
  /// **'Uśpione'**
  String get unwantedSnoozedList;

  /// No description provided for @unwantedEmptyWatchLater.
  ///
  /// In pl, this message translates to:
  /// **'Lista „Na później” jest pusta. Dodaj film lub serial przyciskiem „Na później” na jego stronie.'**
  String get unwantedEmptyWatchLater;

  /// No description provided for @unwantedEmptySnoozed.
  ///
  /// In pl, this message translates to:
  /// **'Nic nie śpi. Uśpij serial, żeby na jakiś czas zniknął z „Następne”.'**
  String get unwantedEmptySnoozed;

  /// No description provided for @unwantedEmptyUnwanted.
  ///
  /// In pl, this message translates to:
  /// **'Brak nieulubionych. Oznacz serial lub film kciukiem w dół na jego stronie.'**
  String get unwantedEmptyUnwanted;

  /// No description provided for @unwantedAddedOn.
  ///
  /// In pl, this message translates to:
  /// **'Dodano {date}'**
  String unwantedAddedOn(String date);

  /// No description provided for @unwantedRemoveWatchLater.
  ///
  /// In pl, this message translates to:
  /// **'Usuń z „Na później”'**
  String get unwantedRemoveWatchLater;

  /// No description provided for @unwantedRestore.
  ///
  /// In pl, this message translates to:
  /// **'Przywróć'**
  String get unwantedRestore;

  /// No description provided for @unwantedMyLists.
  ///
  /// In pl, this message translates to:
  /// **'Moje listy'**
  String get unwantedMyLists;

  /// No description provided for @durationHoursMinutes.
  ///
  /// In pl, this message translates to:
  /// **'{hours} godz. {minutes} min'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @durationMinutes.
  ///
  /// In pl, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @seasonEpisodeLabel.
  ///
  /// In pl, this message translates to:
  /// **'Sezon {season} · Odcinek {episode}'**
  String seasonEpisodeLabel(int season, int episode);

  /// No description provided for @seasonEpisodeShort.
  ///
  /// In pl, this message translates to:
  /// **'S{season} O{episode}'**
  String seasonEpisodeShort(int season, int episode);

  /// No description provided for @endsAt.
  ///
  /// In pl, this message translates to:
  /// **'Koniec o {time}'**
  String endsAt(String time);

  /// No description provided for @timeLeft.
  ///
  /// In pl, this message translates to:
  /// **'Zostało {duration}'**
  String timeLeft(String duration);

  /// No description provided for @subtitleCount.
  ///
  /// In pl, this message translates to:
  /// **'{count, plural, =1{1 napisy} few{{count} napisy} many{{count} napisów} other{{count} napisów}}'**
  String subtitleCount(int count);

  /// No description provided for @watched.
  ///
  /// In pl, this message translates to:
  /// **'Obejrzane'**
  String get watched;

  /// No description provided for @downloadedBadge.
  ///
  /// In pl, this message translates to:
  /// **'Pobrane'**
  String get downloadedBadge;

  /// No description provided for @showMore.
  ///
  /// In pl, this message translates to:
  /// **'Pokaż więcej'**
  String get showMore;

  /// No description provided for @showLess.
  ///
  /// In pl, this message translates to:
  /// **'Pokaż mniej'**
  String get showLess;

  /// No description provided for @directedBy.
  ///
  /// In pl, this message translates to:
  /// **'Reżyseria'**
  String get directedBy;

  /// No description provided for @writtenBy.
  ///
  /// In pl, this message translates to:
  /// **'Scenariusz'**
  String get writtenBy;

  /// No description provided for @studio.
  ///
  /// In pl, this message translates to:
  /// **'Studio'**
  String get studio;

  /// No description provided for @cast.
  ///
  /// In pl, this message translates to:
  /// **'Obsada'**
  String get cast;

  /// No description provided for @chapters.
  ///
  /// In pl, this message translates to:
  /// **'Rozdziały'**
  String get chapters;

  /// No description provided for @chapterNumber.
  ///
  /// In pl, this message translates to:
  /// **'Rozdział {number}'**
  String chapterNumber(int number);

  /// No description provided for @moreEpisodes.
  ///
  /// In pl, this message translates to:
  /// **'Inne odcinki'**
  String get moreEpisodes;

  /// No description provided for @technicalDetails.
  ///
  /// In pl, this message translates to:
  /// **'Informacje techniczne'**
  String get technicalDetails;

  /// No description provided for @mediaContainer.
  ///
  /// In pl, this message translates to:
  /// **'Kontener'**
  String get mediaContainer;

  /// No description provided for @mediaFileSize.
  ///
  /// In pl, this message translates to:
  /// **'Rozmiar'**
  String get mediaFileSize;

  /// No description provided for @mediaBitrate.
  ///
  /// In pl, this message translates to:
  /// **'Bitrate'**
  String get mediaBitrate;

  /// No description provided for @mediaVideo.
  ///
  /// In pl, this message translates to:
  /// **'Wideo'**
  String get mediaVideo;

  /// No description provided for @mediaAudio.
  ///
  /// In pl, this message translates to:
  /// **'Dźwięk'**
  String get mediaAudio;

  /// No description provided for @cancelDownload.
  ///
  /// In pl, this message translates to:
  /// **'Anuluj pobieranie'**
  String get cancelDownload;

  /// No description provided for @favoritesAll.
  ///
  /// In pl, this message translates to:
  /// **'Wszystkie'**
  String get favoritesAll;

  /// No description provided for @favoritesMovies.
  ///
  /// In pl, this message translates to:
  /// **'Filmy'**
  String get favoritesMovies;

  /// No description provided for @favoritesSeries.
  ///
  /// In pl, this message translates to:
  /// **'Seriale'**
  String get favoritesSeries;

  /// No description provided for @favoritesEpisodes.
  ///
  /// In pl, this message translates to:
  /// **'Odcinki'**
  String get favoritesEpisodes;

  /// No description provided for @sortBy.
  ///
  /// In pl, this message translates to:
  /// **'Sortuj'**
  String get sortBy;

  /// No description provided for @sortName.
  ///
  /// In pl, this message translates to:
  /// **'Nazwa'**
  String get sortName;

  /// No description provided for @sortDateAdded.
  ///
  /// In pl, this message translates to:
  /// **'Ostatnio dodane'**
  String get sortDateAdded;

  /// No description provided for @sortPremiere.
  ///
  /// In pl, this message translates to:
  /// **'Data premiery'**
  String get sortPremiere;

  /// No description provided for @sortRating.
  ///
  /// In pl, this message translates to:
  /// **'Ocena'**
  String get sortRating;

  /// No description provided for @noFavorites.
  ///
  /// In pl, this message translates to:
  /// **'Brak ulubionych'**
  String get noFavorites;

  /// No description provided for @noFavoritesHint.
  ///
  /// In pl, this message translates to:
  /// **'Dotknij serca na filmie, serialu lub odcinku, żeby go tu dodać.'**
  String get noFavoritesHint;

  /// No description provided for @noFavoritesInFilter.
  ///
  /// In pl, this message translates to:
  /// **'Brak ulubionych w tej kategorii.'**
  String get noFavoritesInFilter;

  /// No description provided for @loadError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wczytać danych z serwera.'**
  String get loadError;

  /// No description provided for @search.
  ///
  /// In pl, this message translates to:
  /// **'Szukaj'**
  String get search;

  /// No description provided for @searchEverywhereHint.
  ///
  /// In pl, this message translates to:
  /// **'Szukaj filmów, seriali i odcinków'**
  String get searchEverywhereHint;

  /// No description provided for @noSearchResults.
  ///
  /// In pl, this message translates to:
  /// **'Nic nie znaleziono dla „{query}”'**
  String noSearchResults(String query);

  /// No description provided for @searchStartTyping.
  ///
  /// In pl, this message translates to:
  /// **'Wpisz co najmniej 2 znaki.'**
  String get searchStartTyping;

  /// No description provided for @episodeOf.
  ///
  /// In pl, this message translates to:
  /// **'{series} · S{season} O{episode}'**
  String episodeOf(String series, int season, int episode);

  /// No description provided for @unwantedSnoozeOneDay.
  ///
  /// In pl, this message translates to:
  /// **'Na 1 dzień'**
  String get unwantedSnoozeOneDay;

  /// No description provided for @unwantedSnoozeWeek.
  ///
  /// In pl, this message translates to:
  /// **'Na tydzień'**
  String get unwantedSnoozeWeek;

  /// No description provided for @unwantedSnoozeTwoWeeks.
  ///
  /// In pl, this message translates to:
  /// **'Na 2 tygodnie'**
  String get unwantedSnoozeTwoWeeks;

  /// No description provided for @unwantedSnoozeMonth.
  ///
  /// In pl, this message translates to:
  /// **'Na miesiąc'**
  String get unwantedSnoozeMonth;

  /// No description provided for @unwantedSnoozeThreeMonths.
  ///
  /// In pl, this message translates to:
  /// **'Na 3 miesiące'**
  String get unwantedSnoozeThreeMonths;

  /// No description provided for @noEpisodes.
  ///
  /// In pl, this message translates to:
  /// **'Ten serial nie ma jeszcze odcinków.'**
  String get noEpisodes;

  /// No description provided for @specials.
  ///
  /// In pl, this message translates to:
  /// **'Odcinki specjalne'**
  String get specials;

  /// No description provided for @seasonNumber.
  ///
  /// In pl, this message translates to:
  /// **'Sezon {number}'**
  String seasonNumber(int number);

  /// No description provided for @download.
  ///
  /// In pl, this message translates to:
  /// **'Pobierz'**
  String get download;

  /// No description provided for @playNext.
  ///
  /// In pl, this message translates to:
  /// **'Odtwórz'**
  String get playNext;

  /// No description provided for @episodeNumber.
  ///
  /// In pl, this message translates to:
  /// **'Odcinek {number}'**
  String episodeNumber(int number);

  /// No description provided for @searchInLibraryHint.
  ///
  /// In pl, this message translates to:
  /// **'Szukaj w: {library}'**
  String searchInLibraryHint(String library);

  /// No description provided for @downloadsInProgress.
  ///
  /// In pl, this message translates to:
  /// **'Pobieranie ({count})'**
  String downloadsInProgress(int count);

  /// No description provided for @selectAll.
  ///
  /// In pl, this message translates to:
  /// **'Zaznacz wszystko'**
  String get selectAll;

  /// No description provided for @selectItems.
  ///
  /// In pl, this message translates to:
  /// **'Zaznacz do usunięcia'**
  String get selectItems;

  /// No description provided for @refresh.
  ///
  /// In pl, this message translates to:
  /// **'Odśwież'**
  String get refresh;

  /// No description provided for @noOfflineFilesHint.
  ///
  /// In pl, this message translates to:
  /// **'Na stronie filmu lub odcinka wybierz „Pobierz do pamięci”, a na stronie serialu „Pobierz sezon”.'**
  String get noOfflineFilesHint;

  /// No description provided for @general.
  ///
  /// In pl, this message translates to:
  /// **'Ogólne'**
  String get general;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
