class Library {
  final String id;
  final String name;
  final String type;

  Library({required this.id, required this.name, required this.type});

  factory Library.fromJson(Map<String, dynamic> json) {
    return Library(
      id: json['Id'],
      name: json['Name'],
      type: json['CollectionType'] ?? "Mixed",
    );
  }
}
