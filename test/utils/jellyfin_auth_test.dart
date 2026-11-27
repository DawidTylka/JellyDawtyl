import 'package:flutter_test/flutter_test.dart';
import 'package:jellydawtyl/utils/jellyfin_auth.dart';

void main() {
  test('token requests use the MediaBrowser Authorization header', () {
    expect(jellyfinAuthHeaders('abc123'), {
      'Authorization': 'MediaBrowser Token="abc123"',
    });
  });

  test('login header identifies the client and URL-encodes values', () {
    expect(
      jellyfinLoginAuthorization(deviceId: 'dev 1', device: 'Pixel "8"'),
      'MediaBrowser Client="JellyDawtyl", Device="Pixel%20%228%22", '
      'DeviceId="dev%201", Version="1.0.0"',
    );
  });
}
