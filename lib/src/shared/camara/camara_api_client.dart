import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Cliente v2 da Câmara com paginação por `links.next` e retries com backoff.
class CamaraApiV2Client {
  static const String _host = 'dadosabertos.camara.leg.br';
  static const String _basePath = '/api/v2';

  final String appName;
  final String contact;
  final http.Client _http;

  CamaraApiV2Client({
    required this.appName,
    required this.contact,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  Future<http.Response> _get(Uri uri) async {
    int attempt = 0;
    while (true) {
      try {
        final r = await _http.get(uri, headers: {
          'accept': 'application/json',
          'user-agent': '$appName ($contact)',
        });
        if (r.statusCode >= 200 && r.statusCode < 300) return r;
        if (++attempt >= 3) {
          throw http.ClientException('HTTP ${r.statusCode} em ${uri.toString()}', uri);
        }
      } catch (_) {
        if (++attempt >= 3) rethrow;
      }
      await Future.delayed(Duration(milliseconds: attempt == 1 ? 200 : 600));
    }
  }

  Uri _buildUri(String path, [Map<String, dynamic>? params]) {
    final qp = <String, String>{};
    params?.forEach((k, v) {
      if (v == null) return;
      final s = v.toString().trim();
      if (s.isEmpty) return;
      qp[k] = s;
    });
    return Uri.https(_host, '$_basePath$path', qp);
  }

  Future<Map<String, dynamic>> _getJson(String path, [Map<String, dynamic>? params]) async {
    final r = await _get(_buildUri(path, params));
    return json.decode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> _getJsonAll(
    String path, {
    Map<String, dynamic>? params,
    int? maxPaginas,
    int? maxRegistros,
  }) async {
    final out = <Map<String, dynamic>>[];
    Uri? uri = _buildUri(path, params);
    int pagina = 0;

    while (uri != null) {
      if (maxPaginas != null && pagina >= maxPaginas) break;

      final r = await _get(uri);
      final body = json.decode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;

      final dados = (body['dados'] as List? ?? const [])
          .whereType<Map<String, dynamic>>();
      out.addAll(dados);

      if (maxRegistros != null && out.length >= maxRegistros) {
        return out.take(maxRegistros).toList();
      }

      final links = body['links'] as List? ?? const [];
      Map<String, dynamic>? next;
      for (final l in links) {
        if (l is Map && l['rel'] == 'next') {
          next = Map<String, dynamic>.from(l);
          break;
        }
      }
      final href = next?['href'];
      uri = (href is String && href.isNotEmpty) ? Uri.parse(href) : null;
      pagina++;
    }
    return out;
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ----------------- Deputados
  Future<List<Map<String, dynamic>>> listarDeputados({
    String? nome,
    String? siglaUf,
    String? siglaPartido,
    String ordem = 'ASC',
    String ordenarPor = 'nome',
    int itens = 100,
    int? maxPaginas,
  }) {
    final params = {
      if (nome != null) 'nome': nome,
      if (siglaUf != null) 'siglaUf': siglaUf.toUpperCase(),
      if (siglaPartido != null) 'siglaPartido': siglaPartido.toUpperCase(),
      'ordem': ordem,
      'ordenarPor': ordenarPor,
      'itens': itens.clamp(1, 100),
    };
    return _getJsonAll('/deputados', params: params, maxPaginas: maxPaginas);
  }

  Future<Map<String, dynamic>> obterDeputado(int id) async {
    final m = await _getJson('/deputados/$id');
    return (m['dados'] as Map?)?.cast<String, dynamic>() ?? const {};
  }

  Future<List<Map<String, dynamic>>> ocupacoesDeputado(int id) async {
    final m = await _getJson('/deputados/$id/ocupacoes');
    return (m['dados'] as List? ?? const []).whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> despesasDeputado(
    int id, {
    int? ano,
    int? mes,
    String ordem = 'DESC',
    String ordenarPor = 'dataDocumento',
    int itens = 100,
    int? maxPaginas,
  }) {
    final params = {
      if (ano != null) 'ano': ano,
      if (mes != null) 'mes': mes,
      'ordem': ordem,
      'ordenarPor': ordenarPor,
      'itens': itens.clamp(1, 100),
    };
    return _getJsonAll('/deputados/$id/despesas', params: params, maxPaginas: maxPaginas);
  }

  Future<List<Map<String, dynamic>>> discursosDeputado(
    int id, {
    DateTime? dataInicio,
    DateTime? dataFim,
    String ordem = 'DESC',
    String ordenarPor = 'dataHoraInicio',
    int itens = 100,
    int? maxPaginas,
  }) {
    final params = {
      if (dataInicio != null) 'dataInicio': _fmtDate(dataInicio),
      if (dataFim != null) 'dataFim': _fmtDate(dataFim),
      'ordem': ordem,
      'ordenarPor': ordenarPor,
      'itens': itens.clamp(1, 100),
    };
    return _getJsonAll('/deputados/$id/discursos', params: params, maxPaginas: maxPaginas);
  }

  // ----------------- Proposições (projetos)
  Future<List<Map<String, dynamic>>> listarProposicoes({
    int? idDeputadoAutor,
    String? siglaTipo,
    int? ano,
    DateTime? dataInicio,
    DateTime? dataFim,
    String? keywords,
    String? ordem,
    String? ordenarPor,
    int itens = 100,
    int? maxPaginas,
  }) {
    final params = {
      if (idDeputadoAutor != null) 'idDeputadoAutor': idDeputadoAutor,
      if (siglaTipo != null) 'siglaTipo': siglaTipo.toUpperCase(),
      if (ano != null) 'ano': ano,
      if (dataInicio != null) 'dataInicio': _fmtDate(dataInicio),
      if (dataFim != null) 'dataFim': _fmtDate(dataFim),
      if (keywords != null) 'keywords': keywords,
      if (ordem != null) 'ordem': ordem,
      if (ordenarPor != null) 'ordenarPor': ordenarPor,
      'itens': itens.clamp(1, 100),
    };
    return _getJsonAll('/proposicoes', params: params, maxPaginas: maxPaginas);
  }

  Future<Map<String, dynamic>> obterProposicao(int id) async {
    final m = await _getJson('/proposicoes/$id');
    return (m['dados'] as Map?)?.cast<String, dynamic>() ?? const {};
  }

  Future<List<Map<String, dynamic>>> proposicaoTramitacoes(int id, {int itens = 100, int? maxPaginas}) {
    return _getJsonAll('/proposicoes/$id/tramitacoes',
        params: {'itens': itens.clamp(1, 100)}, maxPaginas: maxPaginas);
  }

  Future<List<Map<String, dynamic>>> proposicaoVotacoes(int id, {int itens = 100, int? maxPaginas}) {
    return _getJsonAll('/proposicoes/$id/votacoes',
        params: {'itens': itens.clamp(1, 100)}, maxPaginas: maxPaginas);
  }

  Future<List<Map<String, dynamic>>> proposicaoAutores(int id, {int itens = 100, int? maxPaginas}) {
    return _getJsonAll('/proposicoes/$id/autores',
        params: {'itens': itens.clamp(1, 100)}, maxPaginas: maxPaginas);
  }

  Future<List<Map<String, dynamic>>> proposicaoTemas(int id, {int itens = 100, int? maxPaginas}) {
    return _getJsonAll('/proposicoes/$id/temas',
        params: {'itens': itens.clamp(1, 100)}, maxPaginas: maxPaginas);
  }

  // ----------------- Votações
  Future<List<Map<String, dynamic>>> listarVotacoes({ DateTime? dataInicio, DateTime? dataFim, String ordem = 'DESC', String ordenarPor = 'dataHoraRegistro', int itens = 100, int? maxPaginas, }) {
    final params = {
      'ordem': ordem,
      'ordenarPor': ordenarPor,
      if (dataInicio != null) 'dataInicio': _fmtDate(dataInicio),
      if (dataFim != null) 'dataFim': _fmtDate(dataFim),
      'itens': itens.clamp(1, 100),
    };
    return _getJsonAll('/votacoes', params: params, maxPaginas: maxPaginas);
  }

  Future<Map<String, dynamic>> obterVotacao(String id) async {
    final m = await _getJson('/votacoes/$id');
    return (m['dados'] as Map?)?.cast<String, dynamic>() ?? const {};
  }

  Future<List<Map<String, dynamic>>> votosDaVotacao(String idVotacao, {int itens = 100, int? maxPaginas}) {
    return _getJsonAll('/votacoes/$idVotacao/votos',
        params: {'itens': itens.clamp(1, 100)}, maxPaginas: maxPaginas);
  }

  Future<List<Map<String, dynamic>>> orientacoesDaVotacao(String idVotacao, {int itens = 100, int? maxPaginas}) {
    return _getJsonAll('/votacoes/$idVotacao/orientacoes',
        params: {'itens': itens.clamp(1, 100)}, maxPaginas: maxPaginas);
  }
}
