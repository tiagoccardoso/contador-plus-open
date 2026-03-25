import 'package:flutter/material.dart';

import '../../shared/alep/cached_alep_api.dart';

import 'alep_share_store.dart';

class _CampoItem {
  final String key;
  final dynamic value;
  const _CampoItem(this.key, this.value);

  int get count {
    final v = value;
    if (v is List) return v.length;
    if (v is Map) return v.length;
    return 0;
  }

  String preview() {
    final v = value;
    if (v is List) {
      if (v.isEmpty) return 'Sem valores';
      final first = v.first;
      if (first is Map) {
        final sigla = first['sigla']?.toString();
        final desc = first['descricao']?.toString();
        final nome = first['nome']?.toString();
        return [sigla, nome, desc].whereType<String>().where((s) => s.trim().isNotEmpty).take(1).join('');
      }
      return first.toString();
    }
    if (v is Map) return '${v.length} itens';
    return (v ?? '').toString();
  }
}

class AlepCamposTab extends StatefulWidget {
  const AlepCamposTab({super.key});

  @override
  State<AlepCamposTab> createState() => _AlepCamposTabState();
}

class _AlepCamposTabState extends State<AlepCamposTab> {
  final _api = CachedAlepApi();
  final _search = TextEditingController();

  late Future<_CamposBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<_CamposBundle> _load({bool forceRefresh = false}) async {
    final proposicao = await _api.proposicaoCampos(forceRefresh: forceRefresh);
    final norma = await _api.normaLegalCampos(forceRefresh: forceRefresh);
    return _CamposBundle(proposicaoCampos: proposicao, normaCampos: norma);
  }

  
  void _publishShare(BuildContext context, String text) {
    final store = AlepShareScope.maybeOf(context);
    if (store == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.update(AlepTabKey.campos, text);
    });
  }

@override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();

    return FutureBuilder<_CamposBundle>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          _publishShare(
            context,
            [
              'Campos (catálogo de filtros) — PR (ALEP)',
              '',
              'Carregando catálogos de filtros...',
              '',
              'API pública: https://webservices.assembleia.pr.leg.br/api/public',
              'Fonte: ALEP',
            ].join('\n'),
          );
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          _publishShare(
            context,
            [
              'Campos (catálogo de filtros) — PR (ALEP)',
              '',
              'Falha ao carregar catálogos de filtros.',
              'Erro: ${snap.error}',
              '',
              'API pública: https://webservices.assembleia.pr.leg.br/api/public',
              'Fonte: ALEP',
            ].join('\n'),
          );
          return _ErrorBox(
            title: 'Falha ao carregar campos',
            error: snap.error,
            onRetry: () => setState(() => _future = _load(forceRefresh: true)),
          );
        }

        final data = snap.data!;
        final proposicao = data.proposicaoCampos;
        final norma = data.normaCampos;

        final filtered = <_CampoItem>[];
        void addFiltered(String prefix, Map<String, dynamic> m) {
          for (final e in m.entries) {
            final key = '$prefix.${e.key}';
            final val = e.value;
            final s = '$key $val'.toLowerCase();
            if (q.isEmpty || s.contains(q)) {
              filtered.add(_CampoItem(key, val));
            }
          }
        }

        addFiltered('proposicao', proposicao);
        addFiltered('norma', norma);
        filtered.sort((a, b) => a.key.compareTo(b.key));

        _publishShare(
          context,
          [
            'Campos (catálogo de filtros) — PR (ALEP)',
            if (q.isNotEmpty) 'Filtro: "$q"',
            '',
            'Chaves proposição: ${proposicao.length}',
            'Chaves norma: ${norma.length}',
            'Itens exibidos: ${filtered.length}',
            '',
            'API pública: https://webservices.assembleia.pr.leg.br/api/public',
            'Fonte: ALEP',
          ].join('\n'),
        );

        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _future = _load(forceRefresh: true));
            await _future;
          },
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text(
                'Catálogo de filtros (ALEP)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  labelText: 'Buscar em campos/valores',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _StatRow(
                left: 'proposicao/campos: ${proposicao.length} chaves',
                right: 'norma-legal/campos: ${norma.length} chaves',
              ),
              const SizedBox(height: 12),
              Text('Resultado (${filtered.length})', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Toque em um item para ver os valores disponíveis (sem JSON bruto).',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              ...filtered.map(
                (it) => Card(
                  child: ListTile(
                    title: Text(it.key),
                    subtitle: Text(
                      it.count > 0 ? '${it.count} opções • Ex.: ${it.preview()}' : it.preview(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showCampoDetalhe(context, it),
                  ),
                ),
              ),
              const SizedBox(height: 64),
            ],
          ),
        );
      },
    );
  }

  void _showCampoDetalhe(BuildContext context, _CampoItem item) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final v = item.value;
        final List<Map<String, dynamic>> list = (v is List)
            ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
            : const <Map<String, dynamic>>[];

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.key, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (list.isEmpty)
                  Text(
                    (v ?? 'Sem dados').toString(),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final m = list[i];
                        final codigo = m['codigo']?.toString();
                        final sigla = m['sigla']?.toString();
                        final nome = m['nome']?.toString();
                        final desc = m['descricao']?.toString();

                        final titulo = [sigla, nome, desc]
                            .whereType<String>()
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();

                        return ListTile(
                          dense: true,
                          title: Text(titulo.isEmpty ? 'Opção ${i + 1}' : titulo.first),
                          subtitle: Text(
                            [
                              if (codigo != null && codigo.trim().isNotEmpty) 'Código: $codigo',
                              if (titulo.length > 1) titulo.sublist(1).join(' • '),
                            ].where((s) => s.trim().isNotEmpty).join('\n'),
                          ),
                          isThreeLine: true,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CamposBundle {
  final Map<String, dynamic> proposicaoCampos;
  final Map<String, dynamic> normaCampos;

  _CamposBundle({required this.proposicaoCampos, required this.normaCampos});
}

class _StatRow extends StatelessWidget {
  final String left;
  final String right;
  const _StatRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(left)),
        const SizedBox(width: 12),
        Expanded(child: Text(right, textAlign: TextAlign.right)),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String title;
  final Object? error;
  final VoidCallback onRetry;

  const _ErrorBox({required this.title, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(error?.toString() ?? 'Erro desconhecido', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
