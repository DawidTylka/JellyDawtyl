import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/movie.dart';
import 'package:flutter_application_1/widgets/item_artwork.dart';

void main() {
  const base = 'https://jf.example';

  test('episode prefers season poster, then series poster, then own still', () {
    final episode = Movie.fromJson({
      'Id': 'ep',
      'Name': 'Pilot',
      'Type': 'Episode',
      'SeriesId': 'show',
      'SeasonId': 'season1',
    });

    expect(itemArtworkUrls(episode, base, imageType: 'Backdrop'), [
      '$base/Items/season1/Images/Primary?quality=90',
      '$base/Items/show/Images/Primary?quality=90',
      '$base/Items/ep/Images/Primary?quality=90',
    ]);
  });

  test('episode without season id falls back to series poster', () {
    final episode = Movie.fromJson({
      'Id': 'ep',
      'Name': 'Pilot',
      'Type': 'Episode',
      'SeriesId': 'show',
    });

    expect(
      itemArtworkUrls(episode, base).first,
      '$base/Items/show/Images/Primary?quality=90',
    );
  });

  test('movie uses its own image of the requested type', () {
    final movie = Movie.fromJson({'Id': 'm', 'Name': 'Film', 'Type': 'Movie'});

    expect(
      itemArtworkUrls(movie, base, imageType: 'Backdrop', preferSeries: true),
      ['$base/Items/m/Images/Backdrop?quality=90'],
    );
  });
}
