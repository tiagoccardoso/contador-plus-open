// lib/src/shared/alep/alep_api_client.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Cliente simples para a API pública da ALEP.
/// Base padrão: https://webservices.assembleia.pr.leg.br/api/public
/// (com fallback para http, porque em alguns ambientes o TLS pode falhar)
class AlepApiClient {
  static const String _host = 'webservices.assembleia.pr.leg.br';
  static const String _basePath = '/api/public';

  final http.Client _http;

  AlepApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  Uri _uri(String scheme, String path, [Map<String, dynamic>? params]) {
    final qp = <String, String>{};
    params?.forEach((k, v) {
      if (v == null) return;
      final s = v.toString().trim();
      if (s.isEmpty) return;
      qp[k] = s;
    });
    return Uri(scheme: scheme, host: _host, path: '$_basePath$path', queryParameters: qp.isEmpty ? null : qp);
  }

  Future<http.Response> _sendWithFallback(Future<http.Response> Function(String scheme) send) async {
    try {
      final r = await send('https');
      return r;
    } catch (_) {
      // fallback para http
      return send('http');
    }
  }

  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? params}) async {
    final r = await _sendWithFallback((scheme) {
      final uri = _uri(scheme, path, params);
      return _http.get(uri, headers: {'accept': 'application/json'});
    });

    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw http.ClientException('HTTP ${r.statusCode} em $path', r.request?.url);
    }
    final decoded = json.decode(utf8.decode(r.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    // alguns endpoints podem devolver lista; embrulha para manter tipo.
    return {'data': decoded};
  }

  /// POST que retorna o JSON decodificado (pode ser Map ou List).
  /// Alguns endpoints da ALEP (ex.: /proposicao/filtrar) retornam um Map
  /// com chaves como "lista" e "totalRegistrosSemLimitador".
  Future<dynamic> postJson(String path, Map<String, dynamic> body) async {
    final r = await _sendWithFallback((scheme) {
      final uri = _uri(scheme, path);
      return _http.post(
        uri,
        headers: {'accept': 'application/json', 'content-type': 'application/json'},
        body: json.encode(body),
      );
    });

    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw http.ClientException('HTTP ${r.statusCode} em $path', r.request?.url);
    }
    final decoded = json.decode(utf8.decode(r.bodyBytes));
    return decoded;
  }

  /// Faz GET em uma URL absoluta (fora da base /api/public) e retorna o corpo como texto.
  ///
  /// Usado quando a UI precisa ler páginas do Portal da Transparência (HTML) para obter
  /// dados que a API pública não expõe de forma adequada (ex.: lista de parlamentares
  /// apenas “pessoas”, sem órgãos/entidades).
  Future<String> getTextAbsolute(String url) async {
    final uri = Uri.parse(url);
    final r = await _http.get(uri, headers: {'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'});
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw http.ClientException('HTTP ${r.statusCode} em $url', r.request?.url);
    }
    return utf8.decode(r.bodyBytes);
  }
}
