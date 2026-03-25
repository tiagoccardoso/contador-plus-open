
class Episode {
  final String id;
  final String name;
  final DateTime releaseDate;
  final String externalUrl;

  Episode({
    required this.id,
    required this.name,
    required this.releaseDate,
    required this.externalUrl,
  });

  factory Episode.fromJson(Map<String, dynamic> j) {
    return Episode(
      id: j['id'] as String,
      name: j['name'] as String,
      releaseDate: DateTime.parse(j['release_date'] as String),
      externalUrl: (j['external_urls']?['spotify'] ?? '') as String,
    );
  }
}
