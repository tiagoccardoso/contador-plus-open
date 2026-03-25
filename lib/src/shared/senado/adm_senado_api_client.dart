// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Representa um endpoint candidato encontrado (ex.: vindo do OpenAPI).
class AdmEndpointCandidate {
  final String id; // ex.: "GET /api/v1/senadores/despesas_ceaps/{ano}"
  final String? summary;

  const AdmEndpointCandidate({required this.id, this.summary});
}

/// Resultado de uma consulta no "Dados Abertos Administrativo" do Senado.
class AdmQueryResult {
  final bool ok;
  final dynamic data;
  final Uri? usedUrl;
  final String? error;
  final List<AdmEndpointCandidate> candidates;

  const AdmQueryResult({
    required this.ok,
    this.data,
    this.usedUrl,
    this.error,
    this.candidates = const <AdmEndpointCandidate>[],
  });
}

/// Cliente para o "Dados Abertos Administrativo" do Senado.
///
/// Importante:
/// - A base correta é https://adm.senado.gov.br/adm-dadosabertos
/// - NÃO use Uri.resolve com paths que começam com '/', porque isso descarta o path do base
///   e acaba virando https://adm.senado.gov.br/api/v1/ (errado).
class AdmSenadoApiClient {
  AdmSenadoApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final Uri _base = Uri.parse('https://adm.senado.gov.br/adm-dadosabertos');

  static const Map<String, String> _headers = {
    // Alguns servidores retornam 403 sem um UA "de navegador".
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Mobile Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
  };

  /// Monta uma URL preservando o prefixo /adm-dadosabertos.
  Uri buildUri(String path, [Map<String, String>? queryParameters]) {
    // Se vier "/api/v1/...", removemos a barra inicial para não "resetar" o path do base.
    final cleaned = path.startsWith('/') ? path.substring(1) : path;

    // base.path é "/adm-dadosabertos"
    final basePath =
        _base.path.endsWith('/') ? _base.path.substring(0, _base.path.length - 1) : _base.path;

    // Garante um único '/' entre basePath e cleaned
    final fullPath = '$basePath/$cleaned'.replaceAll('//', '/');

    return Uri(
      scheme: _base.scheme,
      host: _base.host,
      path: fullPath,
      queryParameters: (queryParameters == null || queryParameters.isEmpty) ? null : queryParameters,
    );
  }

  /// Faz GET e tenta interpretar JSON (Map/List). Se vier texto, retorna String.
  Future<dynamic> getDynamic(String path, {Map<String, String>? query}) async {
    final uri = buildUri(path, query);

    final resp = await _client.get(uri, headers: _headers);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final body = resp.body;
      // Tenta JSON
      try {
        return jsonDecode(body);
      } catch (_) {
        return body;
      }
    }

    throw http.ClientException('HTTP ${resp.statusCode}', uri);
  }

  /// Conveniência: endpoint CEAPS por ano.
  Future<dynamic> despesasCeapsPorAno(int ano) {
    return getDynamic('/api/v1/senadores/despesas_ceaps/$ano');
  }

  /// Consulta CEAPS de forma resiliente:
  /// - tenta ano atual, depois ano-1, depois ano-2
  /// - retorna também a lista de endpoints candidatos (útil para debug/inspeção)
  ///
  /// Observação: alguns servidores podem retornar 403 para CSV; preferimos JSON.
  Future<AdmQueryResult> queryCeaps({required String senadorCodigo, int? ano}) async {
    final nowYear = DateTime.now().year;
    final yearsToTry = <int>[
      if (ano != null) ano,
      nowYear,
      nowYear - 1,
      nowYear - 2,
    ].toSet().toList();

    final candidates = <AdmEndpointCandidate>[
      const AdmEndpointCandidate(
        id: 'GET /api/v1/senadores/despesas_ceaps/{ano}',
        summary: 'Despesas CEAPS (JSON) por ano',
      ),
      const AdmEndpointCandidate(
        id: 'GET /api/v1/senadores/despesas_ceaps/{ano}/csv',
        summary: 'Despesas CEAPS (CSV) por ano (pode retornar 403)',
      ),
    ];

    http.ClientException? last;
    for (final y in yearsToTry) {
      final path = '/api/v1/senadores/despesas_ceaps/$y';
      final uri = buildUri(path);

      try {
        final data = await getDynamic(path);

        // Alguns endpoints retornam tudo do ano (lista grande). Aqui não filtramos agressivamente
        // porque o schema pode variar; a UI já permite visualizar/copy.
        return AdmQueryResult(ok: true, data: data, usedUrl: uri, candidates: candidates);
      } on http.ClientException catch (e) {
        last = e;
      } catch (e) {
        return AdmQueryResult(
          ok: false,
          error: e.toString(),
          usedUrl: uri,
          candidates: candidates,
        );
      }
    }

    return AdmQueryResult(
      ok: false,
      error: last?.toString() ?? 'Falha ao consultar CEAPS',
      usedUrl: last?.uri,
      candidates: candidates,
    );
  }

  void close() => _client.close();
}
