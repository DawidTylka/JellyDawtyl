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
  /// **'Użyj menedżera Android'**
  String get useNativeDownloader;

  /// No description provided for @useNativeDownloaderSub.
  ///
  /// In pl, this message translates to:
  /// **'Pobieraj w tle przez system'**
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
  /// **'OGLĄDAJ ONLINE'**
  String get watchOnline;

  /// No description provided for @watchOffline.
  ///
  /// In pl, this message translates to:
  /// **'OGLĄDAJ OFFLINE'**
  String get watchOffline;

  /// No description provided for @downloadToMemory.
  ///
  /// In pl, this message translates to:
  /// **'POBIERZ DO PAMIĘCI'**
  String get downloadToMemory;

  /// No description provided for @downloadAgain.
  ///
  /// In pl, this message translates to:
  /// **'POBIERZ PONOWNIE'**
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
  /// **'Usuń elementy'**
  String get deleteItems;

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
  String selectQualitySeason(Object number);

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
