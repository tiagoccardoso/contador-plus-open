
import 'dart:convert';
import 'package:dio/dio.dart';

class SupportArticle {
  final String title;
  final String url;
  final String snippet;

  SupportArticle({required this.title, required this.url, required this.snippet});
}

/// Scraper muito simples para o portal de soluções da Domínio.
/// Estratégia: baixar o HTML e extrair <a> com possíveis resultados.
/// Observação: HTML pode mudar; tratamos como best-effort.
class DominioSupportScraper {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': 'ContadorPlus/1.0 (+flutter)',
    },
  ));

  static const String base = 'https://suporte.dominioatendimento.com/central/faces/central-solucoes.html';

  Future<List<SupportArticle>> search(String query) async {
    try {
      // Muitas centrais de solução aceitam `?search=` ou usam hash; aqui tentamos GET com query genérica.
      final resp = await _dio.get(base, queryParameters: {'q': query});
      final html = resp.data is String ? resp.data as String : utf8.decode((resp.data as List<int>));
      final results = <SupportArticle>[];

      // Regex bem permissivo para capturar links da própria central, com pequeno trecho do texto ao redor.
      final linkRe = RegExp(r'<a[^>]+href="([^"]+central[^"]+)"[^>]*>(.*?)</a>', caseSensitive: false);
      for (final m in linkRe.allMatches(html).take(30)) {
        final href = m.group(1) ?? '';
        final text = _stripTags(m.group(2) ?? '');
        if (href.isEmpty) continue;
        final url = href.startsWith('http')
            ? href
            : Uri.https(
                'suporte.dominioatendimento.com',
                href.startsWith('/') ? href : '/' + href,
              ).toString();
        if (text.trim().isEmpty) continue;
        results.add(SupportArticle(title: text.trim(), url: url, snippet: ''));
      }

      // Snippets (parágrafos) próximos do link — tentativa simples
      final paraRe = RegExp(r'<p>([^<]{40,300})</p>', caseSensitive: false);
      final paras = paraRe.allMatches(html).map((m) => _stripTags(m.group(1) ?? '').trim()).toList();
      for (var i = 0; i < results.length; i++) {
        if (i < paras.length) {
          results[i] = SupportArticle(title: results[i].title, url: results[i].url, snippet: paras[i]);
        }
      }

      // Se nada encontrado, devolve vazio (UI lida com isso).
      return results;
    } catch (_) {
      return [];
    }
  }

  String _stripTags(String s) => s
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
