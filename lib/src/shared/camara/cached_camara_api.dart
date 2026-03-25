// lib/src/shared/camara/cached_camara_api.dart
import 'camara_api_client.dart';
import '../cache/disk_cache.dart';

/// Wrapper que adiciona cache local em disco (TTL em minutos) sobre o client da Câmara.
class CachedCamaraApi {
  final CamaraApiV2Client api;
  final int ttlMinutes;
  final DiskCache _cache = DiskCache.instance;

  CachedCamaraApi(this.api, {this.ttlMinutes = 30});

  String _k(String path, Map<String, dynamic>? params) {
    final entries = (params ?? {}).entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final qs = entries.map((e) => '${e.key}=${e.value}').join('&');
    return 'GET $path?$qs';
  }

  Future<List<Map<String, dynamic>>> _getList(
      String path, {
        Map<String, dynamic>? params,
        bool noCache = false,
        required Future<List<Map<String, dynamic>>> Function() network,
      }) async {
    final key = _k(path, params);
    if (!noCache) {
      final cached = await _cache.getJson<List<dynamic>>(key, ttlMinutes: ttlMinutes);
      if (cached != null) {
        return cached
            .whereType<Map>()                               // já filtra para Map
            .map((e) => Map<String, dynamic>.from(e))       // removeu o cast desnecessário
            .toList();
      }
    }
    final data = await network();
    await _cache.putJson(key, data);
    return data;
  }

  Future<Map<String, dynamic>> _getObj(
      String path, {
        Map<String, dynamic>? params,
        bool noCache = false,
        required Future<Map<String, dynamic>> Function() network,
      }) async {
    final key = _k(path, params);
    if (!noCache) {
      final cached = await _cache.getJson<Map<String, dynamic>>(key, ttlMinutes: ttlMinutes);
      if (cached != null) return cached;
    }
    final data = await network();
    await _cache.putJson(key, data);
    return data;
  }

  // ---- Endpoints com cache ----
  Future<List<Map<String, dynamic>>> listarDeputados({
    String? nome,
    String? siglaUf,
    String? siglaPartido,
    String ordem = 'ASC',
    String ordenarPor = 'nome',
    int itens = 100,
    int? maxPaginas,
    bool noCache = false,
  }) {
    final params = {
      if (nome != null) 'nome': nome,
      if (siglaUf != null) 'siglaUf': siglaUf,
      if (siglaPartido != null) 'siglaPartido': siglaPartido,
      'ordem': ordem,
      'ordenarPor': ordenarPor,
      'itens': itens,
      if (maxPaginas != null) 'maxPaginas': maxPaginas,
    };
    return _getList('/deputados', params: params, noCache: noCache, network: () {
      return api.listarDeputados(
        nome: nome,
        siglaUf: siglaUf,
        siglaPartido: siglaPartido,
        ordem: ordem,
        ordenarPor: ordenarPor,
        itens: itens,
        maxPaginas: maxPaginas,
      );
    });
  }

  Future<Map<String, dynamic>> obterDeputado(int id, {bool noCache = false}) {
    return _getObj('/deputados/$id', noCache: noCache, network: () {
      return api.obterDeputado(id);
    });
  }

  Future<List<Map<String, dynamic>>> ocupacoesDeputado(int id, {bool noCache = false}) {
    return _getList('/deputados/$id/ocupacoes', noCache: noCache, network: () {
      return api.ocupacoesDeputado(id);
    });
  }

  Future<List<Map<String, dynamic>>> despesasDeputado(
      int id, {
        int? ano,
        int? mes,
        String ordem = 'DESC',
        String ordenarPor = 'dataDocumento',
        int itens = 100,
        int? maxPaginas,
        bool noCache = false,
      }) {
    final params = {
      'ano': ano,
      'mes': mes,
      'ordem': ordem,
      'ordenarPor': ordenarPor,
      'itens': itens,
      'maxPaginas': maxPaginas,
    };
    return _getList('/deputados/$id/despesas', params: params, noCache: noCache, network: () {
      return api.despesasDeputado(
        id,
        ano: ano,
        mes: mes,
        ordem: ordem,
        ordenarPor: ordenarPor,
        itens: itens,
        maxPaginas: maxPaginas,
      );
    });
  }

