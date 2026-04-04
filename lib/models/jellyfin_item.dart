abstract class JellyfinItem {
  final String id;
  final String name;
  final String type;
  final String? overview;
  final int? indexNumber;
  final int? parentIndexNumber;
  final String? seriesName;
  final String? seriesId;

  JellyfinItem({
    required this.id,
    required this.name,
    required this.type,
    this.overview,
    this.indexNumber,
    this.parentIndexNumber,
    this.seriesName,
    this.seriesId,
  });
}
