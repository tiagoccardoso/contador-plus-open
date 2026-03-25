import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cliente simples para a API de Dados Abertos do Senado.
///
/// Observação importante: alguns endpoints históricos do Senado retornam XML
/// por padrão e aceitam JSON via sufixo `.json`. Para aumentar a robustez,
/// este cliente tenta mais de uma URL quando faz sentido.
class SenadoApiClient {
  static const String _base = 'https://legis.senado.leg.br/dadosabertos';

  final http.Client _http;

  SenadoApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  Future<Map<String, dynamic>> _getJsonWithFallback(List<Uri> urls) async {
    Object? lastError;
    for (final url in urls) {
      try {
        final res = await _http.get(url, headers: const {'Accept': 'application/json'});
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw http.ClientException('HTTP ${res.statusCode}', url);
        }
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
        throw const FormatException('Resposta JSON inesperada (não é objeto).');
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? StateError('Falha ao buscar dados do Senado.');
  }

  /// Lista os senadores em exercício.
  ///
  /// Preferimos endpoints com `.json`. Se algum deles estiver indisponível,
  /// tentamos alternativas oficiais que apontam para o mesmo dataset.
  Future<Map<String, dynamic>> getListaSenadoresEmExercicioRaw() {
    return _getJsonWithFallback([
      Uri.parse('$_base/senador/lista/atual.json'),
      Uri.parse('$_base/dados/ListaParlamentarEmExercicio.json'),
      Uri.parse('$_base/arquivos/ListaParlamentarEmExercicio.json'),
    ]);
  }

  /// Detalhamento do senador por código (quando disponível em JSON).
  ///
  /// Nem sempre é necessário para a tela (muitas infos já vêm na lista),
  /// mas fica aqui para expansões futuras.
  Future<Map<String, dynamic>> getSenadorDetalheRaw(String codigo) {
    return _getJsonWithFallback([
      Uri.parse('$_base/senador/$codigo.json'),
      Uri.parse('$_base/senador/$codigo/detalhe.json'),
    ]);
  }

  /// Mandatos do senador por código.
  Future<Map<String, dynamic>> getSenadorMandatosRaw(String codigo) {
    return _getJsonWithFallback([
      Uri.parse('$_base/senador/$codigo/mandatos.json'),
    ]);
  }
}
