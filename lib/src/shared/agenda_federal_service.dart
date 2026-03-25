// lib/src/shared/agenda_federal_service.dart
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom; // <- para tipar Element corretamente
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Modelo público para obrigações federais (Agenda Tributária)
class FedObligation {
  final DateTime date;
  final String title;
  final String? code;
  final String sourceUrl;
  const FedObligation({
    required this.date,
    required this.title,
    this.code,
    required this.sourceUrl,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'title': title,
    'code': code ?? '',
    'sourceUrl': sourceUrl,
  };
}

/// Serviço único: faz scraping do gov.br, parse e cache por mês (YYYY-MM).
/// Reutilize este serviço em QUALQUER lugar (Home, Calendário, etc.).
class AgendaFederalService {
  AgendaFederalService._();
  static final AgendaFederalService instance = AgendaFederalService._();

  final Map<String, List<FedObligation>> _cache = {}; // 'YYYY-MM' -> lista
  final http.Client _client = http.Client();

  // Headers para evitar respostas "capadas" / bloqueios de bot
  static const Map<String, String> _headers = {
    'User-Agent':
    'Mozilla/5.0 (Linux; Android 13; Flutter) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0 Mobile Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'pt-BR,pt;q=0.9',
    'Cache-Control': 'no-cache',
  };

  String _key(DateTime monthKey) =>
      '${monthKey.year.toString().padLeft(4, '0')}-${monthKey.month.toString().padLeft(2, '0')}';

  // ===== Persistência em disco (stale-while-revalidate) =====
  Duration diskTtl = const Duration(days: 1);

  Future<File> _fileFor(String key) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/agenda_federal_$key.json');
  }

  /// Hidrata o cache em memória a partir do disco para os meses informados.
  /// Use no boot para permitir renderização instantânea da Home.
  Future<void> hydrateFromDisk({required List<DateTime> months}) async {
    for (final m in months) {
      final k = _key(m);
      try {
        final f = await _fileFor(k);
        if (await f.exists()) {
          final jsonStr = await f.readAsString();
          final list = (json.decode(jsonStr) as List)
              .map((e) => FedObligation(
            date: DateTime.parse(e['date'] as String),
            title: e['title'] as String,
            code: ((e['code'] ?? '') as String).isEmpty ? null : e['code'] as String,
            sourceUrl: e['sourceUrl'] as String,
          ))
              .toList();
          _cache[k] = list;
          // refresh não-bloqueante
          // ignore: unawaited_futures
          _refreshFromNetwork(m, k);
        }
      } catch (_) {
        // segue a vida
      }
    }
  }

  Future<void> _saveToDisk(String key, List<FedObligation> list) async {
    try {
      final f = await _fileFor(key);
      await f.writeAsString(json.encode(list.map((e) => e.toJson()).toList()));
    } catch (_) {/* ignore */}
  }

  Future<void> _refreshFromNetwork(DateTime monthKey, String k) async {
    try {
      final fresh = await _fetchFromGovBr(year: monthKey.year, month: monthKey.month);
      _cache[k] = fresh;
      await _saveToDisk(k, fresh);
    } catch (_) {
      // mantém snapshot
    }
  }

  /// Retorna a lista do mês com cache memória+disco+rede.
  /// IMPORTANTE: se o arquivo em disco existir mas estiver **vazio**, força rede.
  Future<List<FedObligation>> getMonth(DateTime monthKey) async {
    final k = _key(monthKey);

    // 1) memória
    final mem = _cache[k];
    if (mem != null && mem.isNotEmpty) return mem;

    // 2) disco
    try {
      final f = await _fileFor(k);
      if (await f.exists()) {
        final jsonStr = await f.readAsString();
        final list = (json.decode(jsonStr) as List)
            .map((e) => FedObligation(
          date: DateTime.parse(e['date'] as String),
          title: e['title'] as String,
          code: ((e['code'] ?? '') as String).isEmpty ? null : e['code'] as String,
          sourceUrl: e['sourceUrl'] as String,
        ))
            .toList();
        _cache[k] = list;

        // Se veio vazio do disco, NÃO retorna; força rede síncrona.
        if (list.isNotEmpty) {
          // dispara refresh assíncrono e retorna já
          // ignore: unawaited_futures
          _refreshFromNetwork(monthKey, k);
          return list;
        }
      }
    } catch (_) {
      // segue para rede
    }

    // 3) rede (caminho certo quando disco está vazio/stale)
    final fresh = await _fetchFromGovBr(year: monthKey.year, month: monthKey.month);
    _cache[k] = fresh;
    await _saveToDisk(k, fresh);
    return fresh;
  }

