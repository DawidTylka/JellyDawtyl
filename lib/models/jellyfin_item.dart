class UserData {
  final int? playbackPositionTicks;
  final bool played;
  final int? unplayedItemCount;

  UserData({
    this.playbackPositionTicks,
    this.played = false,
    this.unplayedItemCount,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      playbackPositionTicks: json['PlaybackPositionTicks'],
      played: json['Played'] ?? false,
      unplayedItemCount: json['UnplayedItemCount'],
    );
  }
}

abstract class JellyfinItem {
  final String id;
  final String name;
  final String type;
  final String? overview;
  final int? indexNumber;
  final int? parentIndexNumber;
  final String? seriesName;
  final String? seriesId;
  final int? runTimeTicks;
  final UserData? userData;

  JellyfinItem({
    required this.id,
    required this.name,
    required this.type,
    this.overview,
    this.indexNumber,
    this.parentIndexNumber,
    this.seriesName,
    this.seriesId,
    this.runTimeTicks,
    this.userData,
  });
}
