import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../../services/server_certificate_trust.dart';

/// Setting key for TLS verification of streams opened by libmpv.
const playerTlsVerifySettingKey = 'setting_player_tls_verify';

/// mpv does not verify TLS certificates unless `tls-verify` is set, while the
/// first request of a stream carries the access token. Desktop builds of
/// libmpv/ffmpeg use the system certificate store, so verification is on by
/// default there. Android's ffmpeg has no default CA store; the app builds a
/// bundle from the system certificates, which still needs testing on more
/// devices, so there the option starts off.
bool get playerTlsVerifyDefault => !Platform.isAndroid;

/// Turns on certificate verification for [player] unless the user marked
/// the server as trusted (self-signed certificate) or turned the setting off.
Future<void> configurePlayerTls(
  Player player, {
  required String? baseUrl,
  required bool enabled,
}) async {
  final native = player.platform;
  if (native is! NativePlayer) return;
  if (!enabled || baseUrl == null || !baseUrl.startsWith('https://')) return;
  if (ServerCertificateTrust.trustsAddress(baseUrl)) return;
  try {
    if (Platform.isAndroid) {
      final bundle = await _androidCaBundle();
      if (bundle == null) return; // Verification without CAs would fail.
      await native.setProperty('tls-ca-file', bundle);
    }
    await native.setProperty('tls-verify', 'yes');
  } catch (error) {
    debugPrint('Nie udało się włączyć weryfikacji TLS (${error.runtimeType}).');
  }
}

String? _cachedBundlePath;

/// Concatenates Android's system CA certificates (PEM files, one per CA)
/// into a single file that mpv can use as `tls-ca-file`.
Future<String?> _androidCaBundle() async {
  if (_cachedBundlePath != null) return _cachedBundlePath;
  const dirs = [
    '/apex/com.android.conscrypt/cacerts', // Android 14+ (updatable)
    '/system/etc/security/cacerts',
  ];
  for (final path in dirs) {
    final dir = Directory(path);
    if (!await dir.exists()) continue;
    final buffer = StringBuffer();
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      try {
        final content = await entity.readAsString();
        final start = content.indexOf('-----BEGIN CERTIFICATE-----');
        final endMarker = '-----END CERTIFICATE-----';
        final end = content.indexOf(endMarker);
        if (start < 0 || end < start) continue;
        buffer.writeln(content.substring(start, end + endMarker.length));
      } catch (_) {
        // Unreadable entry: skip it.
      }
    }
    if (buffer.isEmpty) continue;
    final file = File('${Directory.systemTemp.path}/jellydawtyl_ca.pem');
    await file.writeAsString(buffer.toString(), flush: true);
    return _cachedBundlePath = file.path;
  }
  return null;
}
