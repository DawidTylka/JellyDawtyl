/// Build-time configuration.
///
/// Values come from `--dart-define-from-file=.env` (or `--dart-define`), so
/// they are compiled into the code instead of shipping `.env` as an asset
/// that anyone could unpack from the APK. Only non-secret values belong
/// here: everything in a client app can be read by its users.
library;

class AppConfig {
  const AppConfig._();

  /// Google's public test banner IDs are used when no value is provided.
  static const admobBannerAndroid = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  static const admobBannerIos = String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/2934735716',
  );

  /// Only used in debug builds, for UMP consent testing.
  static const admobTestDeviceId = String.fromEnvironment(
    'ADMOB_TEST_DEVICE_ID',
  );
}
