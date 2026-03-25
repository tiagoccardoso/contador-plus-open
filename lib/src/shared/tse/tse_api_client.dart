import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Cliente HTTP para a API pública do TSE (DivulgaCandContas).
///
/// Base: https://divulgacandcontas.tse.jus.br/divulga/rest/v1
///
/// Observações:
/// - alguns endpoints retornam **202** (Accepted)
/// - a API pode responder com **429** (rate limit) ou instabilidades 5xx
/// - evitar martelar o serviço: este client aplica um *throttle* leve
class TseApiClient {
  static const String host = 'divulgacandcontas.tse.jus.br';
  static const String basePath = '/divulga/rest/v1';

  final http.Client _http;
  final Duration minInterval;
  final Duration timeout;
  final int maxAttempts;

  final Random _rnd = Random();
  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _gate = Future.value();

  TseApiClient({
    http.Client? httpClient,
    this.minInterval = const Duration(milliseconds: 150),
    this.timeout = const Duration(seconds: 25),
    this.maxAttempts = 3,
  }) : _http = httpClient ?? http.Client();

  void close() => _http.close();

  Uri _buildUri(String path, [Map<String, dynamic>? params]) {
    final qp = <String, String>{};
    params?.forEach((k, v) {
      if (v == null) return;
      final s = v.toString().trim();
      if (s.isEmpty) return;
      qp[k] = s;
    });
    return Uri.https(host, '$basePath$path', qp.isEmpty ? null : qp);
  }

  bool _ok(int code) => (code >= 200 && code < 300) || code == 202;

  bool _isRetryableStatus(int code) => code == 408 || code == 429 || code >= 500;

  Duration _backoff(int attempt) {
    // attempt: 1..N
    final baseMs = 400 * pow(2, attempt - 1).toInt();
    final jitter = _rnd.nextInt(250);
    final ms = min<int>(baseMs + jitter, 4000);
    return Duration(milliseconds: ms);
  }

  Duration? _retryAfter(http.Response r) {
    final h = r.headers['retry-after'];
    if (h == null || h.trim().isEmpty) return null;
    final s = h.trim();
    final seconds = int.tryParse(s);
    if (seconds != null) return Duration(seconds: seconds);
    final dt = HttpDate.parse(s);
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return null;
    return diff;
  }

  Future<void> _throttle() {
    // Gate serializa todas as requisições e garante um intervalo mínimo entre elas.
    _gate = _gate.then((_) async {
      final now = DateTime.now();
      final wait = minInterval - now.difference(_lastRequest);
      if (wait > Duration.zero) await Future.delayed(wait);
      _lastRequest = DateTime.now();
    });
    return _gate;
  }

  dynamic _decode(http.Response r) {
    if (r.bodyBytes.isEmpty) return null;
    return json.decode(utf8.decode(r.bodyBytes));
  }

  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function() call,
    Uri uri,
  ) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await _throttle();
        final r = await call().timeout(timeout);
        if (_ok(r.statusCode)) return r;

        // Erros definitivos (4xx fora 408/429): não retry.
        if (!_isRetryableStatus(r.statusCode)) {
          throw http.ClientException('HTTP ${r.statusCode} em ${uri.toString()}', uri);
        }

        // Retry-After tem prioridade no 429.
        final ra = (r.statusCode == 429) ? _retryAfter(r) : null;
        if (attempt >= maxAttempts) {
          throw http.ClientException('HTTP ${r.statusCode} em ${uri.toString()}', uri);
        }
        await Future.delayed(ra ?? _backoff(attempt));
      } on TimeoutException catch (e) {
        lastError = e;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(_backoff(attempt));
      } on SocketException catch (e) {
        lastError = e;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(_backoff(attempt));
      } on http.ClientException catch (e) {
        // Se chegou aqui, pode ser retryable que estourou tentativas.
        lastError = e;
        rethrow;
      } catch (e) {
        lastError = e;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(_backoff(attempt));
      }
    }
    // should not reach
    throw http.ClientException('Falha desconhecida: $lastError', uri);
  }

  Future<dynamic> getJson(String path, {Map<String, dynamic>? params}) async {
    final uri = _buildUri(path, params);
    final r = await _sendWithRetry(
      () => _http.get(uri, headers: const {'accept': 'application/json'}),
      uri,
    );
    return _decode(r);
  }

  Future<dynamic> postJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, dynamic>? params,
  }) async {
    final uri = _buildUri(path, params);
    final payload = json.encode(body);
    final r = await _sendWithRetry(
      () => _http.post(
        uri,
        headers: const {
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: payload,
      ),
      uri,
    );
    return _decode(r);
  }
}
