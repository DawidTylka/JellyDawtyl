import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final _storage = const FlutterSecureStorage();

  Future<void> saveCredentials(String url, String token, String userId) async {
    await _storage.write(key: 'baseUrl', value: url);
    await _storage.write(key: 'token', value: token);
    await _storage.write(key: 'userId', value: userId);
  }

  Future<Map<String, String>?> getCredentials() async {
    try {
      final baseUrl = await _storage.read(key: 'baseUrl');
      final token = await _storage.read(key: 'token');
      final userId = await _storage.read(key: 'userId');

      if (baseUrl == null || token == null || userId == null) {
        return null;
      }

      return {'baseUrl': baseUrl, 'token': token, 'userId': userId};
    } catch (e) {
      await _storage.deleteAll();
      return null;
    }
  }

  Future<void> saveSetting(String key, bool value) async {
    await _storage.write(key: key, value: value.toString());
  }

  Future<bool> getSetting(String key, {bool defaultValue = false}) async {
    final value = await _storage.read(key: key);
    if (value == null) return defaultValue;
    return value == 'true';
  }

  Future<void> saveString(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> getString(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> clearAll() async => await _storage.deleteAll();
}
