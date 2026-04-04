import 'jellyfin_item.dart';

class Movie extends JellyfinItem {
  Movie({
    required super.id,
    required super.name,
    super.overview,
    required super.type,
    super.indexNumber,
    super.parentIndexNumber,
    super.seriesName,
    super.seriesId,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['Id'],
      name: json['Name'],
      overview: json['Overview'],
      type: json['Type'] ?? "Movie",
      indexNumber: json['IndexNumber'],
      parentIndexNumber: json['ParentIndexNumber'],
      seriesName: json['SeriesName'],
      seriesId: json['SeriesId'],
    );
  }
}
