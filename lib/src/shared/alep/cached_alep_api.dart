// lib/src/shared/alep/cached_alep_api.dart
//
// Cache em disco (TTL) para chamadas à API pública da ALEP.
//
// IMPORTANTE:
// O DiskCache do projeto tem assinaturas:
//   Future<T?> getJson<T>(String key, {int? ttlMinutes})
//   Future<void> putJson(String key, Object value)
// Então, ttlMinutes deve SEMPRE ser passado como parâmetro nomeado.

import '../cache/disk_cache.dart';
import 'alep_api_client.dart';

/// Wrapper que adiciona cache local em disco (TTL) sobre o client da ALEP.
class CachedAlepApi {
  final AlepApiClient api;
  final int ttlMinutes;
  final DiskCache _cache;

  /// Construtor padrão.
  ///
  /// No projeto, várias telas instanciam `CachedAlepApi()` sem argumentos.
  /// Para manter isso funcionando, o client e cache usam defaults seguros.
  CachedAlepApi([
    AlepApiClient? api,
    DiskCache? cache,
  ])  : api = api ?? AlepApiClient(),
        _cache = cache ?? DiskCache.instance,
        ttlMinutes = 30;

  /// Construtor alternativo com TTL customizável.
  CachedAlepApi.withTtl(
      int ttlMinutes, {
        AlepApiClient? api,
        DiskCache? cache,
      })  : api = api ?? AlepApiClient(),
        _cache = cache ?? DiskCache.instance,
        ttlMinutes = ttlMinutes;

  String _key(String method, String path, Map<String, dynamic>? params, Object? body) {
    final p = <String, dynamic>{...(params ?? {})};
    final entries = p.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final qs = entries.map((e) => '${e.key}=${e.value}').join('&');

    // body entra no cache-key (quando existir), mas sem complicar muito.
    final b = body == null ? '' : body.toString();
    return '$method $path?$qs | $b';
  }

  /// Request genérico com cache.
  /// - Se [noCache] = true, sempre chama a rede.
  /// - Se [ttl] for informado, sobrepõe [ttlMinutes] para esta chamada.
  Future<T> request<T>(
      String method,
      String path, {
        Map<String, dynamic>? params,
        Object? body,
        bool noCache = false,
        bool forceRefresh = false,
        int? ttl,
        required Future<T> Function() network,
      }) async {
    final key = _key(method, path, params, body);
    final effectiveTtl = ttl ?? ttlMinutes;

    final bypass = noCache || forceRefresh;
    if (!bypass) {
      final cached = await _cache.getJson<T>(key, ttlMinutes: effectiveTtl);
      if (cached != null) return cached;
    }

    final data = await network();
    // O DiskCache espera `Object`, e `T` já é não-nulo aqui.
    // Evita cast desnecessário que gera warning.
    await _cache.putJson(key, data);
    return data;
  }

  /// Helper genérico: faz GET quando [body] é nulo; faz POST quando [body] existe.
  /// Retorna o JSON decodificado (pode ser Map ou List).
  Future<dynamic> get(
      String path, {
        Map<String, dynamic>? params,
        Map<String, dynamic>? body,
        bool forceRefresh = false,
        int? ttl,
      }) {
    if (body == null) {
      return request<dynamic>(
        'GET',
        path,
        params: params,
        ttl: ttl,
        forceRefresh: forceRefresh,
        network: () async => api.getJson(path, params: params),
      );
    }
    return request<dynamic>(
      'POST',
      path,
      body: body,
      ttl: ttl,
      forceRefresh: forceRefresh,
      network: () async => api.postJson(path, body),
    );
  }

  // ---------------------------
  // Métodos focados no app


