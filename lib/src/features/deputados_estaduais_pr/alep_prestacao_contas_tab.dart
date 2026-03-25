import 'package:flutter/material.dart';

import '../../shared/alep/cached_alep_api.dart';
import '../../shared/open_link.dart';

import 'alep_share_store.dart';

class AlepPrestacaoContasTab extends StatefulWidget {
  final String? deputado;

  const AlepPrestacaoContasTab({super.key, required this.deputado});

  @override
  State<AlepPrestacaoContasTab> createState() => _AlepPrestacaoContasTabState();
}

class _AlepPrestacaoContasTabState extends State<AlepPrestacaoContasTab> {
  final _api = CachedAlepApi();
  int _ano = DateTime.now().year;
  late Future<Map<String, dynamic>> _future;

  static const int _anoMudancaCaptcha = 2020;

    static const _paths = <String>[
    // Esses caminhos variam ao longo do tempo no catálogo da ALEP; tentamos em cascata.
    '/prestacao-contas/filtrar',
    '/prestacao-contas/filtrar-por-parlamentar',
    '/prestacao-contas/filtrar-por-nome',
    '/prestacao-contas/parlamentar/filtrar',

    // Alguns catálogos publicam como “ressarcimento” / “verba de ressarcimento”.
    '/ressarcimento/filtrar',
    '/ressarcimento/parlamentar/filtrar',
    '/verba-ressarcimento/filtrar',
    '/verba-ressarcimento/parlamentar/filtrar',
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant AlepPrestacaoContasTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deputado != widget.deputado) {
      _future = _load(forceRefresh: true);
      setState(() {});
    }
  }

  Future<Map<String, dynamic>> _load({bool forceRefresh = false}) async {
    final dep = widget.deputado;
    if (dep == null || dep.trim().isEmpty) return <String, dynamic>{'lista': const <dynamic>[]};

    // ⚠️ Importante (e meio chato):
    // No Portal da Transparência, as verbas de ressarcimento "de 2020 até o presente"
    // são consultadas via um serviço que exige verificação (reCAPTCHA: “Não sou um robô”).
    // Isso significa que NÃO existe um endpoint público estável em /api/public para esse dado.
    // Resultado: tentar bater em /verba-ressarcimento/* ou similares dá 404.
    // Em vez de mostrar erro técnico, retornamos um payload indicando que o usuário deve abrir no portal.
    if (_ano >= _anoMudancaCaptcha) {
      return <String, dynamic>{
        'lista': const <dynamic>[],
        'requiresPortal': true,
        'portalUrl': 'https://consultas.assembleia.pr.leg.br/',
        'mensagem': 'A consulta de verbas de ressarcimento a partir de $_anoMudancaCaptcha exige verificação (\"Não sou um robô\").',
      };
    }

    final body = <String, dynamic>{
      'numeroMaximoRegistro': 100,
      // A API da ALEP varia bastante entre versões; enviamos aliases dos campos.
      'nome': dep,
      'parlamentar': dep,
      'parlamentarNome': dep,
      'nomeParlamentar': dep,

      'ano': _ano,
      'exercicio': _ano,
      'anoExercicio': _ano,
    };

    // Para anos anteriores a 2020, algumas páginas do Portal exibem o dado direto (sem captcha)
    // e/ou existiram endpoints antigos. Tentamos a cascata e, se não rolar, orientamos abrir o portal.
    Object? lastErr;
    for (final p in _paths) {
      try {
        return await _api.prestacaoContasFiltrar(p, body, forceRefresh: forceRefresh);
      } catch (e) {
        lastErr = e;
      }
    }

    return <String, dynamic>{
      'lista': const <dynamic>[],
      'requiresPortal': true,
      'portalUrl': 'https://transparencia.assembleia.pr.leg.br/receitas-e-despesas/verbas-de-ressarcimento',
      'mensagem': 'Não foi possível obter os registros automaticamente para $_ano.',
      'erro': lastErr?.toString(),
    };
  }

  List<Map<String, dynamic>> _asList(Map<String, dynamic> m) {
    final v = m['lista'] ?? m['data'] ?? m['items'] ?? m['dados'];
    if (v is List) return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return const [];
  }

  
  void _publishShare(BuildContext context, String text) {
    final store = AlepShareScope.maybeOf(context);
    if (store == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.update(AlepTabKey.prestacaoContas, text);
    });
  }

  double? _parseValor(dynamic v) {
    if (v == null) return null;
    var s = v.toString().trim();
    if (s.isEmpty) return null;

    // remove símbolos e espaços estranhos, mantendo números e separadores
    s = s.replaceAll(RegExp(r'[^0-9,\.\-]'), '');

    // heurística BR: 1.234,56 -> 1234.56
    if (s.contains(',') && s.contains('.')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (s.contains(',') && !s.contains('.')) {
      s = s.replaceAll(',', '.');
    }

    return double.tryParse(s);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deputado == null || widget.deputado!.trim().isEmpty) {
      _publishShare(
        context,
        [
          'Prestação de contas — PR (ALEP)',
          '',
          'Nenhum deputado selecionado.',
          'Dica: selecione um deputado na aba “Deputados”.',
          '',
          'Portal da Transparência: https://transparencia.assembleia.pr.leg.br/',
          'Fonte: ALEP',
        ].join('\n'),
      );
      return const Center(child: Text('Selecione um deputado na aba “Deputados”.'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Text('Ano:'),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _ano,
                items: List.generate(8, (i) => DateTime.now().year - i)
                    .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _ano = v;
                    _future = _load(forceRefresh: true);
                  });
                },
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Abrir no Portal da Transparência',
                icon: const Icon(Icons.open_in_new),
                onPressed: () {
                  final uri = Uri.parse('https://transparencia.assembleia.pr.leg.br/');
                  openExternal(uri);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 0),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                _publishShare(
                  context,
                  [
                    'Prestação de contas — PR (ALEP)',
                    'Deputado: ${widget.deputado}',
                    'Ano: $_ano',
                    '',
                    'Carregando registros...',
                    '',
                    'Portal da Transparência: https://transparencia.assembleia.pr.leg.br/',
                    'Fonte: ALEP',
                  ].join('\n'),
                );
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                _publishShare(
                  context,
                  [
                    'Prestação de contas — PR (ALEP)',
                    'Deputado: ${widget.deputado}',
                    'Ano: $_ano',
                    '',
                    'Não foi possível carregar pela API.',
                    'Você ainda pode acessar pelo Portal da Transparência.',
                    'Erro: ${snap.error}',
                    '',
                    'Portal da Transparência: https://transparencia.assembleia.pr.leg.br/',
                    'API pública: https://webservices.assembleia.pr.leg.br/api/public',
                    'Fonte: ALEP',
                  ].join('\n'),
                );
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Não foi possível carregar prestação de contas pela API.\n'
                      'Você ainda pode acessar pelo Portal da Transparência.\n\n'
                      '${snap.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final data = snap.data ?? const <String, dynamic>{};
              if (data['requiresPortal'] == true) {
                final msg = (data['mensagem'] ?? '').toString();
                final portalUrl = (data['portalUrl'] ?? 'https://transparencia.assembleia.pr.leg.br/').toString();
                final err = (data['erro'] ?? '').toString();

                _publishShare(
                  context,
                  [
                    'Prestação de contas — PR (ALEP)',
                    'Deputado: ${widget.deputado}',
                    'Ano: $_ano',
                    '',
                    msg.isEmpty ? 'Consulta disponível somente pelo portal.' : msg,
                    if (err.isNotEmpty) 'Detalhe: $err',
                    '',
                    'Abrir: $portalUrl',
                    'Fonte: ALEP',
                  ].join('\n'),
                );

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          msg.isEmpty
                              ? 'Consulta disponível somente pelo Portal da Transparência.'
                              : msg,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Abrir no portal'),
                          onPressed: () => openExternal(Uri.parse(portalUrl)),
                        ),
                        if (err.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            err,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              final list = _asList(data);

              if (list.isEmpty) {
                _publishShare(
                  context,
                  [
                    'Prestação de contas — PR (ALEP)',
                    'Deputado: ${widget.deputado}',
                    'Ano: $_ano',
                    '',
                    'Nenhum registro encontrado (no filtro atual).',
                    '',
                    'Portal da Transparência: https://transparencia.assembleia.pr.leg.br/',
                    'Fonte: ALEP',
                  ].join('\n'),
                );
                return const Center(child: Text('Nenhum registro encontrado.'));
              }

              double total = 0;
              int totalCount = 0;
              for (final e in list) {
                final v = _parseValor(e['valor']);
                if (v == null) continue;
                total += v;
                totalCount += 1;
              }

              final top = list.take(5).toList();

              String titleFor(Map<String, dynamic> e) {
                return (e['descricao'] ??
                        e['nome'] ??
                        e['historico'] ??
                        e['documento'] ??
                        e['id'] ??
                        'Item')
                    .toString();
              }

              String subtitleFor(Map<String, dynamic> e) {
                final parts = <String>[];
                for (final k in ['data', 'ano', 'valor', 'categoria', 'tipo']) {
                  final v = e[k];
                  if (v == null) continue;
                  final s = v.toString().trim();
                  if (s.isEmpty) continue;
                  parts.add(s);
                }
                return parts.join(' • ');
              }

              final shareLines = <String>[
                'Prestação de contas — PR (ALEP)',
                'Deputado: ${widget.deputado}',
                'Ano: $_ano',
                'Registros: ${list.length}',
              ];
              if (totalCount > 0) {
                // Em strings do Dart, "$" inicia interpolação. Para exibir o símbolo "R$",
                // precisamos escapar o caractere "$".
                shareLines.add('Soma (campo "valor"): R\$ ${total.toStringAsFixed(2)}');
              }
              shareLines.add('');

              for (final e in top) {
                final t = titleFor(e).replaceAll(RegExp(r'\s+'), ' ').trim();
                final s = subtitleFor(e).replaceAll(RegExp(r'\s+'), ' ').trim();
                final lineTitle = t.length <= 120 ? t : '${t.substring(0, 117)}...';
                final lineSub = s.length <= 140 ? s : '${s.substring(0, 137)}...';
                shareLines.add('- $lineTitle${lineSub.isEmpty ? '' : '\n  $lineSub'}');
              }

              if (list.length > top.length) {
                shareLines.add('... (+${list.length - top.length} itens)');
              }

              shareLines.add('');
              shareLines.add('Portal da Transparência: https://transparencia.assembleia.pr.leg.br/');
              shareLines.add('Fonte: ALEP');

              _publishShare(context, shareLines.join('\n'));

              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (context, i) {
                  final e = list[i];
                  return ListTile(
                    title: Text(titleFor(e), maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(subtitleFor(e), maxLines: 2, overflow: TextOverflow.ellipsis),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
