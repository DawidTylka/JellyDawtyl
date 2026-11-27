import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_config.dart';

/// `google_mobile_ads` supports only Android and iOS. Other platforms never
/// show the ads prompt and never load the SDK.
bool get adsSupportedOnThisPlatform =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// UMP request parameters shared by app start and the privacy settings.
/// Debug geography and test devices are applied only in debug builds.
ConsentRequestParameters buildConsentRequestParameters() {
  if (!kDebugMode) return ConsentRequestParameters();
  const testDeviceId = AppConfig.admobTestDeviceId;
  return ConsentRequestParameters(
    consentDebugSettings: ConsentDebugSettings(
      debugGeography: DebugGeography.debugGeographyEea,
      testIdentifiers: testDeviceId.isNotEmpty ? [testDeviceId] : [],
    ),
  );
}
