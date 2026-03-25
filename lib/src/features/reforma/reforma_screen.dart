import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class ReformaTributariaScreen extends StatelessWidget {
  const ReformaTributariaScreen({super.key});

  static const _links = <_LinkItem>[
    const _LinkItem(
      'Ministério da Fazenda – Regulamentação da Reforma Tributária',
      'https://www.gov.br/fazenda/pt-br/acesso-a-informacao/acoes-e-programas/reforma-tributaria',
      Icons.account_balance_outlined,
    ),
    const _LinkItem(
      'Ministério da Fazenda – Portal Reforma Tributária',
      'https://www.gov.br/fazenda/pt-br/acesso-a-informacao/acoes-e-programas/futuro-seguro/reforma-tributaria',
      Icons.public_outlined,
    ),
    const _LinkItem(
      'Receita Federal – Programa Reforma do Consumo',
      'https://www.gov.br/receitafederal/pt-br/acesso-a-informacao/acoes-e-programas/programas-e-atividades/reforma-consumo',
      Icons.account_tree_outlined,
    ),
    const _LinkItem(
      'Receita Federal – Entenda a Reforma do Consumo',
      'https://www.gov.br/receitafederal/pt-br/acesso-a-informacao/acoes-e-programas/programas-e-atividades/reforma-consumo/entenda',
      Icons.menu_book_outlined,
    ),
    const _LinkItem(
      'Planalto – Emenda Constitucional 132/2023 (texto oficial)',
      'https://www.planalto.gov.br/ccivil_03/constituicao/emendas/emc/emc132.htm',
      Icons.gavel_outlined,
    ),
    const _LinkItem(
      'Planalto – Lei Complementar 214/2025 (regulamentação)',
      'https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp214.htm',
      Icons.description_outlined,
    ),
    const _LinkItem(
      'Senado – PLP 68/2024 (página oficial)',
      'https://www25.senado.leg.br/web/atividade/materias/-/materia/164914',
      Icons.how_to_vote_outlined,
    ),
    const _LinkItem(
      'Câmara – PLP 68/2024 (tramitação e inteiro teor)',
      'https://www.camara.leg.br/proposicoesWeb/fichadetramitacao?idProposicao=2430143',
      Icons.receipt_long_outlined,
    ),
    const _LinkItem(
      'Câmara – Regulamentação sancionada (notícia explicativa)',
      'https://www.camara.leg.br/noticias/1127237-regulamentacao-da-reforma-tributaria-e-sancionada-conheca-a-nova-lei/',
      Icons.newspaper_outlined,
    ),
    const _LinkItem(
      'Senado – explicadores e cronograma de transição',
      'https://www12.senado.leg.br/noticias/materias/2024/12/16/novos-tributos-comecam-a-ser-testados-em-2026-e-transicao-vai-ate-2033',
      Icons.timeline_outlined,
    ),
    const _LinkItem(
      'Domínio Sistemas – Central de Soluções (hub)',
      'https://suporte.dominioatendimento.com/central/faces/central-solucoes.html',
      Icons.support_agent_outlined,
    ),
    const _LinkItem(
      'Domínio Sistemas – Módulo Reforma Tributária',
      'https://suporte.dominioatendimento.com/central/faces/solucao.html?codigo=11962',
      Icons.school_outlined,
    ),
  ];

  Future<void> _abrir(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reforma Tributária'), actions: [IconButton(icon: const Icon(Icons.timeline_outlined), onPressed: ()=>context.go('/reforma/timeline'))]),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: () => context.go('/learning'),
              icon: const Icon(Icons.smart_toy_outlined),
              label: const Text('Pergunte a IA sobre a Reforma Tributária'),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.timeline_outlined),
            title: const Text('Linha do tempo'),
            subtitle: const Text('Acompanhe marcos, vigência e regulamentações'),
            onTap: () => context.go('/reforma/timeline'),
          ),
          const Divider(height: 24),
          for (final item in _links)
            ListTile(
              leading: Icon(item.icon),
              title: Text(item.title),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _abrir(item.url, context),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _LinkItem {
  final String title;
  final String url;
  final IconData icon;
  const _LinkItem(this.title, this.url, this.icon);
}