  /// Lê o cache (ou vazio). Útil para montar listas rápidas enquanto carrega.
  List<FedObligation> peekMonth(DateTime monthKey) {
    final k = _key(monthKey);
    return _cache[k] ?? const <FedObligation>[];
  }

  // ==========
  // Utilidades
  // ==========
  Future<void> invalidateMonth(DateTime monthKey) async {
    final k = _key(monthKey);
    _cache.remove(k);
    try {
      final f = await _fileFor(k);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<List<FedObligation>> refreshNow(DateTime monthKey) async {
    final k = _key(monthKey);
    await invalidateMonth(monthKey);
    final fresh = await _fetchFromGovBr(year: monthKey.year, month: monthKey.month);
    _cache[k] = fresh;
    await _saveToDisk(k, fresh);
    return fresh;
  }

  Future<void> clearAllCache() async {
    _cache.clear();
    try {
      final dir = await getApplicationSupportDirectory();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('agenda_federal_') && f.path.endsWith('.json'));
      for (final f in files) {
        try {
          await f.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  // ==========================
  // HTTP utilitário
  // ==========================
  Future<http.Response> _get(String url, {int depth = 0}) async {
    final resp = await _client.get(Uri.parse(url), headers: _headers);

    // Segue 3xx preservando headers
    if (resp.isRedirect || (resp.statusCode >= 300 && resp.statusCode < 400)) {
      if (depth > 4) {
        throw Exception('Redirecionamentos em excesso para $url');
      }
      final loc = resp.headers['location'];
      if (loc == null || loc.isEmpty) {
        throw Exception('Redirecionamento sem Location em $url');
      }
      final resolved = Uri.parse(url).resolve(loc).toString();
      return _get(resolved, depth: depth + 1);
    }

    if (resp.statusCode != 200 || resp.body.isEmpty) {
      throw Exception('HTTP ${resp.statusCode} em $url');
    }
    return resp;
  }

  // ==========================
  // Scraping + parsing gov.br
  // ==========================
  Future<List<FedObligation>> _fetchFromGovBr({
    required int year,
    required int month,
  }) async {
    // Slugs do site (sem acento)
    const mesPtSlug = {
      1: 'janeiro',
      2: 'fevereiro',
      3: 'marco',
      4: 'abril',
      5: 'maio',
      6: 'junho',
      7: 'julho',
      8: 'agosto',
      9: 'setembro',
      10: 'outubro',
      11: 'novembro',
      12: 'dezembro',
    };
    final mesSlug = mesPtSlug[month]!;
    final monthUrl =
        'https://www.gov.br/receitafederal/pt-br/assuntos/agenda-tributaria/$year/$mesSlug';

    final monthResp = await _get(monthUrl);
    final doc = html.parse(monthResp.body);

    // Coleta links de dias aceitando:
    //  - .../dia-DD-MM-YYYY
    //  - .../DD-MM-YYYY
    // + tolerância a '/' final e querystring, e links RELATIVOS.
    final dayLinks = <String>{};
    final dayRe = RegExp(r'/(?:dia-)?(\d{1,2})-(\d{1,2})-(\d{4})(?:/|\?.*)?$');

    for (final a in doc.querySelectorAll('a[href]')) {
      final rawHref = (a.attributes['href'] ?? '').trim();
      if (rawHref.isEmpty) continue;

      // Resolve relativo em relação à página do mês
      final abs = rawHref.startsWith('http')
          ? rawHref
          : Uri.parse(monthUrl).resolve(rawHref).toString();

      if (!dayRe.hasMatch(abs)) continue;

      // Canonicaliza (remove query e barra final)
      final canonical = abs.split('?').first.replaceAll(RegExp(r'/$'), '');
      dayLinks.add(canonical);
    }

    // Fallback: alguns meses têm um link "Vencimentos diários" intermediário
    if (dayLinks.isEmpty) {
      final anchors = doc.querySelectorAll('a[href]');
      dom.Element? altAnchor;
      for (final a in anchors) {
        final text = a.text.trim().toLowerCase();
        final titleAttr = (a.attributes['title'] ?? '').toLowerCase();
        if (text.contains('vencimentos di') || titleAttr.contains('vencimentos di')) {
          altAnchor = a;
          break;
        }
      }
      if (altAnchor != null) {
        try {
          final altUrl = Uri.parse(monthUrl)
              .resolve((altAnchor.attributes['href'] ?? '').trim())
              .toString();
          final altResp = await _get(altUrl);
          final altDoc = html.parse(altResp.body);
          for (final a in altDoc.querySelectorAll('a[href]')) {
            final rawHref = (a.attributes['href'] ?? '').trim();
            if (rawHref.isEmpty) continue;
            final abs = rawHref.startsWith('http')
                ? rawHref
                : Uri.parse(altUrl).resolve(rawHref).toString();
            if (!dayRe.hasMatch(abs)) continue;
            final canonical = abs.split('?').first.replaceAll(RegExp(r'/$'), '');
            dayLinks.add(canonical);
          }
        } catch (_) {}
      }
    }

    // Ordem determinística (opcional)
    final orderedLinks = dayLinks.toList()..sort();

    final out = <FedObligation>[];
    for (final link in orderedLinks) {
      try {
        final dayResp = await _get(link);
        final dayDoc = html.parse(dayResp.body);
        final date = _extractDateFromUrl(link);

        // 1) tabelas
        final fromTables = _extractFromTables(dayDoc, date, link);
        if (fromTables.isNotEmpty) {
          out.addAll(fromTables);
        } else {
          // 2) listas
          final fromLists = _extractFromLists(dayDoc, date, link);
          if (fromLists.isNotEmpty) {
            out.addAll(fromLists);
          } else {
            // 3) parágrafos (fallback)
            out.addAll(_extractFromParagraphs(dayDoc, date, link));
          }
        }
      } catch (_) {
        // tolerante: ignora erro pontual
      }
    }

    out.sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.title.compareTo(b.title);
    });
    return out;
  }

  DateTime _extractDateFromUrl(String url) {
    // remove query/fragment e barra final
    final clean = url.split('?').first.replaceAll(RegExp(r'/$'), '');
    // Aceita com ou sem 'dia-'
    final m =
    RegExp(r'(?:^|/)(?:dia-)?(\d{1,2})-(\d{1,2})-(\d{4})(?:$|[/?#])').firstMatch(clean);
    if (m == null) {
      throw FormatException('Não foi possível extrair a data de: $url');
    }
    final d = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final y = int.parse(m.group(3)!);
    return DateTime(y, mo, d);
  }

  List<FedObligation> _extractFromTables(dynamic doc, DateTime date, String sourceUrl) {
    final out = <FedObligation>[];
    for (final table in doc.querySelectorAll('table')) {
      for (final tr in table.querySelectorAll('tr')) {
        // lê TH e TD (muitos cabeçalhos usam TH)
        final cells = [
          ...tr.querySelectorAll('th'),
          ...tr.querySelectorAll('td'),
        ].map((e) => e.text.trim()).where((e) => e.isNotEmpty).toList();

        if (cells.isEmpty) continue;
        final text = cells.join(' — ');
        if (text.length < 6) continue;

        String? code;
        String title = text.replaceAll(RegExp(r'\s+'), ' ');
        final m = RegExp(r'^(\d{3,5})\s*[-–]\s*(.+)$').firstMatch(title);
        if (m != null) {
          code = m.group(1);
          title = m.group(2)!.trim();
        }
        // Evita capturar linha de cabeçalho puro
        if (title.toLowerCase().contains('agenda tributária') && !title.contains(RegExp(r'\d'))) {
          continue;
        }

        out.add(FedObligation(date: date, title: title, code: code, sourceUrl: sourceUrl));
      }
    }
    return out;
  }

  List<FedObligation> _extractFromLists(dynamic doc, DateTime date, String sourceUrl) {
    final out = <FedObligation>[];
    for (final ul in doc.querySelectorAll('ul, ol')) {
      for (final li in ul.querySelectorAll('li')) {
        var text = li.text.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (text.length < 6) continue;
        String? code;
        final m = RegExp(r'^(\d{3,5})\s*[-–]\s*(.+)$').firstMatch(text);
        if (m != null) {
          code = m.group(1);
          text = m.group(2)!.trim();
        }
        out.add(FedObligation(date: date, title: text, code: code, sourceUrl: sourceUrl));
      }
    }
    return out;
  }

  List<FedObligation> _extractFromParagraphs(dynamic doc, DateTime date, String sourceUrl) {
    final out = <FedObligation>[];
    final main = doc.querySelector('main') ?? doc.body;
    if (main == null) return out;
    for (final p in main.querySelectorAll('p')) {
      final text = p.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (text.length < 10) continue;
      String? code;
      String title = text;
      final m = RegExp(r'^(\d{3,5})\s*[-–]\s*(.+)$').firstMatch(text);
      if (m != null) {
        code = m.group(1);
        title = m.group(2)!.trim();
      }
      out.add(FedObligation(date: date, title: title, code: code, sourceUrl: sourceUrl));
    }
    return out;
  }
}
