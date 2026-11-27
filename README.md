# JellyDawtyl 🎥

## Help me testing

I am looking for testers who would like to try out this new integration and share their feedback. If you'd like to get access, please send me an email dawid.tylka3@gmail.com and I will gladly add you to the list. Once added, you will receive a confirmation along with further instructions.

## [ENGLISH VERSION]

JellyDawtyl is an unofficial, lightweight client for the **Jellyfin** media server, built with Flutter. The app focuses on smooth video playback, advanced offline management, and full control over stream quality.

### 🎯 Main Project Goal

The primary objective of **JellyDawtyl** is to enable the downloading of **transcoded** video. This allows users to save media from the server in a significantly smaller file size, which is essential for devices with limited storage or when working with slow internet connections.

This project was created mainly for my **personal use** to address specific storage management needs. However, if there is interest from the community, I am open to further developing the app, adding new features, and providing ongoing support.

### ✨ Key Features

* **Premium Player:** Built on the `MediaKit` engine, supporting on-the-fly quality changes, external subtitles (.srt), and automatic next-episode playback.
* **Offline Mode:** Download movies and series to your device. Choose specific video quality and download entire seasons with one click.
* **Smart Downloading:** Background downloads through Android's system downloader (optionally with a notification) and the Dio engine on desktop, cancelling, resuming original-quality downloads, and an option to restrict downloads to Wi-Fi only.
* **Skip Intro:** "Skip intro", "Skip credits" and "Skip recap" buttons (or automatic skipping) using segments from the [Intro Skipper](https://github.com/intro-skipper/intro-skipper) plugin or Jellyfin 10.10+ media segments, online and offline.
* **Desktop Ready:** Full mouse and trackpad support (including horizontal scrolling with the mouse wheel) for Windows, Linux and macOS.
* **Progress Sync:** Automatically reports playback progress back to the Jellyfin server.

### 🔧 Building

```bash
cp .env.example .env          # optional: your AdMob IDs
flutter pub get
flutter run --dart-define-from-file=.env
flutter test
```

`.env` is read by Gradle and passed to Dart with `--dart-define-from-file`; it is not bundled into the app. Without it, Google's public test ad IDs are used.

### 🛠️ Tech Stack

* **Framework:** [Flutter](https://flutter.dev)
* **Video Engine:** [MediaKit](https://mediakit.ml)
* **Networking:** [Dio](https://pub.dev/packages/dio)
* **Local Storage:** [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)
* **Audio Management:** [Audio Service](https://pub.dev/packages/audio_service)

### 📜 License & Legal

This project is released under the **GNU GPL v3** license. See the `LICENSE` file for details.

**Legal Note:** JellyDawtyl is an unofficial project. It is not affiliated with, authorized, or endorsed by the official Jellyfin team. The app uses the public Jellyfin API in accordance with their documentation.

## [WERSJA POLSKA]

JellyDawtyl to nieoficjalny, lekki klient dla serwera multimedialnego **Jellyfin**, zbudowany we Flutterze. Aplikacja skupia się na płynnym odtwarzaniu wideo, zaawansowanym zarządzaniu plikami offline oraz pełnej kontroli nad jakością strumienia.

### 🎯 Główny cel projektu

Głównym celem **JellyDawtyl** jest umożliwienie pobierania wideo w formie **transkodowanej**. Pozwala to na zapisywanie materiałów z serwera w znacznie mniejszym rozmiarze, co jest kluczowe przy ograniczonej pamięci urządzenia lub wolnym łączu internetowym.

Projekt powstał przede wszystkim na mój **własny, osobisty użytek**, aby rozwiązać konkretny problem z zarządzaniem miejscem na dysku. Niemniej jednak, jeśli aplikacja spotka się z zainteresowaniem ze strony innych użytkowników, rozważam jej dalszy rozwój, dodawanie nowych funkcji oraz regularne wsparcie.

### ✨ Kluczowe Funkcje

* **Odtwarzacz Premium:** Zbudowany na silniku `MediaKit`, obsługuje zmianę jakości "w locie", napisy zewnętrzne (.srt) i autoodtwarzanie kolejnych odcinków.
* **Tryb Offline:** Pobieranie filmów i seriali do pamięci urządzenia. Możliwość wyboru jakości wideo i pobierania całych sezonów jednym kliknięciem.
* **Inteligentne Pobieranie:** Pobieranie w tle przez systemowy menedżer Androida (opcjonalnie z powiadomieniem) i silnik Dio na komputerach, anulowanie, wznawianie pobierania oryginalnej jakości oraz opcja blokady pobierania przez dane komórkowe.
* **Pomijanie intro:** Przyciski „Pomiń intro”, „Pomiń napisy końcowe” i „Pomiń podsumowanie” (lub automatyczne pomijanie) na podstawie segmentów z wtyczki [Intro Skipper](https://github.com/intro-skipper/intro-skipper) albo segmentów Jellyfin 10.10+, także offline.
* **Desktop Ready:** Pełna obsługa myszy i gładzików (scrollowanie poziome rolką) na systemach Windows, Linux i macOS.
* **Synchronizacja Postępu:** Automatyczne raportowanie czasu oglądania do serwera Jellyfin.

### 🔧 Budowanie

```bash
cp .env.example .env          # opcjonalnie: własne identyfikatory AdMob
flutter pub get
flutter run --dart-define-from-file=.env
flutter test
```

`.env` czyta Gradle, a do kodu Darta trafia przez `--dart-define-from-file`; nie jest dołączany do aplikacji. Bez niego używane są publiczne testowe identyfikatory reklam Google.

### 🛠️ Technologie

* **Framework:** [Flutter](https://flutter.dev)
* **Silnik Wideo:** [MediaKit](https://mediakit.ml)
* **Networking:** [Dio](https://pub.dev/packages/dio)
* **Pamięć Lokalna:** [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)
* **Zarządzanie Audio:** [Audio Service](https://pub.dev/packages/audio_service)

### 📜 Licencja i Prawa Autorskie

Ten projekt jest udostępniany na licencji **GNU GPL v3**. Szczegóły znajdziesz w pliku `LICENSE`.

**Nota prawna:** JellyDawtyl jest projektem nieoficjalnym. Nie jest w żaden sposób powiązany, autoryzowany ani wspierany przez oficjalny zespół Jellyfin. Aplikacja korzysta z publicznego API Jellyfin zgodnie z ich dokumentacją.
