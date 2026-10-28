import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final _storage = const FlutterSecureStorage();

  Future<void> saveCredentials(String url, String token, String userId) async {
    await _storage.write(key: 'baseUrl', value: url);
    await _storage.write(key: 'token', value: token);
    await _storage.write(key: 'userId', value: userId);
  }

  Future<Map<String, String>?> getCredentials() async {
    final baseUrl = await _storage.read(key: 'baseUrl');
    final token = await _storage.read(key: 'token');
    final userId = await _storage.read(key: 'userId');

    if (baseUrl == null ||
        baseUrl.trim().isEmpty ||
        token == null ||
        token.trim().isEmpty ||
        userId == null ||
        userId.trim().isEmpty) {
      return null;
    }

    // Read failures propagate to the caller. Do not erase credentials or
    // unrelated settings as a recovery action.
    return {'baseUrl': baseUrl, 'token': token, 'userId': userId};
  }

  Future<void> saveSetting(String key, bool value) async {
    await _storage.write(key: key, value: value.toString());
  }

  Future<bool> getSetting(String key, {bool defaultValue = false}) async {
    final value = await _storage.read(key: key);
    if (value == null) return defaultValue;
    return value == 'true';
  }

  Future<int> getInt(String key, {int defaultValue = 0}) async {
    final value = await _storage.read(key: key);
    if (value == null) return defaultValue;
    return int.tryParse(value) ?? defaultValue;
  }

  Future<void> saveInt(String key, int value) async {
    await _storage.write(key: key, value: value.toString());
  }

  Future<void> saveString(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<void> clearCredentials() async {
    await Future.wait([
      _storage.delete(key: 'baseUrl'),
      _storage.delete(key: 'token'),
      _storage.delete(key: 'userId'),
    ]);
  }

  Future<String?> getString(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> clearAll() async => await _storage.deleteAll();
}
