
// lib/src/features/podcast/spotify_public_api.dart
// Integração 100% client-side usando Client Credentials (sem login).
// Requer as chaves no .env: SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET, SPOTIFY_SHOW_ID (opcional).
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'episode.dart';

class SpotifyPublicApi {
  final String clientId;
  final String clientSecret;
  final String showId;
  final String market;

  const SpotifyPublicApi({
    required this.clientId,
    required this.clientSecret,
    required this.showId,
    this.market = 'BR',
  });

  /// Construtor que lê direto do .env
  factory SpotifyPublicApi.fromEnv() {
    final id = dotenv.env['SPOTIFY_CLIENT_ID'] ?? '';
    final secret = dotenv.env['SPOTIFY_CLIENT_SECRET'] ?? '';
    final show = dotenv.env['SPOTIFY_SHOW_ID'] ?? '36pSkw1EtZgTnNrXmJcNPm';
    if (id.isEmpty || secret.isEmpty) {
      throw StateError('SPOTIFY_CLIENT_ID/SECRET não definidos no .env');
    }
    return SpotifyPublicApi(clientId: id, clientSecret: secret, showId: show);
  }

  Future<String> _getAccessToken() async {
    final auth = base64Encode(utf8.encode('$clientId:$clientSecret'));
    final resp = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Authorization': 'Basic $auth',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'grant_type': 'client_credentials'},
    );
    if (resp.statusCode != 200) {
      throw Exception('Falha ao obter token (${resp.statusCode})');
    }
    final data = json.decode(resp.body) as Map<String, dynamic>;
    return data['access_token'] as String;
  }

  Future<List<Episode>> listEpisodes({int limit = 20, int offset = 0}) async {
    final token = await _getAccessToken();
    final uri = Uri.parse(
      'https://api.spotify.com/v1/shows/$showId/episodes?market=$market&limit=$limit&offset=$offset',
    );
    final r = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (r.statusCode != 200) {
      throw Exception('Falha ${r.statusCode} ao buscar episódios');
    }
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return items.map(Episode.fromSpotify).toList();
  }
}
