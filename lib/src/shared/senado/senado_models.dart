// Modelos leves e funções utilitárias para lidar com a resposta
// do dataset de "Senadores em exercício".

class SenadorResumo {
  final String codigo;
  final String nome;
  final String? nomeCompleto;
  final String? uf;
  final String? partido;
  final String? fotoUrl;
  final String? paginaUrl;
  final String? email;

  // Contatos do gabinete (quando disponíveis)
  final String? telefone;
  final String? fax;
  final String? gabinete;

  const SenadorResumo({
    required this.codigo,
    required this.nome,
    this.nomeCompleto,
    this.uf,
    this.partido,
    this.fotoUrl,
    this.paginaUrl,
    this.email,
    this.telefone,
    this.fax,
    this.gabinete,
  });

  /// Converte um item de lista (normalmente vindo de
  /// `ListaParlamentarEmExercicio.Parlamentares.Parlamentar`).
  ///
  /// Mantém parsing tolerante a pequenas variações de chave.
  factory SenadorResumo.fromListaItem(Map<String, dynamic> item) {
    final ident = (item['IdentificacaoParlamentar'] as Map?)?.cast<String, dynamic>() ??
        (item['identificacaoParlamentar'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final mandato = (item['Mandato'] as Map?)?.cast<String, dynamic>() ??
        (item['mandato'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    String? s(Map<String, dynamic> m, String k) {
      final v = m[k];
      if (v == null) return null;
      return v.toString().trim();
    }

    final codigo = (s(ident, 'CodigoParlamentar') ?? s(item, 'CodigoParlamentar') ?? s(item, 'codigo')) ?? '';
    final nome = (s(ident, 'NomeParlamentar') ?? s(item, 'NomeParlamentar') ?? s(item, 'nome')) ?? '';

    // Campos mais comuns na API
    final nomeCompleto = s(ident, 'NomeCompletoParlamentar') ?? s(ident, 'NomeCompleto');
    final uf = s(ident, 'UfParlamentar') ?? s(mandato, 'UfParlamentar') ?? s(item, 'UfParlamentar');
    final partido = s(ident, 'SiglaPartidoParlamentar') ?? s(item, 'SiglaPartidoParlamentar');
    final fotoUrl = s(ident, 'UrlFotoParlamentar') ?? s(item, 'UrlFotoParlamentar');
    final paginaUrl = s(ident, 'UrlPaginaParlamentar') ?? s(item, 'UrlPaginaParlamentar');
    final email = s(ident, 'EmailParlamentar') ?? s(item, 'EmailParlamentar');

    // Contatos de gabinete (nem sempre presentes no dataset)
    final telefone = s(mandato, 'Telefone') ?? s(mandato, 'TelefoneParlamentar') ?? s(item, 'Telefone');
    final fax = s(mandato, 'Fax') ?? s(item, 'Fax');
    final gabinete = s(mandato, 'Gabinete') ?? s(item, 'Gabinete');

    return SenadorResumo(
      codigo: codigo,
      nome: nome,
      nomeCompleto: nomeCompleto,
      uf: uf,
      partido: partido,
      fotoUrl: fotoUrl,
      paginaUrl: paginaUrl,
      email: email,
      telefone: telefone,
      fax: fax,
      gabinete: gabinete,
    );
  }

  Map<String, String?> toExtra() => {
        'nome': nome,
        'fotoUrl': fotoUrl,
        'partido': partido,
        'uf': uf,
      };
}

/// Extrai a lista de senadores em exercício a partir do JSON bruto.
///
/// O Senado às vezes muda pequenas partes da estrutura; a estratégia aqui é:
/// 1) navegar pelo caminho mais comum
/// 2) tentar caminhos alternativos
/// 3) como último recurso, procurar a primeira lista encontrada
List<SenadorResumo> parseSenadoresEmExercicio(Map<String, dynamic> root) {
  dynamic node = root['ListaParlamentarEmExercicio'] ?? root['listaParlamentarEmExercicio'] ?? root;

  dynamic listNode;
  // Estrutura mais comum:
  // ListaParlamentarEmExercicio -> Parlamentares -> Parlamentar -> [ ... ]
  if (node is Map) {
    final m = node.cast<String, dynamic>();
    final parlamentares = m['Parlamentares'] ?? m['parlamentares'];
    if (parlamentares is Map) {
      final pm = parlamentares.cast<String, dynamic>();
      listNode = pm['Parlamentar'] ?? pm['parlamentar'];
    } else {
      listNode = m['Parlamentar'] ?? m['parlamentar'];
    }
  }

  List<dynamic> items;
  if (listNode is List) {
    items = listNode;
  } else if (listNode is Map) {
    // Em alguns casos, vem como objeto único.
    items = [listNode];
  } else {
    // Fallback: procura a primeira lista em algum nível
    items = _firstListDeep(node) ?? const [];
  }

  final out = <SenadorResumo>[];
  for (final it in items) {
    if (it is Map<String, dynamic>) {
      final s = SenadorResumo.fromListaItem(it);
      if (s.codigo.isNotEmpty && s.nome.isNotEmpty) out.add(s);
    } else if (it is Map) {
      final s = SenadorResumo.fromListaItem(it.cast<String, dynamic>());
      if (s.codigo.isNotEmpty && s.nome.isNotEmpty) out.add(s);
    }
  }
  // Ordena para UX (como na lista de deputados)
  out.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
  return out;
}

List<dynamic>? _firstListDeep(dynamic node, [int depth = 0]) {
  if (depth > 6) return null; // evita recursão infinita em estruturas grandes
  if (node is List) return node;
  if (node is Map) {
    for (final v in node.values) {
      final found = _firstListDeep(v, depth + 1);
      if (found != null) return found;
    }
  }
  return null;
}
