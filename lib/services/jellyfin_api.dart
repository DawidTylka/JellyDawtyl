import 'package:dio/dio.dart';
import '../models/movie.dart';
import '../models/library.dart';
import '../models/episode.dart';

class JellyfinApi {
  final Dio _dio = Dio();

  Future<Map<String, dynamic>?> login(
    String url,
    String username,
    String password,
  ) async {
    String fullUrl = url.startsWith('http') ? url : 'https://$url';

    try {
      final response = await _dio.post(
        "$fullUrl/Users/AuthenticateByName",
        data: {"Username": username, "Pw": password},
        options: Options(
          headers: {
            "X-Emby-Authorization":
                'MediaBrowser Client="MyJellyApp", Device="Phone", DeviceId="123", Version="1.0.0"',
          },
        ),
      );
      return response.data;
    } catch (e) {
      print("Błąd logowania: $e");
      return null;
    }
  }

  // A. Pobiera główne biblioteki
  Future<List<Library>> fetchUserLibraries(
    String url,
    String token,
    String userId,
  ) async {
    String fullUrl = url.startsWith('http') ? url : 'https://$url';
    try {
      final response = await _dio.get(
        "$fullUrl/Users/$userId/Views",
        options: Options(headers: {"X-Emby-Token": token}),
      );
      final List data = response.data['Items'] ?? [];
      return data
          .where(
            (item) =>
                item['CollectionType'] != 'music' &&
                item['CollectionType'] != 'audiobooks' &&
                item['CollectionType'] != 'books',
          )
          .map((l) => Library.fromJson(l))
          .toList();
    } catch (e) {
      print("Błąd bibliotek: $e");
      return [];
    }
  }

  // B. Pobiera "Kontynuuj oglądanie"
  Future<List<Movie>> fetchResumeItems(
    String url,
    String token,
    String userId,
  ) async {
    String fullUrl = url.startsWith('http') ? url : 'https://$url';
    try {
      final response = await _dio.get(
        "$fullUrl/Users/$userId/Items/Resume",
        queryParameters: {
          "Recursive": true,
          "Fields": "PrimaryImageAspectRatio",
        },
        options: Options(headers: {"X-Emby-Token": token}),
      );
      final List data = response.data['Items'] ?? [];
      return data.map((m) => Movie.fromJson(m)).toList();
    } catch (e) {
      print("Błąd Resume: $e");
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
    String fullUrl = url.startsWith('http') ? url : 'https://$url';
    try {
      final response = await _dio.get(
        "$fullUrl/Users/$userId/Items/Latest",
        queryParameters: {
          "ParentId": libraryId,
          "Fields": "PrimaryImageAspectRatio",
        },
        options: Options(headers: {"X-Emby-Token": token}),
      );
      final List data = response.data ?? [];
      return data.map((m) => Movie.fromJson(m)).toList();
    } catch (e) {
      print("Błąd Latest: $e");
      return [];
    }
  }

  // D. Pobiera WSZYSTKO w bibliotece
  Future<List<Movie>> fetchAllInLibrary(
    String url,
    String token,
    String userId,
    String libraryId,
  ) async {
    String fullUrl = url.startsWith('http') ? url : 'https://$url';
    try {
      final response = await _dio.get(
        "$fullUrl/Users/$userId/Items",
        queryParameters: {
          "ParentId": libraryId,
          "Recursive": true,
          "IncludeItemTypes": "Movie,Series",
          "Fields": "PrimaryImageAspectRatio,Overview,Type",
          "SortBy": "SortName",
          "SortOrder": "Ascending",
        },
        options: Options(headers: {"X-Emby-Token": token}),
      );

      final List data = response.data['Items'] ?? [];
      return data.map((m) => Movie.fromJson(m)).toList();
    } catch (e) {
      print("Błąd AllInLibrary: $e");
      return [];
    }
  }

  Future<List<Episode>> fetchEpisodes(
    String url,
    String token,
    String userId,
    String seriesId,
  ) async {
    try {
      String fullUrl = url.startsWith('http') ? url : 'https://$url';
      final response = await _dio.get(
        "$fullUrl/Shows/$seriesId/Episodes",
        queryParameters: {
          "UserId": userId,
          "Fields": "Overview,PrimaryImageAspectRatio",
        },
        options: Options(headers: {"X-Emby-Token": token}),
      );
      final List data = response.data['Items'] ?? [];
      return data.map((e) => Episode.fromJson(e)).toList();
    } catch (e) {
      print("Błąd pobierania odcinków: $e");
      return [];
    }
  }

  Future<void> reportPlaybackProgress({
    required String baseUrl,
    required String token,
    required String userId,
    required String itemId,
    required Duration position,
    required bool isPaused,
    required bool isStopped,
  }) async {
    final dio = Dio();
    int ticks = position.inMicroseconds * 10;

    final String action = isStopped
        ? "Stopped"
        : (isPaused ? "Progress" : "Progress");
    final String url = "$baseUrl/Sessions/Playing/$action";

    try {
      await dio.post(
        url,
        data: {"ItemId": itemId, "PositionTicks": ticks, "IsPaused": isPaused},
        options: Options(headers: {"X-Emby-Token": token}),
      );
    } catch (e) {
      print("Błąd raportowania postępu: $e");
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
        options: Options(headers: {"X-Emby-Token": token}),
      );
      return response.data['Name'];
    } catch (e) {
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
        options: Options(headers: {"X-Emby-Token": token}),
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
            (s) => s != null && (s['Type'] == 'Video' || s['Type'] == 'Video'),
            orElse: () => null,
          );
          if (videoStream != null) {
            width ??= videoStream['Width'] as int?;
            height ??= videoStream['Height'] as int?;
            bitrate ??= videoStream['Bitrate'] as int?;
          }
        }
      }

      final meta = {
        'Width': width,
        'Height': height,
        'Bitrate': bitrate,
        'raw': data,
      };
      print('fetchItemMediaInfo: $itemId -> $meta');
      return meta;
    } catch (e) {
      print("Błąd pobierania mediów: $e");
      return null;
    }
  }
}
