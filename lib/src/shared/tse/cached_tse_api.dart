// lib/src/shared/tse/cached_tse_api.dart
//
// Cache (TTL) para chamadas à API pública do TSE (DivulgaCandContas).
//
// Melhorias aplicadas:
// - dedupe de requisições "em voo" (evita explosão de requests)
// - fallback "stale-if-error" (se a rede falhar, retorna cache antigo)
// - chave de cache estável (params e body com ordenação)
// - evita persistir em disco consultas por CPF/CNPJ (privacidade)

import 'dart:async';
import 'dart:convert';

import '../cache/disk_cache.dart';
import 'tse_api_client.dart';

class CachedTseApi {
  final TseApiClient api;
  final DiskCache _cache;

  // Requests em voo (dedupe): mesma key -> mesma Future.
  final Map<String, Future<dynamic>> _inFlight = {};

  // Cache em memória para consultas sensíveis (ex.: CPF/CNPJ).
  final Map<String, _MemEntry> _mem = {};

  CachedTseApi([
    TseApiClient? api,
    DiskCache? cache,
  ])  : api = api ?? TseApiClient(),
        _cache = cache ?? DiskCache.instance;

  void dispose() => api.close();

  // ---------------------
  // Helpers de key
  // ---------------------

  Object? _canonicalize(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      final out = <String, dynamic>{};
      for (final k in keys) {
        out[k] = _canonicalize(v[k]);
      }
      return out;
    }
    if (v is List) {
      return v.map(_canonicalize).toList();
    }
    return v;
  }

  String _key(
    String method,
    String path,
    Map<String, dynamic>? params,
    Object? body,
  ) {
    final p = <String, dynamic>{...(params ?? {})};
    final pCanon = _canonicalize(p);
    final bCanon = _canonicalize(body);
    return 'TSE $method $path | p=${json.encode(pCanon)} | b=${json.encode(bCanon)}';
  }

  Future<T> _dedup<T>(String key, Future<T> Function() work) async {
    final existing = _inFlight[key];
    if (existing != null) return await existing as T;
    final fut = work();
    _inFlight[key] = fut;
    try {
      return await fut;
    } finally {
      // remove apenas se ainda é o mesmo future
      if (identical(_inFlight[key], fut)) {
        _inFlight.remove(key);
      }
    }
  }

  Future<T> _request<T>(
    String method,
    String path, {
    Map<String, dynamic>? params,
    Object? body,
    int? ttlMinutes,
    bool forceRefresh = false,
    bool allowDiskCache = true,
    required Future<T> Function() network,
  }) async {
    final key = _key(method, path, params, body);

    return _dedup<T>(key, () async {
      // 1) cache "fresh" (quando aplicável)
      if (!forceRefresh && ttlMinutes != null) {
        if (allowDiskCache) {
          final cached = await _cache.getJson<T>(key, ttlMinutes: ttlMinutes);
          if (cached != null) return cached;
        } else {
          final entry = _mem[key];
          if (entry != null && DateTime.now().difference(entry.ts).inMinutes <= ttlMinutes) {
            return entry.data as T;
          }
        }
      }

      // 2) cache "stale" para fallback, quando usamos disco
      T? stale;
      if (allowDiskCache) {
        stale = await _cache.getJsonStale<T>(key);
      }

      // 3) rede
      try {
        final data = await network();
        if (allowDiskCache) {
          await _cache.putJson(key, data as Object?);
        } else {
          _mem[key] = _MemEntry(DateTime.now(), data);
        }
        return data;
      } catch (_) {
        // 4) stale-if-error
        if (stale != null) return stale;
        rethrow;
      }
    });
  }

  // ---------------------------
  // Endpoints usados pelo app
  // ---------------------------

  Future<List<dynamic>> eleicoesOrdinarias({bool forceRefresh = false}) async {
    return _request<List<dynamic>>(
      'GET',
      '/eleicao/ordinarias',
      ttlMinutes: 6 * 60,
      forceRefresh: forceRefresh,
      network: () async {
        final d = await api.getJson('/eleicao/ordinarias');
        return (d is List) ? d : <dynamic>[];
      },
    );
  }

  Future<List<dynamic>> ufs({bool forceRefresh = false}) async {
    return _request<List<dynamic>>(
      'GET',
      '/eleicao/ufs',
      ttlMinutes: 6 * 60,
      forceRefresh: forceRefresh,
      network: () async {
        final d = await api.getJson('/eleicao/ufs');
        return (d is List) ? d : <dynamic>[];
      },
    );
  }

  Future<List<dynamic>> municipios(String siglaUf, {bool forceRefresh = false}) async {
    final uf = siglaUf.toUpperCase();
    return _request<List<dynamic>>(
      'GET',
      '/eleicao/ufs/$uf/municipios',
      ttlMinutes: 6 * 60,
      forceRefresh: forceRefresh,
      network: () async {
        final d = await api.getJson('/eleicao/ufs/$uf/municipios');
        return (d is List) ? d : <dynamic>[];
      },
    );
  }

  Future<Map<String, dynamic>> cargos({
    required int idEleicao,
    required String siglaBusca,
    bool forceRefresh = false,
  }) async {
    final s = siglaBusca;
    return _request<Map<String, dynamic>>(
      'GET',
      '/eleicao/listar/municipios/$idEleicao/$s/cargos',
      ttlMinutes: 60,
      forceRefresh: forceRefresh,
      network: () async {
        final d = await api.getJson('/eleicao/listar/municipios/$idEleicao/$s/cargos');
        return (d is Map) ? Map<String, dynamic>.from(d) : <String, dynamic>{};
      },
    );
  }

  Future<Map<String, dynamic>> candidatos({
    required int anoEleitoral,
    required String siglaBusca,
    required int idEleicao,
    required int cargo,
    bool forceRefresh = false,
  }) async {
    return _request<Map<String, dynamic>>(
      'GET',
      '/candidatura/listar/$anoEleitoral/$siglaBusca/$idEleicao/$cargo/candidatos',
      ttlMinutes: 30,
      forceRefresh: forceRefresh,
      network: () async {
        final d = await api.getJson('/candidatura/listar/$anoEleitoral/$siglaBusca/$idEleicao/$cargo/candidatos');
        return (d is Map) ? Map<String, dynamic>.from(d) : <String, dynamic>{};
      },
    );
  }

  Future<Map<String, dynamic>> candidatoDetalhe({
    required int anoEleitoral,
    required String siglaBusca,
    required int idEleicao,
    required int candidato,
    bool forceRefresh = false,
  }) async {
    return _request<Map<String, dynamic>>(
      'GET',
      '/candidatura/buscar/$anoEleitoral/$siglaBusca/$idEleicao/candidato/$candidato',
      ttlMinutes: 2 * 60,
      forceRefresh: forceRefresh,
      network: () async {
        final d = await api.getJson('/candidatura/buscar/$anoEleitoral/$siglaBusca/$idEleicao/candidato/$candidato');
        return (d is Map) ? Map<String, dynamic>.from(d) : <String, dynamic>{};
      },
    );
  }

  Future<Map<String, dynamic>> prestador({
    required int idEleicao,
    required int anoEleitoral,
    required String siglaBusca,
    required int cargo,
    required int candidato,
    bool forceRefresh = false,
  }) async {
    return _request<Map<String, dynamic>>(
      'GET',
      '/prestador/consulta/$idEleicao/$anoEleitoral/$siglaBusca/$cargo/90/90/$candidato',
      ttlMinutes: 30,
      forceRefresh: forceRefresh,
      network: () async {
        final d = await api.getJson('/prestador/consulta/$idEleicao/$anoEleitoral/$siglaBusca/$cargo/90/90/$candidato');
        if (d is Map) return Map<String, dynamic>.from(d);
        // Alguns retornos vêm embrulhados em lista: [ { ... } ]
        if (d is List && d.isNotEmpty && d.first is Map) {
          return Map<String, dynamic>.from(d.first as Map);
        }
        return <String, dynamic>{};
      },
    );
  }

  /// Busca doadores/fornecedores por nome ou CPF/CNPJ.
  Future<dynamic> doadorFornecedor({
    required int idEleicao,
    String? nome,
    String? cpfCnpj,
    bool forceRefresh = false,
  }) async {
    final cpf = cpfCnpj?.trim();
    final isCpfCnpj = cpf != null && cpf.isNotEmpty;

    final body = <String, dynamic>{
      'idEleicao': idEleicao.toString(),
      if (nome != null && nome.trim().isNotEmpty) 'nome': nome.trim(),
      if (isCpfCnpj) 'cpfCnpj': cpf,
    };

    // Consulta é dinâmica, cache curto.
    // Por privacidade, se for CPF/CNPJ, cache apenas em memória.
    return _request<dynamic>(
      'POST',
      '/doador-fornecedor/consulta/$idEleicao',
      body: body,
      ttlMinutes: 10,
      forceRefresh: forceRefresh,
      allowDiskCache: !isCpfCnpj,
      network: () => api.postJson('/doador-fornecedor/consulta/$idEleicao', body),
    );
  }
}

class _MemEntry {
  final DateTime ts;
  final Object? data;
  _MemEntry(this.ts, this.data);
}
