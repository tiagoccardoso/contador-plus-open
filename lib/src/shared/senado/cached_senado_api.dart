import '../cache/disk_cache.dart';
import 'senado_api_client.dart';
import 'senado_models.dart';

/// Wrapper com cache em disco (TTL em minutos) sobre o client do Senado.
class CachedSenadoApi {
  final SenadoApiClient _api;
  final DiskCache _cache = DiskCache.instance;

  CachedSenadoApi({SenadoApiClient? api}) : _api = api ?? SenadoApiClient();

  /// Lista senadores em exercício com cache em disco.
  ///
  /// O dataset é relativamente estável durante o dia; 12h é um TTL seguro.
  Future<List<SenadorResumo>> listarSenadoresEmExercicio({
    Duration ttl = const Duration(hours: 12),
    bool noCache = false,
  }) async {
    const key = 'SENADO:lista_senadores_em_exercicio';
    final ttlMinutes = ttl.inMinutes;

    if (!noCache) {
      final cached = await _cache.getJson<Map<String, dynamic>>(key, ttlMinutes: ttlMinutes);
      if (cached != null) {
        return parseSenadoresEmExercicio(cached);
      }
    }

    final raw = await _api.getListaSenadoresEmExercicioRaw();
    await _cache.putJson(key, raw);
    return parseSenadoresEmExercicio(raw);
  }


/// Detalhe do senador (resposta bruta da API), com cache.
Future<Map<String, dynamic>> obterDetalheSenadorRaw(
  String codigo, {
  Duration ttl = const Duration(hours: 12),
  bool noCache = false,
}) async {
  final key = 'SENADO:senador_detalhe:$codigo';
  final ttlMinutes = ttl.inMinutes;

  if (!noCache) {
    final cached = await _cache.getJson<Map<String, dynamic>>(key, ttlMinutes: ttlMinutes);
    if (cached != null) return cached;
  }

  final raw = await _api.getSenadorDetalheRaw(codigo);
  await _cache.putJson(key, raw);
  return raw;
}

/// Mandatos do senador (resposta bruta), com cache.
Future<Map<String, dynamic>> obterMandatosSenadorRaw(
  String codigo, {
  Duration ttl = const Duration(hours: 12),
  bool noCache = false,
}) async {
  final key = 'SENADO:senador_mandatos:$codigo';
  final ttlMinutes = ttl.inMinutes;

  if (!noCache) {
    final cached = await _cache.getJson<Map<String, dynamic>>(key, ttlMinutes: ttlMinutes);
    if (cached != null) return cached;
  }

  final raw = await _api.getSenadorMandatosRaw(codigo);
  await _cache.putJson(key, raw);
  return raw;
}

}
