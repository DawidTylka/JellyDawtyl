import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/server_url.dart';

class StorageService {
  final _storage = const FlutterSecureStorage();

  Future<void> saveCredentials(String url, String token, String userId) async {
    await _storage.write(key: 'baseUrl', value: normalizeServerUrl(url));
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
    // Addresses saved by older versions may lack a scheme; normalize on read
    // so every consumer gets the same canonical address.
    return {
      'baseUrl': normalizeServerUrl(baseUrl),
      'token': token,
      'userId': userId,
    };
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

  // One random identifier per installation, used as the Jellyfin DeviceId at
  // login and for the WebSocket. The key predates the login use; reusing it
  // keeps the identifier this installation already sends to the server.
  static const _deviceIdKey = 'jellyfin_socket_device_id_v1';
  static Future<String>? _deviceIdFuture;

  Future<String> getDeviceId() async {
    final pending = _deviceIdFuture ??= _loadOrCreateDeviceId();
    try {
      return await pending;
    } catch (_) {
      if (identical(_deviceIdFuture, pending)) _deviceIdFuture = null;
      rethrow;
    }
  }

  Future<String> _loadOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final id = List<int>.generate(
      32,
      (_) => random.nextInt(16),
    ).map((digit) => digit.toRadixString(16)).join();
    await _storage.write(key: _deviceIdKey, value: id);
    return id;
  }

  Future<String?> getString(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> clearAll() async => await _storage.deleteAll();
}
