import 'jellyfin_item.dart';

class Episode extends JellyfinItem {
  Episode({
    required super.id,
    required super.name,
    super.overview,
    required super.indexNumber,
    required super.parentIndexNumber,
    super.seriesName,
    super.seriesId,
    super.runTimeTicks,
    super.userData,
  }) : super(type: "Episode");

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['Id'],
      name: json['Name'],
      overview: json['Overview'],
      indexNumber: json['IndexNumber'] ?? 0,
      parentIndexNumber: json['ParentIndexNumber'] ?? 0,
      seriesName: json['SeriesName'],
      seriesId: json['SeriesId'],
      runTimeTicks: json['RunTimeTicks'],
      userData: json['UserData'] != null ? UserData.fromJson(json['UserData']) : null,
    );
  }
}