import 'package:flutter_application_1/services/server_certificate_trust.dart';
import 'package:flutter_application_1/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _MemoryStorage storage;

  setUp(() async {
    storage = _MemoryStorage();
    await ServerCertificateTrust.restore(storage);
  });

  test('shows certificate trust only for HTTPS addresses', () {
    expect(
      ServerCertificateTrust.addressUsesHttps('https://media.example'),
      isTrue,
    );
    expect(
      ServerCertificateTrust.addressUsesHttps('media.example:8096'),
      isTrue,
    );
    expect(
      ServerCertificateTrust.addressUsesHttps('http://media.example'),
      isFalse,
    );
    expect(ServerCertificateTrust.addressUsesHttps(''), isFalse);
  });

  test('trust is saved and applies only to the selected host', () async {
    await ServerCertificateTrust.setAddressTrusted(
      storage: storage,
      address: 'https://Media.Example:8920',
      trusted: true,
    );

    expect(
      ServerCertificateTrust.trustsAddress('https://media.example'),
      isTrue,
    );
    expect(
      ServerCertificateTrust.trustsAddress('https://other.example'),
      isFalse,
    );
    expect(
      ServerCertificateTrust.trustsAddress('http://media.example'),
      isFalse,
    );

    await ServerCertificateTrust.restore(storage);
    expect(
      ServerCertificateTrust.trustsAddress('https://media.example'),
      isTrue,
    );
  });

  test(
    'removing trust restores normal certificate validation for that host',
    () async {
      await ServerCertificateTrust.setAddressTrusted(
        storage: storage,
        address: 'https://media.example',
        trusted: true,
      );
      await ServerCertificateTrust.setAddressTrusted(
        storage: storage,
        address: 'https://media.example',
        trusted: false,
      );

      expect(
        ServerCertificateTrust.trustsAddress('https://media.example'),
        isFalse,
      );
    },
  );
}

class _MemoryStorage extends StorageService {
  final Map<String, String> _values = {};

  @override
  Future<String?> getString(String key) async => _values[key];

  @override
  Future<void> saveString(String key, String value) async {
    _values[key] = value;
  }
}
