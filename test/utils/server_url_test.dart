import 'package:flutter_test/flutter_test.dart';
import 'package:jellydawtyl/utils/server_url.dart';

void main() {
  group('normalizeServerUrl', () {
    test('adds https to an address without a scheme', () {
      expect(normalizeServerUrl('jf.example.com'), 'https://jf.example.com');
    });
    test('removes trailing slashes and spaces', () {
      expect(normalizeServerUrl(' jf.example.com/ '), 'https://jf.example.com');
      expect(
        normalizeServerUrl('http://host:8096/jellyfin//'),
        'http://host:8096/jellyfin',
      );
    });
    test('keeps an explicit scheme and is idempotent', () {
      const url = 'HTTP://192.168.0.11:8096';
      expect(normalizeServerUrl(url), url);
      expect(normalizeServerUrl(normalizeServerUrl(url)), url);
    });
  });

  group('isInsecurePublicAddress', () {
    test('plain http to the internet is insecure', () {
      expect(isInsecurePublicAddress('http://jf.example.com'), isTrue);
      expect(isInsecurePublicAddress('http://8.8.8.8:8096'), isTrue);
    });
    test('local network, https and addresses without a scheme are fine', () {
      for (final address in [
        'http://192.168.0.11:8096',
        'http://10.0.0.5',
        'http://172.20.1.1',
        'http://100.101.102.103', // Tailscale
        'http://localhost:8096',
        'http://nas.local',
        'http://jellyfin',
        'http://[fd00::1]:8096',
        'https://jf.example.com',
        'jf.example.com',
      ]) {
        expect(isInsecurePublicAddress(address), isFalse, reason: address);
      }
    });
  });
}
