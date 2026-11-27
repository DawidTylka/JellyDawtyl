import 'dart:io';

import 'package:dio/dio.dart';
import '../models/movie.dart';
import '../models/library.dart';
import '../models/episode.dart';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';
import '../utils/jellyfin_auth.dart';

String _redactedNetworkError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    return status == null
        ? 'DioException (${error.type.name})'
        : 'DioException (${error.type.name}, HTTP $status)';
  }
  return error.runtimeType.toString();
}

/// Raised when the server rejects the saved access token (HTTP 401/403).
class JellyfinUnauthorizedException implements Exception {
  const JellyfinUnauthorizedException();
  @override
  String toString() => 'JellyfinUnauthorizedException';
}

/// Raised when the server cannot be reached (no network, timeout, DNS, TLS).
class JellyfinUnreachableException implements Exception {
  const JellyfinUnreachableException();
  @override
  String toString() => 'JellyfinUnreachableException';
}

/// Reason a login attempt failed, so the login screen can say what happened.
enum LoginFailure { invalidCredentials, unreachable, certificate, server }

class LoginResult {
  final Map<String, dynamic>? data;
  final LoginFailure? failure;
  const LoginResult.success(Map<String, dynamic> this.data) : failure = null;
  const LoginResult.failure(LoginFailure this.failure) : data = null;
  bool get isSuccess => data != null;
}

/// Shared timeouts: without them a request to an unreachable server can
/// hang for minutes behind a modal loading dialog.
final BaseOptions jellyfinDioOptions = BaseOptions(
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 30),
);

class JellyfinApi {
  final Dio _dio = Dio(jellyfinDioOptions);

  Future<LoginResult> loginWithResult(
    String url,
    String username,
    String password,
  ) async {
    try {
      // Jellyfin binds the issued token to DeviceId, so every installation
      // needs its own persistent identifier. It is sent only here: sessions
      // that already hold a token are not affected by the change.
      final deviceId = await StorageService().getDeviceId();
      final response = await _dio.post(
        "$url/Users/AuthenticateByName",
        data: {"Username": username, "Pw": password},
        options: Options(
          headers: {
            jellyfinAuthHeader: jellyfinLoginAuthorization(deviceId: deviceId),
          },
        ),
      );
      final data = response.data;
      if (data is Map && data['AccessToken'] is String) {
        return LoginResult.success(Map<String, dynamic>.from(data));
      }
      return const LoginResult.failure(LoginFailure.server);
    } catch (e) {
      debugPrint('Błąd logowania (${_redactedNetworkError(e)}).');
      return LoginResult.failure(classifyLoginError(e));
    }
  }

