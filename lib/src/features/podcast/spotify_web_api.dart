
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'auth/spotify_pkce.dart';
import 'episode_model.dart';

class SpotifyWebApi {
  final SpotifyAuthRepository _auth;
  SpotifyWebApi(this._auth);

  String get showId => dotenv.env['SPOTIFY_SHOW_ID'] ?? '36pSkw1EtZgTnNrXmJcNPm';

  Future<List<Episode>> fetchEpisodes({int limit = 50}) async {
    final token = await _auth.getValidAccessToken();
    if (token == null) {
      throw 'Não autenticado no Spotify.';
    }
    final uri = Uri.https('api.spotify.com', '/v1/shows/$showId/episodes', {
      'market': 'BR',
      'limit': '$limit',
    });

    final resp = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (resp.statusCode != 200) {
      throw 'Falha ao buscar episódios (${resp.statusCode})';
    }

    final map = json.decode(resp.body) as Map<String, dynamic>;
    final items = (map['items'] as List).cast<Map<String, dynamic>>();
    return items.map((j) => Episode.fromJson(j)).toList();
  }
}
