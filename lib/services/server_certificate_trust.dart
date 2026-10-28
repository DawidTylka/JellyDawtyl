import 'dart:convert';
import 'dart:io';

import 'package:flutter_downloader/flutter_downloader.dart';

import 'storage_service.dart';

/// Explicit, per-host opt-in for self-signed or otherwise invalid HTTPS certs.
/// All other hosts continue to use the platform's normal certificate checks.
class ServerCertificateTrust {
  ServerCertificateTrust._();

  static const _storageKey = 'trusted_https_hosts_v1';
  static final Set<String> _trustedHosts = {};
  static bool _installed = false;

  static Set<String> get trustedHosts => Set.unmodifiable(_trustedHosts);

  static void install() {
    if (_installed) return;
    HttpOverrides.global = _ServerCertificateOverrides();
    _installed = true;
  }

  static Future<void> restore(StorageService storage) async {
    _trustedHosts.clear();
    try {
      final encoded = await storage.getString(_storageKey);
      if (encoded != null && encoded.isNotEmpty) {
        final decoded = jsonDecode(encoded);
        if (decoded is List) {
          _trustedHosts.addAll(
            decoded.whereType<String>().map((host) => host.toLowerCase()),
          );
        }
      }
    } catch (_) {
      // A failed or malformed preference must fail closed without blocking startup.
      _trustedHosts.clear();
    }
  }

  static bool addressUsesHttps(String address) => _httpsHost(address) != null;

  static bool trustsAddress(String address) {
    final host = _httpsHost(address);
    return host != null && _trustedHosts.contains(host);
  }

  static Future<void> setAddressTrusted({
    required StorageService storage,
    required String address,
    required bool trusted,
  }) async {
    final host = _httpsHost(address);
    if (host == null) return;
    final nextHosts = Set<String>.of(_trustedHosts);
    if (trusted) {
      nextHosts.add(host);
    } else {
      nextHosts.remove(host);
    }
    await storage.saveString(_storageKey, jsonEncode(nextHosts.toList()));
    _trustedHosts
      ..clear()
      ..addAll(nextHosts);
    await syncAndroidDownloaderTrust();
  }

  static bool acceptsInvalidCertificate(
    X509Certificate certificate,
    String host,
    int port,
  ) => _trustedHosts.contains(host.toLowerCase());

  static Future<void> syncAndroidDownloaderTrust() async {
    if (Platform.isAndroid && FlutterDownloader.initialized) {
      await FlutterDownloader.setTrustedHttpsHosts(_trustedHosts.toList());
    }
  }

  static String? _httpsHost(String address) {
    final value = address.trim();
    if (value.isEmpty) return null;
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(value);
    final uri = Uri.tryParse(hasScheme ? value : 'https://$value');
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty) {
      return null;
    }
    return uri.host.toLowerCase();
  }
}

class _ServerCertificateOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (certificate, host, port) =>
        ServerCertificateTrust.acceptsInvalidCertificate(
          certificate,
          host,
          port,
        );
    return client;
  }
}
