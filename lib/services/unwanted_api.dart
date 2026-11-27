import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../utils/jellyfin_auth.dart';
import 'jellyfin_api.dart';

/// Lists of the jellyfin-plugin-unwanted server plugin.
enum UnwantedListKind { unwanted, snoozed, watchLater }

UnwantedListKind? _kindFromJson(Object? value) {
  if (value is int && value >= 0 && value < UnwantedListKind.values.length) {
    return UnwantedListKind.values[value];
  }
  switch (value) {
    case 'Unwanted':
      return UnwantedListKind.unwanted;
    case 'Snoozed':
      return UnwantedListKind.snoozed;
    case 'WatchLater':
      return UnwantedListKind.watchLater;
  }
  return null;
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

/// State of a series or movie. For an episode or a season the plugin answers
/// with the state of its series (target*).
class UnwantedStatus {
  final String itemId;
  final String targetId;
  final String? targetName;
  final String? targetType;
  final bool unwanted;
  final bool snoozed;
  final DateTime? snoozeUntil;
  final bool untilNewEpisode;
  final bool watchLater;

  const UnwantedStatus({
    required this.itemId,
    required this.targetId,
    this.targetName,
    this.targetType,
    this.unwanted = false,
    this.snoozed = false,
    this.snoozeUntil,
    this.untilNewEpisode = false,
    this.watchLater = false,
  });

  /// Snoozing applies to series only, as in the plugin's web client.
  bool get canSnooze => targetType == 'Series';

  factory UnwantedStatus.fromJson(Map<String, dynamic> json) {
    final itemId = json['ItemId']?.toString() ?? '';
    return UnwantedStatus(
      itemId: itemId,
      targetId: json['TargetId']?.toString() ?? itemId,
      targetName: json['TargetName'] as String?,
      targetType: json['TargetType'] as String?,
      unwanted: json['Unwanted'] == true,
      snoozed: json['Snoozed'] == true,
      snoozeUntil: _date(json['SnoozeUntilUtc']),
      untilNewEpisode: json['UntilNewEpisode'] == true,
      watchLater: json['WatchLater'] == true,
    );
  }
}

class UnwantedListEntry {
  final String itemId;
  final String name;
  final String? type;
  final int? productionYear;
  final UnwantedListKind kind;
  final DateTime? added;
  final DateTime? snoozeUntil;
  final bool untilNewEpisode;
  final bool hasPrimaryImage;

  const UnwantedListEntry({
    required this.itemId,
    required this.name,
    required this.kind,
    this.type,
    this.productionYear,
    this.added,
    this.snoozeUntil,
    this.untilNewEpisode = false,
    this.hasPrimaryImage = false,
  });

  static UnwantedListEntry? fromJson(Map<String, dynamic> json) {
    final kind = _kindFromJson(json['Kind']);
    final id = json['ItemId']?.toString();
    if (kind == null || id == null) return null;
    return UnwantedListEntry(
      itemId: id,
      name: json['Name'] as String? ?? '',
      type: json['Type'] as String?,
      productionYear: json['ProductionYear'] as int?,
      kind: kind,
      added: _date(json['AddedUtc']),
      snoozeUntil: _date(json['SnoozeUntilUtc']),
      untilNewEpisode: json['UntilNewEpisode'] == true,
      hasPrimaryImage: json['HasPrimaryImage'] == true,
    );
  }
}

/// Client for `/UnwantedSeries/*`. When the plugin is not installed the
/// server answers 404 and the app simply hides these features.
class UnwantedApi {
  static final UnwantedApi _instance = UnwantedApi._();
  factory UnwantedApi() => _instance;
  UnwantedApi._();

  final Dio _dio = Dio(jellyfinDioOptions);
  final Map<String, Future<bool>> _availability = {};

  /// Bumped after every change, so open screens can refresh their state.
  final ValueNotifier<int> changes = ValueNotifier(0);

  static String _root(String baseUrl) => '$baseUrl/UnwantedSeries';

  /// Whether the server has the plugin. Remembered per server; a network
  /// error is not remembered, so the next screen asks again.
  Future<bool> isAvailable(String baseUrl, String token) {
    return _availability[baseUrl] ??= _probe(baseUrl, token).then((value) {
      if (value == null) _availability.remove(baseUrl);
      return value ?? false;
    });
  }

  Future<bool?> _probe(String baseUrl, String token) async {
    try {
      await _dio.get<dynamic>(
        '${_root(baseUrl)}/Lists',
        options: Options(headers: jellyfinAuthHeaders(token)),
      );
      return true;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 || code == 405) return false;
      return null;
    } catch (_) {
      return null;
    }
  }

  void forgetAvailability() => _availability.clear();

  Future<UnwantedStatus?> fetchStatus(
    String baseUrl,
    String token,
    String itemId,
  ) async {
    if (!await isAvailable(baseUrl, token)) return null;
    try {
      final response = await _dio.get<dynamic>(
        '${_root(baseUrl)}/Status/$itemId',
        options: Options(headers: jellyfinAuthHeaders(token)),
      );
      final data = response.data;
      return data is Map ? UnwantedStatus.fromJson(Map.from(data)) : null;
    } catch (e) {
      // 404: this type is not supported by the plugin (e.g. a music video).
      return null;
    }
  }

  Future<List<UnwantedListEntry>> fetchLists(
    String baseUrl,
    String token,
  ) async {
    final response = await _dio.get<dynamic>(
      '${_root(baseUrl)}/Lists',
      options: Options(headers: jellyfinAuthHeaders(token)),
    );
    final data = response.data;
    if (data is! List) return const [];
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => UnwantedListEntry.fromJson(Map<String, dynamic>.from(e)))
        .whereType<UnwantedListEntry>()
        .toList();
  }

  Future<UnwantedStatus?> _modify(
    String method,
    String baseUrl,
    String token,
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        '${_root(baseUrl)}/$path',
        queryParameters: query,
        options: Options(method: method, headers: jellyfinAuthHeaders(token)),
      );
      changes.value++;
      final data = response.data;
      return data is Map ? UnwantedStatus.fromJson(Map.from(data)) : null;
    } catch (e) {
      debugPrint('Wtyczka Unwanted: błąd $method $path (${e.runtimeType}).');
      rethrow;
    }
  }

  Future<UnwantedStatus?> setUnwanted(
    String baseUrl,
    String token,
    String itemId,
    bool value,
  ) => _modify(value ? 'POST' : 'DELETE', baseUrl, token, 'Unwanted/$itemId');

  Future<UnwantedStatus?> setWatchLater(
    String baseUrl,
    String token,
    String itemId,
    bool value,
  ) => _modify(value ? 'POST' : 'DELETE', baseUrl, token, 'WatchLater/$itemId');

  /// Snoozes for [days], or until a new episode appears.
  Future<UnwantedStatus?> snooze(
    String baseUrl,
    String token,
    String itemId, {
    int? days,
    bool untilNewEpisode = false,
  }) {
    assert((days ?? 0) > 0 || untilNewEpisode);
    return _modify(
      'POST',
      baseUrl,
      token,
      'Snooze/$itemId',
      query: {
        if (days != null && days > 0) 'days': days,
        if (untilNewEpisode) 'untilNewEpisode': true,
      },
    );
  }

  Future<UnwantedStatus?> wake(String baseUrl, String token, String itemId) =>
      _modify('DELETE', baseUrl, token, 'Snooze/$itemId');
}
