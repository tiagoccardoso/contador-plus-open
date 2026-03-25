import 'package:flutter/material.dart';

import '../../shared/whatsapp_share.dart';

import 'alep_campos_tab.dart';
import 'alep_deputados_tab.dart';
import 'alep_normas_tab.dart';
import 'alep_prestacao_contas_tab.dart';
import 'alep_proposicoes_tab.dart';
import 'alep_share_store.dart';

class DeputadosEstaduaisPrScreen extends StatefulWidget {
  const DeputadosEstaduaisPrScreen({super.key});

  @override
  State<DeputadosEstaduaisPrScreen> createState() => _DeputadosEstaduaisPrScreenState();
}

class _DeputadosEstaduaisPrScreenState extends State<DeputadosEstaduaisPrScreen> {
  String? _deputadoSelecionado;

  late final AlepShareStore _shareStore;

  @override
  void initState() {
    super.initState();
    _shareStore = AlepShareStore();
    _seedShareFallbacks();
  }

  void _seedShareFallbacks() {
    for (final key in AlepTabKey.values) {
      _shareStore.update(key, _fallbackMessageFor(key));
    }
  }

  void _selecionarDeputado(BuildContext context, String nome) {
    setState(() => _deputadoSelecionado = nome);

    // Atualiza shares com fallback da seleção atual (as abas substituem com dados reais depois).
    for (final key in AlepTabKey.values) {
      _shareStore.update(key, _fallbackMessageFor(key));
    }

    // UX: ao selecionar um deputado, pula direto para a próxima aba (Proposições).
    final controller = DefaultTabController.of(context);
    controller.animateTo(1);
  }

  String _fallbackMessageFor(AlepTabKey key) {
    final nome = _deputadoSelecionado;

    String header() => 'Deputados Estaduais — PR (ALEP)';

    // Links úteis (estáveis).
    const perfis = 'https://www.assembleia.pr.leg.br/deputados/conheca';
    const consultas = 'https://consultas.assembleia.pr.leg.br/';
    const apiPublica = 'https://webservices.assembleia.pr.leg.br/api/public';
    const transparencia = 'https://transparencia.assembleia.pr.leg.br/';

    final base = <String>[
      header(),
      if (nome != null && nome.trim().isNotEmpty) 'Selecionado: $nome',
      '',
    ];

    switch (key) {
      case AlepTabKey.deputados:
        return [
          ...base,
          'Lista/Perfis: $perfis',
          'Consultas: $consultas',
          'Fonte: ALEP',
        ].join('\n');

      case AlepTabKey.proposicoes:
        return [
          ...base,
          'Aba ativa: Proposições',
          if (nome == null || nome.trim().isEmpty) 'Dica: selecione um deputado na aba “Deputados”.',
          '',
          'Consultas (proposições): $consultas',
          'API pública: $apiPublica',
          'Fonte: ALEP',
        ].join('\n');

      case AlepTabKey.normas:
        return [
          ...base,
          'Aba ativa: Normas',
          if (nome == null || nome.trim().isEmpty) 'Dica: selecione um deputado na aba “Deputados”.',
          '',
          'Consultas (normas): $consultas',
          'API pública: $apiPublica',
          'Fonte: ALEP',
        ].join('\n');

      case AlepTabKey.prestacaoContas:
        return [
          ...base,
          'Aba ativa: Prestação de contas',
          if (nome == null || nome.trim().isEmpty) 'Dica: selecione um deputado na aba “Deputados”.',
          '',
          'Portal da Transparência: $transparencia',
          'API pública: $apiPublica',
          'Fonte: ALEP',
        ].join('\n');

      case AlepTabKey.campos:
        return [
          ...base,
          'Aba ativa: Campos (catálogo de filtros)',
          '',
          'API pública: $apiPublica',
          'Fonte: ALEP',
        ].join('\n');
    }
  }

  Future<void> _shareActiveTab(BuildContext context) async {
    final controller = DefaultTabController.of(context);
    final key = AlepTabKey.fromTabIndex(controller.index);

    // Preferência: texto preparado pela aba (com itens já carregados).
    // Fallback: um resumo estável e útil.
    final msg = _shareStore.textFor(key) ?? _fallbackMessageFor(key);
    await shareToWhatsApp(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Builder(
        builder: (ctx) {
          return AlepShareScope(
            notifier: _shareStore,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Deputados Estaduais - PR'),
                actions: [
                  IconButton(
                    tooltip: 'Compartilhar (aba ativa)',
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () => _shareActiveTab(ctx),
                  ),
                ],
                bottom: const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'Deputados', icon: Icon(Icons.people_alt_outlined)),
                    Tab(text: 'Proposições', icon: Icon(Icons.receipt_long_outlined)),
                    Tab(text: 'Normas', icon: Icon(Icons.gavel_outlined)),
                    Tab(text: 'Prestação de contas', icon: Icon(Icons.account_balance_wallet_outlined)),
                    Tab(text: 'Campos', icon: Icon(Icons.tune_outlined)),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  AlepDeputadosTab(
                    selectedDeputado: _deputadoSelecionado,
                    onSelectDeputado: (nome) => _selecionarDeputado(ctx, nome),
                  ),
                  AlepProposicoesTab(deputado: _deputadoSelecionado),
                  AlepNormasTab(deputado: _deputadoSelecionado),
                  AlepPrestacaoContasTab(deputado: _deputadoSelecionado),
                  const AlepCamposTab(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
