import 'package:flutter_test/flutter_test.dart';
import 'package:jellydawtyl/models/movie.dart';
import 'package:jellydawtyl/widgets/item_artwork.dart';

void main() {
  const base = 'https://jf.example';
  String url(String id, String type) =>
      '$base/Items/$id/Images/$type?quality=90';
  ArtworkCandidate poster(String id) =>
      ArtworkCandidate(url(id, 'Primary'), portrait: true);
  ArtworkCandidate wide(String id, String type) =>
      ArtworkCandidate(url(id, type), portrait: false);

  final episode = Movie.fromJson({
    'Id': 'ep',
    'Name': 'Pilot',
    'Type': 'Episode',
    'SeriesId': 'show',
    'SeasonId': 'season1',
  });

  test('episode in a landscape card prefers landscape season/series art', () {
    expect(itemArtworkCandidates(episode, base, landscape: true), [
      wide('season1', 'Thumb'),
      wide('show', 'Thumb'),
      wide('show', 'Backdrop'),
      poster('season1'),
      poster('show'),
      wide('ep', 'Primary'),
    ]);
  });

  test('episode in a portrait card uses season, then series poster', () {
    expect(itemArtworkCandidates(episode, base), [
      poster('season1'),
      poster('show'),
      wide('ep', 'Primary'),
    ]);
  });

  test('episode without season id starts with the series', () {
    final noSeason = Movie.fromJson({
      'Id': 'ep',
      'Name': 'Pilot',
      'Type': 'Episode',
      'SeriesId': 'show',
    });
    expect(itemArtworkCandidates(noSeason, base).first, poster('show'));
  });

  test('movie uses its own art matched to the card shape', () {
    final movie = Movie.fromJson({'Id': 'm', 'Name': 'Film', 'Type': 'Movie'});
    expect(itemArtworkCandidates(movie, base, landscape: true), [
      wide('m', 'Thumb'),
      wide('m', 'Backdrop'),
      poster('m'),
    ]);
    expect(itemArtworkCandidates(movie, base), [poster('m')]);
  });
}