  @visibleForTesting
  static LoginFailure classifyLoginError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        return LoginFailure.invalidCredentials;
      }
      if (error.type == DioExceptionType.badCertificate ||
          error.error is HandshakeException) {
        return LoginFailure.certificate;
      }
      if (status == null) return LoginFailure.unreachable;
    }
    return LoginFailure.server;
  }

  /// Ends the session on the server, so the token stops working there too.
  /// Failures are ignored: the app forgets the token either way.
  Future<void> logout(String baseUrl, String token) async {
    try {
      await _dio.post(
        '$baseUrl/Sessions/Logout',
        options: Options(
          headers: jellyfinAuthHeaders(token),
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      debugPrint('Błąd wylogowania na serwerze (${_redactedNetworkError(e)}).');
    }
  }

  // A. Pobiera główne biblioteki
  Future<List<Library>> fetchUserLibraries(
    String url,
    String token,
    String userId,
  ) async {
    try {
      return await fetchUserLibrariesOrThrow(url, token, userId);
    } catch (e) {
      debugPrint('Błąd bibliotek (${_redactedNetworkError(e)}).');
      return [];
    }
  }

  /// Like [fetchUserLibraries], but tells an expired token
  /// ([JellyfinUnauthorizedException]) apart from a server that cannot be
  /// reached ([JellyfinUnreachableException]).
  Future<List<Library>> fetchUserLibrariesOrThrow(
    String url,
    String token,
    String userId,
  ) async {
    try {
      final response = await _dio.get(
        "$url/UserViews",
        queryParameters: {"UserId": userId},
        options: Options(headers: jellyfinAuthHeaders(token)),
      );
      final List<dynamic> data = response.data['Items'] ?? [];
      return data
          .where((item) {
            final type = item['CollectionType'];

            const allowedTypes = [
              'movies',
              'tvshows',
              'boxsets',
              'homevideos',
              'folders',
            ];

            return allowedTypes.contains(type) || type == null;
          })
          .map((l) => Library.fromJson(l))
          .toList();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // Only 401 means the token is gone. A 403 often comes from a proxy,
      // a WAF or an access schedule, and must not wipe a valid login.
      if (status == 401) throw const JellyfinUnauthorizedException();
      if (status == null || status == 403) {
        throw const JellyfinUnreachableException();
      }
      rethrow;
    }
  }

  // B. Pobiera "Kontynuuj oglądanie"
  // Parametry jak w kliencie webowym: tylko wideo, limit 12 pozycji.
  Future<List<Movie>> fetchResumeItems(
    String url,
    String token,
    String userId, {
    String? parentId,
    int limit = 12,
  }) async {
    try {
      final response = await _dio.get(
        "$url/UserItems/Resume",
        queryParameters: {
          "UserId": userId,
          "Limit": limit,
          "MediaTypes": "Video",
          "EnableTotalRecordCount": false,
          "ParentId": ?parentId,
          "Fields": "PrimaryImageAspectRatio,UserData,RunTimeTicks",
        },
        options: Options(headers: jellyfinAuthHeaders(token)),
      );
      final List<dynamic> data = response.data['Items'] ?? [];
      return data.map((m) => Movie.fromJson(m)).toList();
    } catch (e) {
      debugPrint('Błąd Resume (${_redactedNetworkError(e)}).');
      return [];
    }
  }

  // C. Pobiera "Ostatnio dodane"
  Future<List<Movie>> fetchLatestItems(
    String url,
    String token,
    String userId,
    String libraryId,
  ) async {
    try {
      final response = await _dio.get(
        "$url/Items/Latest",
        queryParameters: {
          "UserId": userId,
          "ParentId": libraryId,
          "Fields": "PrimaryImageAspectRatio,UserData,RunTimeTicks",
        },
        options: Options(headers: jellyfinAuthHeaders(token)),
      );
      final List<dynamic> data = response.data ?? [];
      return data.map((m) => Movie.fromJson(m)).toList();
    } catch (e) {
      debugPrint('Błąd Latest (${_redactedNetworkError(e)}).');
      return [];
    }
  }

  // D. Pobiera zawartość biblioteki stronami (Limit/StartIndex)
  Future<List<Movie>> fetchAllInLibrary(
    String url,
    String token,
    String userId,
    String libraryId, {
    int startIndex = 0,
    int limit = libraryPageSize,
    String? searchTerm,
  }) async {
    // Errors reach the caller: an empty page would look like the end of the
    // library and stop paging.
    final response = await _dio.get(
      "$url/Items",
      queryParameters: {
        "UserId": userId,
        "ParentId": libraryId,
        "Recursive": true,
        "IncludeItemTypes": "Movie,Series",
        "Fields": "PrimaryImageAspectRatio,Type,UserData,RunTimeTicks",
        "SortBy": "SortName",
        "SortOrder": "Ascending",
        "StartIndex": startIndex,
        "Limit": limit,
        "SearchTerm": ?searchTerm,
        "EnableTotalRecordCount": false,
      },
      options: Options(headers: jellyfinAuthHeaders(token)),
    );

    final List<dynamic> data = response.data['Items'] ?? [];
    return data.map((m) => Movie.fromJson(m)).toList();
  }

  static const int libraryPageSize = 100;

  Future<List<Episode>> fetchEpisodes(
    String url,
    String token,
    String userId,
    String seriesId,
  ) async {
    try {
      final response = await _dio.get(
        "$url/Shows/$seriesId/Episodes",
        queryParameters: {
          "UserId": userId,
          "Fields": "Overview,PrimaryImageAspectRatio,UserData,RunTimeTicks",
        },
        options: Options(headers: jellyfinAuthHeaders(token)),
      );
      final List<dynamic> data = response.data['Items'] ?? [];
      return data.map((e) => Episode.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Błąd pobierania odcinków (${_redactedNetworkError(e)}).');
      return [];
    }
  }

  /// Reports playback to `/Sessions/Playing` (start), `/Progress` or
  /// `/Stopped`. [playSessionId] ties the reports to a transcoding job so the
  /// server can stop ffmpeg as soon as the session ends.
  Future<bool> reportPlaybackProgress({
    required String baseUrl,
    required String token,
    required String userId,
    required String itemId,
    required Duration position,
    required bool isPaused,
    required bool isStopped,
    bool isStart = false,
    String? playSessionId,
    String? mediaSourceId,
    String? playMethod,
  }) async {
    final int ticks = position.inMicroseconds * 10;
    final String url = isStart
        ? "$baseUrl/Sessions/Playing"
        : "$baseUrl/Sessions/Playing/${isStopped ? 'Stopped' : 'Progress'}";

    try {
      await _dio.post(
        url,
        data: {
          "ItemId": itemId,
          "PositionTicks": ticks,
          "IsPaused": isPaused,
          "CanSeek": true,
          "PlaySessionId": ?playSessionId,
          "MediaSourceId": ?mediaSourceId,
          "PlayMethod": ?playMethod,
        },
        options: Options(headers: jellyfinAuthHeaders(token)),
      );
      return true;
    } catch (e) {
      debugPrint('Błąd raportowania postępu (${_redactedNetworkError(e)}).');
      return false;
    }
  }

  /// Skippable segments (intro, credits, recap, preview, commercial) of an
  /// item. Jellyfin 10.10+ serves them at `/MediaSegments/{id}`, filled by
  /// the Intro Skipper plugin among others. Older Intro Skipper versions
  /// only expose `/Episode/{id}/IntroSkipperSegments`, used as a fallback.
  /// Returns raw JSON maps as stored in download sidecars; parse them with
  /// `MediaSegment.listFromJson`.
  Future<List<Map<String, dynamic>>> fetchMediaSegments({
    required String baseUrl,
    required String token,
    required String itemId,
  }) async {
    final options = Options(
      headers: jellyfinAuthHeaders(token),
      receiveTimeout: const Duration(seconds: 10),
    );
    try {
      final response = await _dio.get(
        '$baseUrl/MediaSegments/$itemId',
        options: options,
      );
      final items = (response.data is Map) ? response.data['Items'] : null;
      if (items is List && items.isNotEmpty) {
        return items
            .whereType<Map<dynamic, dynamic>>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (e) {
      debugPrint('Brak segmentów MediaSegments (${_redactedNetworkError(e)}).');
    }
    try {
      final response = await _dio.get(
        '$baseUrl/Episode/$itemId/IntroSkipperSegments',
        options: options,
      );
      final data = response.data;
      if (data is Map) return introSkipperToMediaSegments(data);
    } catch (e) {
      debugPrint('Brak segmentów Intro Skipper (${_redactedNetworkError(e)}).');
    }
    return [];
  }

  /// Converts the legacy Intro Skipper answer (seconds, keyed by analysis
  /// mode) to the `/MediaSegments` shape (ticks, `Type`).
  @visibleForTesting
  static List<Map<String, dynamic>> introSkipperToMediaSegments(
    Map<dynamic, dynamic> data,
  ) {
    const types = {
      'introduction': 'Intro',
      'intro': 'Intro',
      'credits': 'Outro',
      'outro': 'Outro',
      'recap': 'Recap',
      'preview': 'Preview',
      'commercial': 'Commercial',
    };
    final result = <Map<String, dynamic>>[];
    data.forEach((key, value) {
      final type = types[key.toString().toLowerCase()];
      if (type == null || value is! Map) return;
      if (value['Valid'] == false) return;
      final start = value['IntroStart'] ?? value['Start'];
      final end = value['IntroEnd'] ?? value['End'];
      if (start is! num || end is! num || end <= start) return;
      result.add({
        'Type': type,
        'StartTicks': (start * 10000000).round(),
        'EndTicks': (end * 10000000).round(),
      });
    });
    return result;
  }

  /// Fetches only the per-user playback data for a bounded set of known items.
  /// This is used to reconcile downloaded metadata without enumerating a library.
  Future<List<Map<String, dynamic>>> fetchUserDataForItems({
    required String baseUrl,
    required String token,
    required String userId,
    required List<String> itemIds,
  }) async {
    if (itemIds.isEmpty) return [];
    try {
      final response = await _dio.get(
        '$baseUrl/Items',
        queryParameters: {
          'UserId': userId,
          'Ids': itemIds.join(','),
          'Fields': 'UserData',
          'EnableImages': false,
          'EnableTotalRecordCount': false,
        },
        options: Options(headers: jellyfinAuthHeaders(token)),
      );
      final items = (response.data as Map?)?['Items'];
      if (items is! List) return [];
      return items
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (error) {
      debugPrint(
        'Błąd odświeżania statusów pobranych pozycji (${_redactedNetworkError(error)}).',
      );
      return [];
    }
  }

  Future<String?> fetchSeriesName(
    String baseUrl,
    String token,
    String seriesId,
  ) async {
    try {
      final response = await _dio.get(
        "$baseUrl/Items/$seriesId",
        options: Options(headers: jellyfinAuthHeaders(token)),
      );
      return response.data['Name'];
    } catch (e) {
      debugPrint(
        'Błąd pobierania nazwy serialu (${_redactedNetworkError(e)}).',
      );
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchItemMediaInfo(
    String baseUrl,
    String token,
    String itemId,
  ) async {
    try {
      final response = await _dio.get(
        "$baseUrl/Items/$itemId",
        queryParameters: {
          "Fields": "MediaStreams,MediaSources,Width,Height,Bitrate",
        },
        options: Options(headers: jellyfinAuthHeaders(token)),
      );

      final data = response.data as Map<String, dynamic>?;
      if (data == null) return null;

      int? width = data['Width'] as int?;
      int? height = data['Height'] as int?;
      int? bitrate = data['Bitrate'] as int?;

      if ((width == null || height == null || bitrate == null) &&
          data['MediaSources'] != null) {
        final sources = data['MediaSources'] as List<dynamic>?;
        if (sources != null && sources.isNotEmpty) {
          final first = sources.first as Map<String, dynamic>?;
          width ??= first?['Width'] as int?;
          height ??= first?['Height'] as int?;
          bitrate ??= first?['Bitrate'] as int?;
        }
      }

      if ((width == null || height == null || bitrate == null) &&
          data['MediaStreams'] != null) {
        final streams = data['MediaStreams'] as List<dynamic>?;
        if (streams != null) {
          final videoStream = streams.cast<Map<String, dynamic>?>().firstWhere(
            (s) => s != null && s['Type'] == 'Video',
            orElse: () => null,
          );
          if (videoStream != null) {
            width ??= videoStream['Width'] as int?;
            height ??= videoStream['Height'] as int?;
            bitrate ??= videoStream['Bitrate'] as int?;
          }
        }
      }

      return {
        'Width': width,
        'Height': height,
        'Bitrate': bitrate,
        'raw': data,
      };
    } catch (e) {
      debugPrint('Błąd pobierania mediów (${_redactedNetworkError(e)}).');
      return null;
    }
  }

  /// Pobiera listę strumieni napisów dla danego odcinka/filmu
  Future<List<Map<String, dynamic>>> fetchSubtitleStreams(
    String baseUrl,
    String token,
    String itemId,
  ) async {
    try {
      final response = await _dio.get(
        "$baseUrl/Items/$itemId",
        queryParameters: {"Fields": "MediaSources"},
        options: Options(headers: jellyfinAuthHeaders(token)),
      );

      final data = response.data as Map<String, dynamic>?;
      if (data == null) return [];

      final sources = data['MediaSources'] as List<dynamic>?;
      if (sources == null || sources.isEmpty) return [];

      final streams = sources.first['MediaStreams'] as List<dynamic>?;
      if (streams == null) return [];

      return streams
          .cast<Map<String, dynamic>>()
          .where((s) => s['Type'] == 'Subtitle')
          .toList();
    } catch (e) {
      debugPrint(
        'Błąd pobierania strumieni napisów (${_redactedNetworkError(e)}).',
      );
      rethrow;
    }
  }

  // E. Pobiera "Następne w kolejce" (tylko dla seriali)
  // Parametry jak w kliencie webowym: limit 24, bez pozycji z "Kontynuuj
  // oglądanie" i bez seriali nieoglądanych od ponad roku.
  Future<List<Movie>> fetchNextUp(
    String url,
    String token,
    String userId, {
    String? parentId,
    int limit = 24,
  }) async {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 365));
    try {
      final response = await _dio.get(
        "$url/Shows/NextUp",
        queryParameters: {
          "UserId": userId,
          "Limit": limit,
          "Fields":
              "PrimaryImageAspectRatio,Overview,Type,UserData,RunTimeTicks",
          "EnableResumable": false,
          "EnableTotalRecordCount": false,
          "NextUpDateCutoff": cutoff.toIso8601String(),
          "ParentId": ?parentId,
        },
        options: Options(headers: jellyfinAuthHeaders(token)),
      );

      final List<dynamic> data = response.data['Items'] ?? [];
      return data.map((m) => Movie.fromJson(m)).toList();
    } catch (e) {
      debugPrint('Błąd NextUp (${_redactedNetworkError(e)}).');
      return [];
    }
  }

  /// Favorites with what the favorites screen sorts and groups by.
  Future<List<Movie>> fetchFavoritesOrThrow(
    String url,
    String token,
    String userId, {
    String sortBy = 'SortName',
    String sortOrder = 'Ascending',
  }) async {
    final response = await _dio.get<dynamic>(
      "$url/Items",
      queryParameters: {
        "UserId": userId,
        "Recursive": true,
        "Filters": "IsFavorite",
        "IncludeItemTypes": "Movie,Series,Episode",
        "Fields":
            "PrimaryImageAspectRatio,Overview,Type,UserData,RunTimeTicks,DateCreated",
        "SortBy": sortBy,
        "SortOrder": sortOrder,
      },
      options: Options(headers: jellyfinAuthHeaders(token)),
    );
    final List<dynamic> data = (response.data as Map?)?['Items'] ?? [];
    return data
        .map((m) => Movie.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<bool> setFavorite({
    required String baseUrl,
    required String token,
    required String userId,
    required String itemId,
    required bool isFavorite,
  }) async {
    final url = '$baseUrl/UserFavoriteItems/$itemId';
    final query = {'UserId': userId};

    try {
      final options = Options(headers: jellyfinAuthHeaders(token));
      if (isFavorite) {
        await _dio.post(url, queryParameters: query, options: options);
      } else {
        await _dio.delete(url, queryParameters: query, options: options);
      }
      return true;
    } catch (e) {
      debugPrint('Błąd aktualizacji ulubionych (${_redactedNetworkError(e)}).');
      return false;
    }
  }

  Future<bool> setPlayed({
    required String baseUrl,
    required String token,
    required String userId,
    required String itemId,
    required bool played,
  }) async {
    final url = '$baseUrl/UserPlayedItems/$itemId';
    final query = {'UserId': userId};

    try {
      final options = Options(headers: jellyfinAuthHeaders(token));
      if (played) {
        await _dio.post(url, queryParameters: query, options: options);
      } else {
        await _dio.delete(url, queryParameters: query, options: options);
      }
      return true;
    } catch (e) {
      debugPrint(
        'Błąd aktualizacji stanu obejrzenia (${_redactedNetworkError(e)}).',
      );
      return false;
    }
  }

  /// Everything the details screen shows: the single-item endpoint returns
  /// people, genres, chapters and media sources without extra fields.
  Future<Map<String, dynamic>?> fetchItemDetails({
    required String baseUrl,
    required String token,
    required String userId,
    required String itemId,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '$baseUrl/Items/$itemId',
        queryParameters: {'UserId': userId},
        options: Options(headers: jellyfinAuthHeaders(token)),
      );
      final data = response.data;
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } catch (e) {
      debugPrint('Błąd szczegółów pozycji (${_redactedNetworkError(e)}).');
      return null;
    }
  }

  /// The episodes before and after [episodeId] (the server returns up to
  /// three: previous, this one and next).
  Future<List<Episode>> fetchAdjacentEpisodes({
    required String baseUrl,
    required String token,
    required String userId,
    required String seriesId,
    required String episodeId,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '$baseUrl/Shows/$seriesId/Episodes',
        queryParameters: {
          'UserId': userId,
          'AdjacentTo': episodeId,
          'Fields': 'Overview',
        },
        options: Options(headers: jellyfinAuthHeaders(token)),
      );
      final items = (response.data as Map?)?['Items'];
      if (items is! List) return const [];
      return items
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => Episode.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Błąd sąsiednich odcinków (${_redactedNetworkError(e)}).');
      return const [];
    }
  }

  /// Searches the whole server (all libraries) for movies, series and
  /// episodes.
  Future<List<Movie>> searchItems({
    required String baseUrl,
    required String token,
    required String userId,
    required String query,
    String? parentId,
    int limit = 60,
  }) async {
    final response = await _dio.get<dynamic>(
      '$baseUrl/Items',
      queryParameters: {
        'UserId': userId,
        'SearchTerm': query,
        'ParentId': ?parentId,
        'Recursive': true,
        'IncludeItemTypes': 'Movie,Series,Episode',
        'Fields': 'PrimaryImageAspectRatio,Overview,UserData,RunTimeTicks',
        'Limit': limit,
        'EnableTotalRecordCount': false,
      },
      options: Options(headers: jellyfinAuthHeaders(token)),
    );
    final items = (response.data as Map?)?['Items'];
    if (items is! List) return const [];
    return items
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => Movie.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
}
