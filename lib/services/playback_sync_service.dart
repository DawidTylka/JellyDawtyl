import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'download_service.dart';
import 'jellyfin_api.dart';
import 'pending_playback_changes.dart';
import 'storage_service.dart';

/// Syncs offline playback up to Jellyfin and mirrors Jellyfin user data back
/// into metadata sidecars for downloaded videos.
class PlaybackSyncService {
  PlaybackSyncService._();
  static final PlaybackSyncService instance = PlaybackSyncService._();

  static const _storageKey = 'offline_playback_changes_v1';
  static const _deviceIdStorageKey = 'jellyfin_socket_device_id_v1';
  static const _itemBatchSize = 50;
  static const _reconcileThrottle = Duration(seconds: 30);

  final StorageService _storage = StorageService();
  final Map<String, Map<String, dynamic>> _pending = {};
  final Map<String, int> _socketRevisions = {};
  final ValueNotifier<int> downloadedMetadataRevision = ValueNotifier(0);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<dynamic>? _socketSubscription;
  WebSocket? _socket;
  Timer? _socketKeepAliveTimer;
  Timer? _retryTimer;
  Timer? _socketReconnectTimer;
  Future<void>? _refreshFuture;
  Future<void> _socketMessageQueue = Future<void>.value();
  Map<String, List<File>>? _downloadedMetadataFiles;
  DateTime? _lastReconcileStartedAt;
  String? _socketCredentialsKey;
  int _socketReconnectAttempts = 0;
  bool _initialized = false;
  bool _isSyncing = false;
  bool _socketConnecting = false;
  bool _isForeground = true;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final encoded = await _storage.getString(_storageKey);
      if (encoded != null && encoded.isNotEmpty) {
        final decoded = jsonDecode(encoded) as Map<String, dynamic>;
        _pending.addAll(
          decoded.map(
            (id, value) =>
                MapEntry(id, Map<String, dynamic>.from(value as Map)),
          ),
        );
      }
    } catch (error) {
      debugPrint(
        'Nie udało się odczytać kolejki synchronizacji odtwarzania: $error',
      );
    }

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      states,
    ) {
      if (states.any((state) => state != ConnectivityResult.none)) {
        unawaited(syncPending());
        unawaited(_ensureSocketConnected());
        unawaited(refreshDownloadedUserData(force: true));
      }
    });
    _retryTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(syncPending()),
    );
    unawaited(syncPending());
    unawaited(_ensureSocketConnected());
    unawaited(refreshDownloadedUserData(force: true));
  }

  void onAppPaused() {
    _isForeground = false;
    _socketReconnectTimer?.cancel();
    _socketReconnectTimer = null;
    final socket = _socket;
    _socket = null;
    _socketCredentialsKey = null;
    _socketKeepAliveTimer?.cancel();
    _socketKeepAliveTimer = null;
    unawaited(_socketSubscription?.cancel());
    _socketSubscription = null;
    if (socket != null) unawaited(socket.close(WebSocketStatus.goingAway));
  }

  void onAppResumed() {
    _isForeground = true;
    unawaited(syncPending());
    unawaited(_ensureSocketConnected());
    unawaited(refreshDownloadedUserData(force: true));
  }

  void onCredentialsChanged() {
    _closeSocket();
    unawaited(_ensureSocketConnected());
    unawaited(refreshDownloadedUserData(force: true));
  }

  Future<void> record({
    required String itemId,
    required String filePath,
    required Duration position,
    required Duration duration,
    required bool stopped,
  }) async {
    if (itemId.isEmpty) return;
    final positionMs = position.inMilliseconds.clamp(0, 1 << 62);
    final durationMs = duration.inMilliseconds.clamp(0, 1 << 62);
    final played = durationMs > 0 && positionMs >= durationMs * 0.95;

    // Make offline playback visible immediately, even without a network.
    try {
      final file = File('$filePath.json');
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        if (data is Map<String, dynamic>) {
          final userData = Map<String, dynamic>.from(
            data['UserData'] as Map? ?? {},
          );
          userData['PlaybackPositionTicks'] = positionMs * 10000;
          userData['Played'] = played;
          data['UserData'] = userData;
          await file.writeAsString(
            const JsonEncoder.withIndent('  ').convert(data),
          );
          downloadedMetadataRevision.value++;
        }
      }
    } catch (error) {
      debugPrint('Nie udało się zapisać lokalnego postępu: $error');
    }

    _pending[itemId] = {
      'itemId': itemId,
      'positionMs': positionMs,
      'durationMs': durationMs,
      'played': played,
      'stopped': stopped,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await _save();
    unawaited(syncPending());
  }

  /// Reconciles only downloaded item IDs, in bounded batches. This is called
  /// on app resume/connectivity restoration and when Downloads is opened.
  Future<void> refreshDownloadedUserData({bool force = false}) {
    if (_refreshFuture != null) return _refreshFuture!;
    final now = DateTime.now();
    if (!force &&
        _lastReconcileStartedAt != null &&
        now.difference(_lastReconcileStartedAt!) < _reconcileThrottle) {
      return Future<void>.value();
    }
    _lastReconcileStartedAt = now;
    final refresh = _refreshDownloadedUserData();
    _refreshFuture = refresh;
    return refresh.whenComplete(() => _refreshFuture = null);
  }

  Future<void> _refreshDownloadedUserData() async {
    // Flush this device's newer offline edits before applying a server snapshot.
    await syncPending();
    if (_isSyncing) return;

    Map<String, String>? credentials;
    try {
      credentials = await _storage.getCredentials();
    } catch (error) {
      debugPrint(
        'Nie można odczytać danych do synchronizacji (${error.runtimeType}).',
      );
      return;
    }
    if (credentials == null) return;
    final filesByItemId = await _scanDownloadedMetadataFiles();
    _downloadedMetadataFiles = filesByItemId;
    final itemIds = filesByItemId.keys.toList();
    if (itemIds.isEmpty) return;

    final api = JellyfinApi();
    final pendingAtStart = _pending.keys.toSet();
    final socketRevisionsAtStart = Map<String, int>.from(_socketRevisions);
    var changed = false;
    for (var start = 0; start < itemIds.length; start += _itemBatchSize) {
      final end = min(start + _itemBatchSize, itemIds.length);
      final ids = itemIds.sublist(start, end);
      final items = await api.fetchUserDataForItems(
        baseUrl: credentials['baseUrl']!,
        token: credentials['token']!,
        userId: credentials['userId']!,
        itemIds: ids,
      );
      for (final item in items) {
        final itemId = item['Id']?.toString();
        final userData = item['UserData'];
        if (itemId == null ||
            userData is! Map ||
            pendingAtStart.contains(itemId) ||
            _pending.containsKey(itemId) ||
            (_socketRevisions[itemId] ?? 0) >
                (socketRevisionsAtStart[itemId] ?? 0)) {
          continue;
        }
        changed |= await _writeUserDataToSidecars(
          filesByItemId[itemId] ?? const [],
          Map<String, dynamic>.from(userData),
        );
      }
    }
    if (changed) downloadedMetadataRevision.value++;
  }

  Future<Map<String, List<File>>> _scanDownloadedMetadataFiles() async {
    final result = <String, List<File>>{};
    try {
      final root = Directory(await DownloadService().getDirectoryPath());
      if (!await root.exists()) return result;
      await for (final folder in root.list(followLinks: false)) {
        if (folder is! Directory) continue;
        await for (final entity in folder.list(followLinks: false)) {
          if (entity is! File || !entity.path.toLowerCase().endsWith('.mp4')) {
            continue;
          }
          final metadataFile = File('${entity.path}.json');
          if (!await metadataFile.exists()) continue;
          try {
            final metadata = jsonDecode(await metadataFile.readAsString());
            if (metadata is! Map) continue;
            final itemId = metadata['Id']?.toString();
            if (itemId == null || itemId.isEmpty) continue;
            result.putIfAbsent(itemId, () => []).add(metadataFile);
          } catch (_) {
            // Ignore incomplete or older sidecars; they will not be synced.
          }
        }
      }
    } catch (error) {
      debugPrint('Nie udało się znaleźć metadanych pobranych odcinków: $error');
    }
    return result;
  }

  Future<bool> _writeUserDataToSidecars(
    List<File> sidecars,
    Map<String, dynamic> remoteUserData,
  ) async {
    var changed = false;
    const syncFields = {
      'Played',
      'PlaybackPositionTicks',
      'PlayedPercentage',
      'PlayCount',
      'LastPlayedDate',
      'IsFavorite',
      'UnplayedItemCount',
    };
    for (final file in sidecars) {
      try {
        final data = jsonDecode(await file.readAsString());
        if (data is! Map<String, dynamic>) continue;
        final userData = Map<String, dynamic>.from(
          data['UserData'] as Map? ?? {},
        );
        var fileChanged = false;
        for (final field in syncFields) {
          if (!remoteUserData.containsKey(field)) continue;
          if (userData[field] != remoteUserData[field]) fileChanged = true;
          userData[field] = remoteUserData[field];
        }
        if (!fileChanged) continue;
        data['UserData'] = userData;
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(data),
        );
        changed = true;
      } catch (error) {
        debugPrint('Nie udało się zaktualizować ${file.path}: $error');
      }
    }
    return changed;
  }

  Future<void> syncPending() async {
    if (_isSyncing || _pending.isEmpty) return;
    _isSyncing = true;
    try {
      final credentials = await _storage.getCredentials();
      if (credentials == null) return;
      final api = JellyfinApi();
      await flushPendingPlaybackChanges(
        pending: _pending,
        synchronize: (change) async {
          final position = Duration(
            milliseconds: change['positionMs'] as int? ?? 0,
          );
          return synchronizePlaybackChange(
            change: change,
            reportProgress: () => api.reportPlaybackProgress(
              baseUrl: credentials['baseUrl']!,
              token: credentials['token']!,
              userId: credentials['userId']!,
              itemId: change['itemId'] as String,
              position: position,
              isPaused: true,
              isStopped: change['stopped'] as bool? ?? true,
            ),
            markPlayed: () => api.setPlayed(
              baseUrl: credentials['baseUrl']!,
              token: credentials['token']!,
              userId: credentials['userId']!,
              itemId: change['itemId'] as String,
              played: true,
            ),
          );
        },
        save: _save,
      );
    } catch (error) {
      debugPrint('Synchronizacja postępu odtwarzania nie powiodła się: $error');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _ensureSocketConnected() async {
    if (!_initialized || !_isForeground || _socketConnecting) return;
    _socketConnecting = true;
    try {
      final credentials = await _storage.getCredentials();
      if (credentials == null) return;
      final baseUrl = credentials['baseUrl']!;
      final token = credentials['token']!;
      final userId = credentials['userId']!;
      final credentialsKey = '$baseUrl|$token|$userId';
      if (_socketCredentialsKey == credentialsKey &&
          (_socket?.readyState == WebSocket.open ||
              _socket?.readyState == WebSocket.connecting)) {
        return;
      }
      if (_socket != null) _closeSocket();

      final deviceId = await _getDeviceId();
      final baseUri = Uri.parse(baseUrl);
      final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
      final basePath = baseUri.path.replaceFirst(RegExp(r'/+$'), '');
      final socketUri = baseUri.replace(
        scheme: scheme,
        path: '$basePath/socket',
        queryParameters: {
          ...baseUri.queryParameters,
          'api_key': token,
          'deviceId': deviceId,
        },
      );
      final socket = await WebSocket.connect(socketUri.toString());
      if (!_isForeground) {
        await socket.close(WebSocketStatus.goingAway);
        return;
      }
      _socket = socket;
      _socketCredentialsKey = credentialsKey;
      _socketReconnectAttempts = 0;
      _socketReconnectTimer?.cancel();
      _socketKeepAliveTimer?.cancel();
      _socketKeepAliveTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (socket.readyState == WebSocket.open) {
          socket.add(jsonEncode({'MessageType': 'KeepAlive'}));
        }
      });
      _socketSubscription = socket.listen(
        (message) {
          _socketMessageQueue = _socketMessageQueue
              .then((_) => _handleSocketMessage(message, userId))
              .catchError((Object error) {
                debugPrint(
                  'Nie udało się obsłużyć wiadomości Jellyfin: $error',
                );
              });
        },
        onError: (_) => _onSocketEnded(socket),
        onDone: () => _onSocketEnded(socket),
        cancelOnError: true,
      );
    } catch (error) {
      debugPrint('Nie udało się połączyć z kanałem Jellyfin.');
      _scheduleSocketReconnect();
    } finally {
      _socketConnecting = false;
    }
  }

  void _closeSocket() {
    final socket = _socket;
    _socket = null;
    _socketCredentialsKey = null;
    _socketKeepAliveTimer?.cancel();
    _socketKeepAliveTimer = null;
    unawaited(_socketSubscription?.cancel());
    _socketSubscription = null;
    if (socket != null) unawaited(socket.close(WebSocketStatus.goingAway));
  }

  void _onSocketEnded(WebSocket socket) {
    if (!identical(_socket, socket)) return;
    _socket = null;
    _socketCredentialsKey = null;
    _socketKeepAliveTimer?.cancel();
    _socketKeepAliveTimer = null;
    _socketSubscription = null;
    _scheduleSocketReconnect();
  }

  void _scheduleSocketReconnect() {
    if (!_initialized || !_isForeground || _socketReconnectTimer != null) {
      return;
    }
    final seconds = min(60, 2 << min(_socketReconnectAttempts, 5));
    _socketReconnectAttempts++;
    _socketReconnectTimer = Timer(Duration(seconds: seconds), () {
      _socketReconnectTimer = null;
      unawaited(_ensureSocketConnected());
    });
  }

  Future<void> _handleSocketMessage(dynamic message, String userId) async {
    try {
      final decoded = jsonDecode(message.toString());
      if (decoded is! Map || decoded['MessageType'] != 'UserDataChanged') {
        return;
      }
      final payload = decoded['Data'];
      if (payload is! Map || payload['UserId']?.toString() != userId) return;
      final entries = payload['UserDataList'];
      if (entries is! List) return;

      var filesByItemId = _downloadedMetadataFiles;
      var refreshedIndexAfterMiss = false;
      for (final entry in entries) {
        if (entry is! Map) continue;
        final itemId = entry['ItemId']?.toString();
        if (itemId == null || itemId.isEmpty || _pending.containsKey(itemId)) {
          continue;
        }
        _socketRevisions.update(
          itemId,
          (revision) => revision + 1,
          ifAbsent: () => 1,
        );
        filesByItemId ??= await _scanDownloadedMetadataFiles();
        if (!filesByItemId.containsKey(itemId) && !refreshedIndexAfterMiss) {
          // A download may have completed since the last index was built.
          filesByItemId = await _scanDownloadedMetadataFiles();
          _downloadedMetadataFiles = filesByItemId;
          refreshedIndexAfterMiss = true;
        }
        final sidecars = filesByItemId[itemId];
        if (sidecars == null || sidecars.isEmpty) continue;
        if (await _writeUserDataToSidecars(
          sidecars,
          Map<String, dynamic>.from(entry),
        )) {
          downloadedMetadataRevision.value++;
        }
      }
      _downloadedMetadataFiles ??= filesByItemId;
    } catch (error) {
      debugPrint('Nie udało się zastosować zmiany Jellyfin UserData: $error');
    }
  }

  Future<String> _getDeviceId() async {
    final existing = await _storage.getString(_deviceIdStorageKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final id = List<int>.generate(
      32,
      (_) => random.nextInt(16),
    ).map((digit) => digit.toRadixString(16)).join();
    await _storage.saveString(_deviceIdStorageKey, id);
    return id;
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _socketReconnectTimer?.cancel();
    _socketReconnectTimer = null;
    onAppPaused();
    _initialized = false;
  }

  Future<void> _save() =>
      _storage.saveString(_storageKey, jsonEncode(_pending));
}
