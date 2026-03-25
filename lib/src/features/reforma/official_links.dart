/// Links oficiais e utilidades para consulta de Reforma Tributária (versão pública).
class OfficialLinks {
  // Receita Federal
  static final Uri rfReforma = Uri.parse(
    'https://www.gov.br/receitafederal/pt-br/servicos/reforma-tributaria',
  );
  static final Uri rfProgramaConsumo = Uri.parse(
    'https://www.gov.br/receitafederal/pt-br/acesso-a-informacao/acoes-e-programas/programas-e-atividades/reforma-consumo',
  );

  // Ministério da Fazenda
  static final Uri mfReforma = Uri.parse(
    'https://www.gov.br/fazenda/pt-br/acesso-a-informacao/acoes-e-programas/reforma-tributaria',
  );
  static final Uri mfVideos = Uri.parse(
    'https://www.gov.br/fazenda/pt-br/acesso-a-informacao/acoes-e-programas/reforma-tributaria/videos',
  );

  /// Busca pública na Central de Soluções (fallback via Google site search).
  static Uri dominioPublicSearch([String q = 'Reforma Tributária', String? base]) {
    if (base != null && base.isNotEmpty) {
      return Uri.parse('$base${Uri.encodeComponent(q)}');
    }
    final query = 'site:suporte.dominioatendimento.com OR site:centraldesolucoes.dominiosistemas.com.br $q';
    return Uri.parse('https://www.google.com/search?q=${Uri.encodeComponent(query)}');
  }

  /// Home pública da Central de Soluções (link solicitado).
  static final Uri dominioPublicHome = Uri.parse(
    'https://suporte.dominioatendimento.com/central/faces/central-solucoes.html',
  );

  /// Artigo do módulo Reforma Tributária na Central (pode exigir login).
  static final Uri dominioModulo = Uri.parse(
    'https://suporte.dominioatendimento.com/central/faces/solucao.html?codigo=11962',
  );
}