  /// Normaliza um nome de parlamentar capturado do Portal.
  ///
  /// O Portal mistura botões/links de exportação (XLS/XLSX/PDF/CSV) próximos ao nome.
  /// Também pode inserir "-" ou bullets no início da linha.
  String _normalizeDeputadoName(String raw) {
    var s = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return '';

    // Remove marcadores comuns de lista no início.
    s = s.replaceFirst(RegExp(r'^(?:[-–—•\.\u00B7]+\s*)+'), '').trim();

    // Remove tokens de exportação no início ("XLSX Nome").
    s = s.replaceFirst(RegExp(r'^(?:XLSX|XLS|CSV|PDF)\s+', caseSensitive: false), '').trim();

    // Remove tokens de exportação que ficaram grudados no meio.
    s = s.replaceAll(RegExp(r'\b(?:XLSX|XLS|CSV|PDF)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Linhas que viraram só o token.
    if (RegExp(r'^(?:XLSX|XLS|CSV|PDF)$', caseSensitive: false).hasMatch(s)) return '';

    // Remove sobra de hífen no início depois de limpeza.
    s = s.replaceFirst(RegExp(r'^[\-\.\u00B7]\s*'), '').trim();

    return s;
  }

  bool _looksLikePersonName(String s) {
    final t = _normalizeDeputadoName(s);
    if (t.isEmpty) return false;

    // Exige pelo menos 2 palavras ("Ana Júlia", "Alexandre Curi").
    final parts = t.split(' ').where((p) => p.trim().isNotEmpty).toList();
    if (parts.length < 2) return false;

    // Evita itens com números.
    if (RegExp(r'\d').hasMatch(t)) return false;

    final lower = t.toLowerCase();

    // Evita capturar menus/títulos e órgãos.
    // Observação: o HTML do Portal mistura MUITA coisa (títulos, instruções, botões).
    // Aqui o filtro é deliberadamente agressivo para manter apenas nomes de pessoas.
    const badSubstrings = [
      'legislatura',
      'transpar',
      'assembleia',
      'agencia',
      'secretaria',
      'governo',
      'tribunal',
      'ministerio',
      'prefeitura',
      'camara',
      'autarquia',
      'fundacao',
      // Frases/títulos que não são nomes de pessoas
      'atividade legislativa',
      'atividade parlamentar',
      'atividades parlamentares',
      'por parlamentar',
      'diarios',
      'diario',
      'atos',
      'atualizado ate',
      'atualizado até',
      'nao houve',
      'não houve',
      'publicadas',
      'periodo',
      'período',
      'como consultar',
      'clique',
      'ver mais',
      'selecione',
      'pesquisar',
    ];
    for (final b in badSubstrings) {
      if (lower.contains(b)) return false;
    }

    // Bloqueia palavras “típicas de página” como token inteiro.
    final badWords = <String>{
      'atividade',
      'parlamentar',
      'parlamentares',
      'diarios',
      'diário',
      'atualizado',
      'nessa',
      'nesta',
      'neste',
      'consultar',
      'consulta',
      'verbas',
      'ressarcimento',
      'prestacao',
      'prestação',
      'contas',
      // ruído capturado ocasionalmente por fontes alternativas
      'cantora',
      'cantor',
      'banda',
    };
    for (final w in lower.split(RegExp(r'\s+'))) {
      final ww = w.trim();
      if (ww.isEmpty) continue;
      if (badWords.contains(ww)) return false;
    }

    // Deve ter “cara” de nome próprio: maioria das palavras iniciando com maiúscula,
    // permitindo partículas comuns em minúsculo.
    const allowLower = <String>{'de', 'da', 'do', 'das', 'dos', 'e', 'd', 'jr', 'júnior', 'junior', 'neto', 'filho'};
    int checked = 0;
    int ok = 0;
    for (final p in parts) {
      final w = p.trim();
      if (w.isEmpty) continue;
      final wl = w.toLowerCase();
      if (allowLower.contains(wl)) continue;
      if (wl == 'dr.' || wl == 'dr' || wl == 'dra.' || wl == 'dra') continue;
      checked++;
      final first = String.fromCharCode(w.runes.first);
      if (RegExp(r'[A-ZÀ-ÖØ-Þ]').hasMatch(first)) ok++;
    }
    if (checked > 0 && ok / checked < 0.6) return false;

    return true;
  }

  List<String> _extractDeputadosFromHtml(String html) {
    // Remove scripts/styles (sem usar flags inline (?is), que quebram no Dart).
    var t = html
        .replaceAll(
      RegExp(r'<script[^>]*>[\s\S]*?<\/script>', caseSensitive: false),
      ' ',
    )
        .replaceAll(
      RegExp(r'<style[^>]*>[\s\S]*?<\/style>', caseSensitive: false),
      ' ',
    );

    // Troca algumas tags por separadores para ajudar a segmentar.
    // (Dart NÃO suporta (?i), então usamos caseSensitive:false)
    t = t
        .replaceAll(
      RegExp(r'<\s*br\s*\/?>', caseSensitive: false),
      '\n',
    )
        .replaceAll(
      RegExp(r'<\s*\/\s*(p|div|li|tr|td|th|h\d)\s*>', caseSensitive: false),
      '\n',
    );

    // Remove demais tags HTML.
    t = t.replaceAll(RegExp(r'<[^>]+>'), ' ');
    t = t.replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&');
    t = t.replaceAll(RegExp(r'\s+'), ' ');

    final found = <String>{};

    // Padrão comum: "NOME DO DEPUTADO 20" (quantidade ao lado).
    // ⚠️ NÃO use r'...' aqui por causa de \' / \"
    final withCount = RegExp(
      "\\b([A-Za-zÀ-ÖØ-öø-ÿ'\"\\-\\.]+(?:\\s+[A-Za-zÀ-ÖØ-öø-ÿ'\"\\-\\.]+)+)\\s+(\\d{1,4})\\b",
    );

    for (final m in withCount.allMatches(t)) {
      final cand = _normalizeDeputadoName(m.group(1) ?? '');
      if (_looksLikePersonName(cand)) found.add(cand);
    }

    // Importante: NÃO usar um fallback “nameLike” genérico aqui.
    // Ele acaba capturando títulos/instruções da página (ex.: "Atividade Legislativa Por Parlamentar").
    // Para esta tela, preferimos retornar MENOS nomes a incluir falsos positivos.

    final list = found.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  // ---------------------------

  // ---------------------------

  /// Lista de deputados estaduais do PR (somente pessoas).
  ///
  /// A lista de "autores" em /proposicao/campos inclui órgãos/entidades (ex.: agências),
  /// então para a aba "Deputados" usamos como fonte o Portal da Transparência.
  ///
  /// Fonte: https://transparencia.assembleia.pr.leg.br/plenario/atividade-por-parlamentar
  Future<Map<String, dynamic>> deputadosEstaduaisPr({bool noCache = false, bool forceRefresh = false}) {
    const url = 'https://transparencia.assembleia.pr.leg.br/plenario/atividade-por-parlamentar';

    return request<Map<String, dynamic>>(
      'GET',
      '/_scrape/deputados-estaduais-pr',
      noCache: noCache,
      forceRefresh: forceRefresh,
      ttl: 24 * 60, // muda pouco
      network: () async {
        // 1) Tenta extrair do Portal da Transparência.
        final html = await api.getTextAbsolute(url);
        var lista = _extractDeputadosFromHtml(html);

        // 2) Fallback: se o Portal estiver muito dinâmico/minificado e não der para extrair,
        // usa /proposicao/campos e filtra para nomes "com cara" de pessoa.
        // Se o scrape não encontrou um volume razoável de nomes, tentamos um fallback.
        // Mantemos o limite alto para evitar “falsos positivos” (frases e nomes fora do rol de parlamentares).
        if (lista.length < 30) {
          try {
            final campos = await api.getJson('/proposicao/campos');

            final found = <String>{};
            void walk(dynamic v) {
              if (v == null) return;
              if (v is String) {
                final cand = _normalizeDeputadoName(v);
                if (_looksLikePersonName(cand)) found.add(cand);
                return;
              }
              if (v is List) {
                for (final e in v) walk(e);
                return;
              }
              if (v is Map) {
                for (final e in v.values) walk(e);
              }
            }

            // Procura em chaves comuns.
            walk(campos['autores']);
            walk(campos['parlamentares']);
            walk(campos['lista']);

            final fallback = found.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
            if (fallback.length > lista.length) {
              lista = fallback;
            }
          } catch (_) {
            // ignora fallback se falhar
          }
        }

        return <String, dynamic>{'lista': lista};
      },
    );
  }

  /// GET /proposicao/campos
  Future<Map<String, dynamic>> proposicaoCampos({bool noCache = false, bool forceRefresh = false}) {
    return request<Map<String, dynamic>>(
      'GET',
      '/proposicao/campos',
      noCache: noCache,
      forceRefresh: forceRefresh,
      ttl: 24 * 60, // campos mudam pouco
      network: () => api.getJson('/proposicao/campos'),
    );
  }

  /// POST /proposicao/filtrar  (a API aceita filtros via body)
  Future<Map<String, dynamic>> proposicaoFiltrar(
      Map<String, dynamic> filtros, {
        bool noCache = false,
        bool forceRefresh = false,
      }) {
    return request<Map<String, dynamic>>(
      'POST',
      '/proposicao/filtrar',
      body: filtros,
      noCache: noCache,
      forceRefresh: forceRefresh,
      network: () async {
        final decoded = await api.postJson('/proposicao/filtrar', filtros);
        return (decoded is Map)
            ? Map<String, dynamic>.from(decoded)
            : <String, dynamic>{'lista': decoded};
      },
    );
  }

  /// GET /proposicao/{codigo}
  Future<Map<String, dynamic>> proposicaoDetalhe(Object codigo, {bool noCache = false, bool forceRefresh = false}) {
    final c = codigo.toString();
    return request<Map<String, dynamic>>(
      'GET',
      '/proposicao/$c',
      noCache: noCache,
      forceRefresh: forceRefresh,
      network: () => api.getJson('/proposicao/$c'),
    );
  }

  /// GET /norma-legal/campos
  Future<Map<String, dynamic>> normaLegalCampos({bool noCache = false, bool forceRefresh = false}) {
    return request<Map<String, dynamic>>(
      'GET',
      '/norma-legal/campos',
      noCache: noCache,
      forceRefresh: forceRefresh,
      ttl: 24 * 60,
      network: () => api.getJson('/norma-legal/campos'),
    );
  }

  /// POST /norma-legal/filtrar
  Future<Map<String, dynamic>> normaLegalFiltrar(
      Map<String, dynamic> filtros, {
        bool noCache = false,
        bool forceRefresh = false,
      }) {
    return request<Map<String, dynamic>>(
      'POST',
      '/norma-legal/filtrar',
      body: filtros,
      noCache: noCache,
      forceRefresh: forceRefresh,
      network: () async {
        final decoded = await api.postJson('/norma-legal/filtrar', filtros);
        return (decoded is Map)
            ? Map<String, dynamic>.from(decoded)
            : <String, dynamic>{'lista': decoded};
      },
    );
  }

  /// GET /norma-legal/{codigo} com fallback para /normal-legal/{codigo}
  Future<Map<String, dynamic>> normaLegalDetalhe(Object codigo, {bool noCache = false, bool forceRefresh = false}) async {
    final c = codigo.toString();
    try {
      return await request<Map<String, dynamic>>(
        'GET',
        '/norma-legal/$c',
        noCache: noCache,
        forceRefresh: forceRefresh,
        network: () => api.getJson('/norma-legal/$c'),
      );
    } catch (_) {
      // fallback documentado em alguns lugares com typo
      return request<Map<String, dynamic>>(
        'GET',
        '/normal-legal/$c',
        noCache: noCache,
        forceRefresh: forceRefresh,
        network: () => api.getJson('/normal-legal/$c'),
      );
    }
  }

  /// Endpoint “coringa” para a aba de prestação de contas.
  /// Como o catálogo da ALEP pode variar, a tela tenta caminhos diferentes.
  Future<Map<String, dynamic>> prestacaoContasFiltrar(
      String path,
      Map<String, dynamic> filtros, {
        bool noCache = false,
        bool forceRefresh = false,
      }) {
    return request<Map<String, dynamic>>(
      'POST',
      path,
      body: filtros,
      noCache: noCache,
      forceRefresh: forceRefresh,
      network: () async {
        final decoded = await api.postJson(path, filtros);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return <String, dynamic>{'dados': decoded};
      },
    );
  }
}
