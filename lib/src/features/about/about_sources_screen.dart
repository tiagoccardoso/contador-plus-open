import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class AboutSourcesScreen extends StatefulWidget {
  const AboutSourcesScreen({super.key});

  @override
  State<AboutSourcesScreen> createState() => _AboutSourcesScreenState();
}

class _AboutSourcesScreenState extends State<AboutSourcesScreen> {
  PackageInfo? _pkg;
  DateTime? _ultimaAtualizacao;
  List<_FonteOficial> _fontesOficiais = const <_FonteOficial>[];

  @override
  void initState() {
    super.initState();
    _loadPkg();
    _loadFontesOficiais();
  }

  Future<void> _loadPkg() async {
    try {
      final p = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _pkg = p);
    } catch (_) {
      // silencioso
    }
  }

  Future<void> _loadFontesOficiais() async {
    try {
      final raw = await rootBundle.loadString('assets/data/obrigacoes.json');
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;

      final atualizadoEm = decoded['atualizadoEm']?.toString();
      final fontes = (decoded['fontes'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((m) => _FonteOficial(
                titulo: (m['titulo'] ?? 'Fonte oficial').toString(),
                url: (m['url'] ?? '').toString(),
              ))
          .where((f) => f.url.trim().isNotEmpty)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _ultimaAtualizacao = atualizadoEm == null ? null : DateTime.tryParse(atualizadoEm);
        _fontesOficiais = fontes;
      });
    } catch (_) {
      // silencioso
    }
  }


  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _goCalendar(BuildContext context) {
    // GoRouter: vai para a tela do calendário.
    // Se você usa rotas nomeadas, prefira: context.goNamed('calendar');
    context.go('/calendar');
  }

  @override
  Widget build(BuildContext context) {
    final pkg = _pkg;
    final versionStr =
        pkg == null ? '—' : '${pkg.appName} • v${pkg.version} (${pkg.buildNumber})';

    final ultimaAtualizacao = _ultimaAtualizacao;

    final ultimaStr = ultimaAtualizacao == null
        ? null
        : DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(ultimaAtualizacao.toLocal());

    // Lista de páginas oficiais consultadas na última sincronização.
    final fontesOficiais = _fontesOficiais;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobre & Fontes'),
        leading: IconButton(
          tooltip: 'Calendário',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => _goCalendar(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Cabeçalho do app
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(versionStr),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Calendário fiscal com fontes oficiais e IA para tirar dúvidas.\n'
                        'App contábil • Transparência e cidadania.',
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Isenção
            const _SectionHeader('Isenção de responsabilidade'),
            const Text(
              'Este aplicativo é independente e não representa, não endossa e não possui qualquer afiliação '
                  'com órgãos governamentais, Poder Executivo, Legislativo ou entidades públicas. '
                  'Os prazos e links exibidos são organizados a partir de conteúdos públicos publicados em sites '
                  'oficiais e materiais de apoio públicos. Sempre confirme a informação diretamente na fonte antes de '
                  'cumprir qualquer obrigação ou tomar decisões.',
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 12),
            const Text(
              'O app e o assistente de IA têm caráter exclusivamente informativo e não prestam assessoria contábil, '
                  'jurídica ou fiscal. Opiniões, explicações ou resumos não substituem a leitura integral dos atos oficiais '
                  'nem a orientação de profissional habilitado.',
              textAlign: TextAlign.justify,
            ),

            const SizedBox(height: 16),

            // Última atualização
            const _SectionHeader('Última atualização (calendário)'),
            if (ultimaAtualizacao == null)
              const Text(
                'A data e a hora da última sincronização do calendário são exibidas na tela principal do app, '
                    'junto às obrigações. Esta tela de ajuda descreve apenas como as informações são obtidas e quais '
                    'fontes oficiais podem ser consultadas.',
                textAlign: TextAlign.justify,
              )
            else
              Text(ultimaStr ?? ''),

            const SizedBox(height: 16),

            // Fontes oficiais deste mês
            const _SectionHeader('Fontes oficiais deste mês'),
            const Text(
              'O app registra internamente quais páginas oficiais foram consultadas para montar o calendário. '
                  'Quando disponível, a lista abaixo mostra os links exatos lidos na sincronização mais recente.',
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 8),
            if (fontesOficiais.isEmpty)
              const Text(
                'Não foi possível carregar uma lista detalhada de páginas consultadas. '
                    'As obrigações mostradas no calendário vêm das páginas públicas da Agenda Tributária, '
                    'conforme descrito na seção de fontes permanentes.',
                style: TextStyle(fontStyle: FontStyle.italic),
                textAlign: TextAlign.justify,
              )
            else
              ...fontesOficiais
                  .map((f) => _FonteTile(f: f, onOpen: _open)),

            const SizedBox(height: 20),

            // Fontes oficiais permanentes
            const _SectionHeader('Fontes oficiais permanentes'),
            const Text(
              'Além das páginas diárias da Agenda Tributária, o app pode abrir os seguintes portais e serviços '
                  'oficiais governamentais e legislativos, conforme os links exibidos nas telas de detalhes e de ajuda:',
              textAlign: TextAlign.justify,
            ),

            const SizedBox(height: 12),

            // Agenda Tributária
            _LinkTile(
              icon: Icons.account_balance_outlined,
              title: 'Receita Federal — Agenda Tributária',
              subtitle:
              'Páginas oficiais mensais e diárias com prazos de obrigações tributárias federais.',
              links: const {
                'Agenda Tributária (portal)':
                'https://www.gov.br/receitafederal/pt-br/assuntos/agenda-tributaria',
              },
              onOpen: _open,
            ),

            // Normas & legislação tributária
            _LinkTile(
              icon: Icons.gavel_outlined,
              title: 'Normas tributárias (RFB / DOU)',
              subtitle:
              'Consulta de atos normativos da Receita Federal e publicações no Diário Oficial da União, '
                  'inclusive normas relacionadas à DCTFWeb.',
              links: const {
                'Normas da Receita Federal':
                'http://normas.receita.fazenda.gov.br/sijut2consulta/consulta.action',
                'Diário Oficial — busca DCTFWeb':
                'https://www.in.gov.br/consulta/-/buscar/dou?q=DCTFWeb',
              },
              onOpen: _open,
            ),

            // Obrigações trabalhistas e regimes especiais
            _LinkTile(
              icon: Icons.work_outline,
              title: 'Obrigações trabalhistas e regimes especiais',
              subtitle:
              'Portais oficiais relacionados a eSocial, FGTS Digital e ao regime do Simples Nacional.',
              links: const {
                'Portal eSocial': 'https://www.gov.br/esocial/pt-br',
                'FGTS Digital — MTE':
                'https://www.gov.br/trabalho-e-emprego/pt-br/assuntos/fgts-digital',
                'Portal do Simples Nacional':
                'https://www.gov.br/receitafederal/pt-br/assuntos/simples-nacional',
              },
              onOpen: _open,
            ),

            // Reforma Tributária
            _LinkTile(
              icon: Icons.auto_graph_outlined,
              title: 'Reforma Tributária — conteúdos oficiais',
              subtitle:
              'Materiais, explicações e serviços sobre a Reforma Tributária em portais da Receita Federal e do Ministério da Fazenda.',
              links: const {
                'Receita Federal — Reforma Tributária':
                'https://www.gov.br/receitafederal/pt-br/servicos/reforma-tributaria',
                'Receita Federal — Programa Reforma do Consumo':
                'https://www.gov.br/receitafederal/pt-br/acesso-a-informacao/acoes-e-programas/programas-e-atividades/reforma-consumo',
                'Ministério da Fazenda — Reforma Tributária':
                'https://www.gov.br/fazenda/pt-br/acesso-a-informacao/acoes-e-programas/reforma-tributaria',
                'Ministério da Fazenda — Futuro Seguro / Reforma Tributária':
                'https://www.gov.br/fazenda/pt-br/acesso-a-informacao/acoes-e-programas/futuro-seguro/reforma-tributaria',
                'Ministério da Fazenda — vídeos (Reforma Tributária)':
                'https://www.gov.br/fazenda/pt-br/acesso-a-informacao/acoes-e-programas/reforma-tributaria/videos',
                'Receita Federal — Entenda a Reforma do Consumo':
                'https://www.gov.br/receitafederal/pt-br/acesso-a-informacao/acoes-e-programas/programas-e-atividades/reforma-consumo/entenda',
                'Portal da Receita Federal (RFB)':
                'https://www.gov.br/receita/',

              },
              onOpen: _open,
            ),

            // Legislação de referência (Planalto)
            _LinkTile(
              icon: Icons.menu_book_outlined,
              title: 'Legislação de referência (Planalto)',
              subtitle:
              'Texto oficial da Constituição (emendas) e leis complementares relacionadas à Reforma Tributária.',
              links: const {
                'EC nº 132/2023 — Reforma Tributária do Consumo':
                'https://www.planalto.gov.br/ccivil_03/constituicao/emendas/emc/emc132.htm',
                'LC nº 214/2023 — normas complementares':
                'https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp214.htm',
              },
              onOpen: _open,
            ),

            // Poder Legislativo
            _LinkTile(
              icon: Icons.account_balance,
              title: 'Poder Legislativo federal — dados públicos',
              subtitle:
              'Dados abertos, notícias e tramitações de proposições na Câmara dos Deputados e no Senado Federal.',
              links: const {
                'Câmara — API de Dados Abertos':
                'https://dadosabertos.camara.leg.br/api/v2',
                'Senado — Dados Abertos (API)':
                'https://legis.senado.leg.br/dadosabertos',
                'Senado — documentação da API (Swagger)':
                'https://legis.senado.leg.br/dadosabertos/api-docs/swagger-ui/index.html',
                'Câmara — notícia da regulamentação da Reforma Tributária':
                'https://www.camara.leg.br/noticias/1127237-regulamentacao-da-reforma-tributaria-e-sancionada-conheca-a-nova-lei/',
                'Câmara — tramitação da regulamentação da Reforma Tributária':
                'https://www.camara.leg.br/proposicoesWeb/fichadetramitacao?idProposicao=2430143',
                'Senado Federal — notícias':
                'https://www12.senado.leg.br/noticias',
                'Senado Federal — notícia sobre fase de testes e transição dos novos tributos':
                'https://www12.senado.leg.br/noticias/materias/2024/12/16/novos-tributos-comecam-a-ser-testados-em-2026-e-transicao-vai-ate-2033',
                'Senado Federal — tramitação de matérias':
                'https://www25.senado.leg.br/web/atividade/materias/',
                'Senado Federal — matéria específica da regulamentação':
                'https://www25.senado.leg.br/web/atividade/materias/-/materia/164914',
              },
              onOpen: _open,
            ),


            // Senado (Administrativo)
            _LinkTile(
              icon: Icons.receipt_long_outlined,
              title: 'Senado — Dados Abertos Administrativo',
              subtitle:
                  'API pública do Senado (área administrativa) usada para consultas de despesas e transparência.',
              links: const {
                'Portal Dados Abertos Administrativo':
                    'https://adm.senado.gov.br/adm-dadosabertos',
                'API (base)':
                    'https://adm.senado.gov.br/adm-dadosabertos/api/v1/',
              },
              onOpen: _open,
            ),

            // Justiça Eleitoral (TSE)
            _LinkTile(
              icon: Icons.how_to_vote_outlined,
              title: 'Justiça Eleitoral — TSE (DivulgaCandContas)',
              subtitle:
                  'API pública do TSE usada para consultar informações divulgadas de candidaturas e prestação de contas.',
              links: const {
                'API pública (base)':
                    'https://divulgacandcontas.tse.jus.br/divulga/rest/v1',
                'Portal DivulgaCandContas':
                    'https://divulgacandcontas.tse.jus.br/',
              },
              onOpen: _open,
            ),

            // Assembleia Legislativa do Paraná (ALEP)
            _LinkTile(
              icon: Icons.groups_outlined,
              title: 'Assembleia Legislativa do Paraná (ALEP) — dados públicos',
              subtitle:
                  'API e páginas públicas usadas para listar deputados e consultar dados de proposições e ressarcimentos.',
              links: const {
                'API pública (webservices)':
                    'https://webservices.assembleia.pr.leg.br/api/public',
                'Deputados (lista pública)':
                    'https://www.assembleia.pr.leg.br/deputados/conheca',
                'Fotos de deputados (diretório base)':
                    'https://www.assembleia.pr.leg.br/cache/imagens/deputados/small/',
                'Portal de consultas (prestação de contas)':
                    'https://consultas.assembleia.pr.leg.br/',
              },
              onOpen: _open,
            ),

            // Poder Judiciário
            _LinkTile(
              icon: Icons.balance_outlined,
              title: 'Poder Judiciário — STF',
              subtitle:
                  'Página do STF usada como referência em eventos e julgados relacionados a temas tributários.',
              links: const {
                'Portal do STF': 'https://portal.stf.jus.br/',
              },
              onOpen: _open,
            ),

            // Materiais de apoio Domínio
            _LinkTile(
              icon: Icons.school_outlined,
              title: 'Materiais de apoio — Domínio Sistemas',
              subtitle:
              'Artigos e materiais técnicos da Central de Soluções Domínio, usados como referência complementar para rotinas e obrigações acessórias.',
              links: const {
                'Central de Soluções Domínio':
                'https://suporte.dominioatendimento.com/central/faces/central-solucoes.html',
                'Domínio — solução 11962':
                'https://suporte.dominioatendimento.com/central/faces/solucao.html?codigo=11962',
                'Domínio — solução 3973':
                'https://suporte.dominioatendimento.com/central/faces/solucao.html?codigo=3973',
                'Domínio — solução 5015':
                'https://suporte.dominioatendimento.com/central/faces/solucao.html?codigo=5015',
                'Domínio — solução 5105':
                'https://suporte.dominioatendimento.com/central/faces/solucao.html?codigo=5105',
                'Domínio — solução 6020':
                'https://suporte.dominioatendimento.com/central/faces/solucao.html?codigo=6020',
                'Domínio — solução 6044':
                'https://suporte.dominioatendimento.com/central/faces/solucao.html?codigo=6044',
                'Domínio — solução 8204':
                'https://suporte.dominioatendimento.com/central/faces/solucao.html?codigo=8204',
                'Domínio — solução 8406':
                'https://suporte.dominioatendimento.com/central/faces/solucao.html?codigo=8406',
              },
              onOpen: _open,
            ),

            const SizedBox(height: 20),

            // Como coletamos os dados
            const _SectionHeader('Como coletamos os dados'),
            const Text(
              'O calendário é montado a partir da leitura automatizada das páginas públicas da Agenda Tributária '
                  'da Receita Federal e, quando pertinente, de normas, portais de serviços e materiais de apoio oficiais. '
                  'As informações são organizadas localmente em formato de calendário e lista, e em cada obrigação é oferecido '
                  'um atalho para a página de origem, quando disponível.',
              textAlign: TextAlign.justify,
            ),

            const SizedBox(height: 16),

            // Observação sobre feriados
            const _SectionHeader('Observação sobre feriados'),
            const Text(
              'Feriados e pontos facultativos exibidos no app são uma conveniência visual e podem divergir de decretos, '
                  'portarias locais ou decisões posteriores. Sempre confirme, na fonte oficial, se o prazo se prorroga quando '
                  'recaí em dia não útil no seu município ou estado.',
              textAlign: TextAlign.justify,
            ),

            const SizedBox(height: 20),

            // IA do app
            const _SectionHeader('Assistente de IA do app'),
            const Text(
              'O app oferece um recurso de IA para ajudar a tirar dúvidas sobre prazos, termos e conceitos básicos, '
                  'usando como referência as mesmas fontes oficiais listadas nesta página. Para utilizar esse recurso, o usuário deve configurar ao menos uma chave de API em Ajustes > IA. '
                  'Esse recurso é um apoio para entender melhor o conteúdo, mas não é um canal oficial de nenhum órgão público.',
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 8),
            const Text(
              'As respostas da IA podem conter simplificações e não substituem:\n'
                  '• a consulta direta às páginas oficiais; e\n'
                  '• a análise de um profissional contábil ou jurídico habilitado.',
              textAlign: TextAlign.justify,
            ),

            const SizedBox(height: 24),

            // APIs & serviços de terceiros
            const _SectionHeader('APIs & serviços de terceiros'),
            const Text(
              'Além das fontes oficiais, o app pode utilizar serviços de terceiros configurados pelo próprio usuário para IA, conteúdo complementar e '
                  'compartilhamento. Esses serviços não têm vínculo com órgãos públicos.',
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 12),
            _LinkTile(
              icon: Icons.smart_toy_outlined,
              title: 'Serviços de IA configuráveis pelo usuário',
              subtitle:
              'O usuário pode cadastrar sua própria chave para OpenAI, Gemini e DeepSeek, definir a IA principal e usar as demais como secundárias.',
              links: const {
                'OpenAI — Chat Completions':
                'https://api.openai.com/v1/chat/completions',
                'Gemini API — gerar conteúdo':
                'https://ai.google.dev/gemini-api/docs',
                'DeepSeek API — chat completions':
                'https://api-docs.deepseek.com/api/create-chat-completion',
              },
              onOpen: _open,
            ),
            _LinkTile(
              icon: Icons.podcasts_outlined,
              title: 'Spotify — canais de podcast',
              subtitle:
              'A área de Podcast abre diretamente os canais no Spotify, sem consulta à API do serviço.',
              links: const {
                'Canal 1':
                'https://open.spotify.com/show/36pSkw1EtZgTnNrXmJcNPm',
                'Canal 2':
                'https://open.spotify.com/show/7iH3UWkTdoQ6OtYxsjJKut',
              },
              onOpen: _open,
            ),
            _LinkTile(
              icon: Icons.share_outlined,
              title: 'Compartilhamento e buscas rápidas',
              subtitle:
              'Acesso a compartilhamento via WhatsApp e a buscas rápidas em navegador.',
              links: const {
                'Compartilhamento via WhatsApp':
                'https://wa.me/?text=',
                'Busca no Google a partir de termo digitado':
                'https://www.google.com/search?q=',
              },
              onOpen: _open,
            ),

            const SizedBox(height: 24),

            // Bibliotecas & utilitários
            const _SectionHeader('Bibliotecas & utilitários'),
            _PkgTile(
              name: 'http',
              desc: 'Requisições HTTP para acessar as fontes públicas.',
              url: 'https://pub.dev/packages/http',
              onOpen: _open,
            ),
            _PkgTile(
              name: 'url_launcher',
              desc: 'Abertura de links oficiais em navegador ou apps externos.',
              url: 'https://pub.dev/packages/url_launcher',
              onOpen: _open,
            ),
            _PkgTile(
              name: 'share_plus',
              desc:
              'Compartilhamento nativo de textos e arquivos (por exemplo, CSV).',
              url: 'https://pub.dev/packages/share_plus',
              onOpen: _open,
            ),
            _PkgTile(
              name: 'path_provider',
              desc:
              'Acesso a diretórios temporários/externos para exportação de arquivos.',
              url: 'https://pub.dev/packages/path_provider',
              onOpen: _open,
            ),
            _PkgTile(
              name: 'intl',
              desc: 'Formatação de datas, números e moeda (pt_BR).',
              url: 'https://pub.dev/packages/intl',
              onOpen: _open,
            ),
            _PkgTile(
              name: 'shared_preferences',
              desc:
              'Armazenamento local de preferências (favoritos, ajustes).',
              url: 'https://pub.dev/packages/shared_preferences',
              onOpen: _open,
            ),
            _PkgTile(
              name: 'package_info_plus',
              desc: 'Informações de nome e versão do aplicativo.',
              url: 'https://pub.dev/packages/package_info_plus',
              onOpen: _open,
            ),

            const SizedBox(height: 28),

            // Créditos
            const _SectionHeader('Créditos'),
            const Text(
              'Este aplicativo agrega dados públicos para organizar obrigações, prazos e links de referência, '
                  'respeitando os termos de uso das fontes oficiais e sempre apontando para os canais originais. '
                  'Apesar do cuidado na leitura automática das páginas, podem ocorrer atrasos de atualização ou '
                  'divergências em relação às publicações oficiais.',
              textAlign: TextAlign.justify,
            ),

            const SizedBox(height: 28),

            Center(
              child: TextButton.icon(
                onPressed: () => _goCalendar(context),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Voltar para o calendário'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* =================== SUPORTE =================== */

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FonteOficial {
  final String titulo;
  final String url;
  const _FonteOficial({required this.titulo, required this.url});
}

class _FonteTile extends StatelessWidget {
  final _FonteOficial f;
  final void Function(String url) onOpen;
  const _FonteTile({required this.f, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.link),
        title: Text(f.titulo),
        subtitle: Text(
          f.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => onOpen(f.url),
        onLongPress: () => Clipboard.setData(ClipboardData(text: f.url)),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Map<String, String> links;
  final void Function(String url) onOpen;

  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.links,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final entries = links.entries.toList();
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 8),
            ...entries.map(
                  (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: const Icon(Icons.link, size: 18),
                title: Text(e.key),
                subtitle: Text(
                  e.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => onOpen(e.value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PkgTile extends StatelessWidget {
  final String name;
  final String desc;
  final String url;
  final void Function(String url) onOpen;

  const _PkgTile({
    required this.name,
    required this.desc,
    required this.url,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.extension_outlined),
      title: Text(name),
      subtitle: Text(desc),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => onOpen(url),
    );
  }
}