  Future<List<Map<String, dynamic>>> discursosDeputado(
      int id, {
        DateTime? dataInicio,
        DateTime? dataFim,
        String ordem = 'DESC',
        String ordenarPor = 'dataHoraInicio',
        int itens = 100,
        int? maxPaginas,
        bool noCache = false,
      }) {
    final params = {
      'dataInicio': dataInicio?.toIso8601String(),
      'dataFim': dataFim?.toIso8601String(),
      'ordem': ordem,
      'ordenarPor': ordenarPor,
      'itens': itens,
      'maxPaginas': maxPaginas,
    };
    return _getList('/deputados/$id/discursos', params: params, noCache: noCache, network: () {
      return api.discursosDeputado(
        id,
        dataInicio: dataInicio,
        dataFim: dataFim,
        ordem: ordem,
        ordenarPor: ordenarPor,
        itens: itens,
        maxPaginas: maxPaginas,
      );
    });
  }

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
    bool noCache = false,
  }) {
    final params = {
      'idDeputadoAutor': idDeputadoAutor,
      'siglaTipo': siglaTipo,
      'ano': ano,
      'dataInicio': dataInicio?.toIso8601String(),
      'dataFim': dataFim?.toIso8601String(),
      'keywords': keywords,
      'ordem': ordem,
      'ordenarPor': ordenarPor,
      'itens': itens,
      'maxPaginas': maxPaginas,
    };
    return _getList('/proposicoes', params: params, noCache: noCache, network: () {
      return api.listarProposicoes(
        idDeputadoAutor: idDeputadoAutor,
        siglaTipo: siglaTipo,
        ano: ano,
        dataInicio: dataInicio,
        dataFim: dataFim,
        keywords: keywords,
        ordem: ordem,
        ordenarPor: ordenarPor,
        itens: itens,
        maxPaginas: maxPaginas,
      );
    });
  }

  Future<List<Map<String, dynamic>>> listarVotacoes({
    DateTime? dataInicio,
    DateTime? dataFim, String ordem = 'DESC', String ordenarPor = 'dataHoraRegistro',
    int itens = 100,
    int? maxPaginas,
    bool noCache = false,
  }) {
    final params = {
      'ordem': ordem,
      'ordenarPor': ordenarPor,
      'dataInicio': dataInicio?.toIso8601String(),
      'dataFim': dataFim?.toIso8601String(),
      'itens': itens,
      'maxPaginas': maxPaginas,
    };
    return _getList('/votacoes', params: params, noCache: noCache, network: () {
      return api.listarVotacoes(
        
        dataInicio: dataInicio,
        dataFim: dataFim,
        itens: itens,
        maxPaginas: maxPaginas,
        ordem: ordem,
        ordenarPor: ordenarPor
      );
    });
  }

  Future<List<Map<String, dynamic>>> votosDaVotacao(
      String idVotacao, {
        int itens = 100,
        int? maxPaginas,
        bool noCache = false,
      }) {
    final params = {'itens': itens, 'maxPaginas': maxPaginas};
    return _getList('/votacoes/$idVotacao/votos', params: params, noCache: noCache, network: () {
      return api.votosDaVotacao(idVotacao, itens: itens, maxPaginas: maxPaginas);
    });
  }


/// Proposições de um deputado em um ano, com proteção ao bug de filtro por data.
Future<List<Map<String, dynamic>>> proposicoesDoDeputadoPorAno({
  required int idDeputado,
  required int ano,
  int itens = 100,
  int? maxPaginas,
  bool noCache = false,
}) async {
  final params1 = {
    'idDeputadoAutor': idDeputado,
    'ano': ano,
    'ordem': 'DESC',
    'ordenarPor': 'dataApresentacao',
    'itens': itens,
    'maxPaginas': maxPaginas,
  };
  final k1 = _k('/proposicoes', params1);
  final c1 = await _cache.getJson<List<dynamic>>(k1, ttlMinutes: noCache ? 0 : ttlMinutes);
  if (c1 != null) return c1.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  final list1 = await api.listarProposicoes(
    idDeputadoAutor: idDeputado,
    ano: ano,
    ordem: 'DESC',
    ordenarPor: 'dataApresentacao',
    itens: itens,
    maxPaginas: maxPaginas,
  );
  if (list1.isNotEmpty) {
    await _cache.putJson(k1, list1);
    return list1;
  }

  // Fallback: apenas autor e filtro local por ano
  final params2 = {
    'idDeputadoAutor': idDeputado,
    'ordem': 'DESC',
    'ordenarPor': 'dataApresentacao',
    'itens': itens,
    'maxPaginas': maxPaginas,
  };
  final k2 = _k('/proposicoes_fallback', {...params2, 'anoLocal': ano});
  final c2 = await _cache.getJson<List<dynamic>>(k2, ttlMinutes: noCache ? 0 : ttlMinutes);
  if (c2 != null) return c2.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  final list2 = await api.listarProposicoes(
    idDeputadoAutor: idDeputado,
    ordem: 'DESC',
    ordenarPor: 'dataApresentacao',
    itens: itens,
    maxPaginas: maxPaginas,
  );
  final filtrado = list2.where((p) {
    final a = (p['ano'] as num?)?.toInt();
    return a == ano;
  }).toList();
  await _cache.putJson(k2, filtrado);
  return filtrado;
}
}
