// lib/src/features/podcast/episode.dart
class Episode {
  final String id;
  final String name;
  final String description;
  final String releaseDate; // ISO yyyy-MM-dd
  final int durationMs;
  final String imageUrl;
  final String url; // link open.spotify.com/episode/...

  Episode({
    required this.id,
    required this.name,
    required this.description,
    required this.releaseDate,
    required this.durationMs,
    required this.imageUrl,
    required this.url,
  });

  factory Episode.fromSpotify(Map<String, dynamic> j) => Episode(
        id: j['id'],
        name: j['name'] ?? '',
        description: j['description'] ?? '',
        releaseDate: j['release_date'] ?? '',
        durationMs: j['duration_ms'] ?? 0,
        imageUrl: (j['images'] as List?)?.isNotEmpty == true ? j['images'][0]['url'] : '',
        url: (j['external_urls']?['spotify']) ?? 'https://open.spotify.com/episode/${j['id']}',
      );
}