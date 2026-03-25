import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class EpisodesTab extends StatefulWidget {
  final void Function(Map<String, dynamic> episode) onEpisodeSelected;
  const EpisodesTab({super.key, required this.onEpisodeSelected});

  @override
  State<EpisodesTab> createState() => _EpisodesTabState();
}

class _EpisodesTabState extends State<EpisodesTab> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchEpisodes();
  }

  Future<List<Map<String, dynamic>>> _fetchEpisodes() async {
    final clientId = dotenv.env['SPOTIFY_CLIENT_ID'] ?? '';
    final clientSecret = dotenv.env['SPOTIFY_CLIENT_SECRET'] ?? '';
    final showId = dotenv.env['SPOTIFY_SHOW_ID'] ?? '';

    if (clientId.isEmpty || clientSecret.isEmpty || showId.isEmpty) {
      throw Exception('Credenciais/SHOW_ID ausentes no .env');
    }

    final basic = base64Encode(utf8.encode('$clientId:$clientSecret'));
    final tokenRes = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Authorization': 'Basic $basic',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'grant_type': 'client_credentials'},
    );
    final tokenJson = jsonDecode(tokenRes.body);
    final token = tokenJson['access_token'];

    final res = await http.get(
      Uri.parse('https://api.spotify.com/v1/shows/$showId/episodes?market=BR'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(res.body);
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Erro ao carregar episódios: ${snap.error}'),
            ),
          );
        }
        final episodes = snap.data ?? <Map<String, dynamic>>[];
        if (episodes.isEmpty) {
          return const Center(child: Text('Nenhum episódio disponível.'));
        }

        return ListView.separated(
          itemCount: episodes.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final e = episodes[i];
            final title = e['name'] ?? 'Episódio';
            final images = (e['images'] as List?) ?? const [];
            final imageUrl = images.isNotEmpty ? images.first['url'] as String? : null;
            final releaseDate = e['release_date'] ?? '';
            return ListTile(
              leading: imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(imageUrl, width: 48, height: 48, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.podcasts),
              title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: releaseDate.isNotEmpty ? Text(releaseDate) : null,
              onTap: () => widget.onEpisodeSelected(e),
              trailing: const Icon(Icons.chevron_right),
            );
          },
        );
      },
    );
  }
}
