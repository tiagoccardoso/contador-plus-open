import 'package:flutter/material.dart';

import '../../shared/alep/alep_utils.dart';
import '../../shared/alep/cached_alep_api.dart';

class AlepProposicaoDetailScreen extends StatefulWidget {
  final int codigo;
  const AlepProposicaoDetailScreen({super.key, required this.codigo});

  @override
  State<AlepProposicaoDetailScreen> createState() => _AlepProposicaoDetailScreenState();
}

class _AlepProposicaoDetailScreenState extends State<AlepProposicaoDetailScreen> {
  final _api = CachedAlepApi();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.proposicaoDetalhe(widget.codigo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Proposição #${widget.codigo}')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorState(
              error: snap.error,
              onRetry: () => setState(() => _future = _api.proposicaoDetalhe(widget.codigo, forceRefresh: true)),
            );
          }

          final data = snap.data ?? const {};
          final valor = (data['valor'] is Map) ? Map<String, dynamic>.from(data['valor'] as Map) : data;

          final tipo = valor['tipoProposicao']?.toString() ?? valor['siglaTipoProposicao']?.toString() ?? '';
          final numero = valor['numero']?.toString() ?? '';
          final ano = valor['ano']?.toString() ?? '';
          final autor = valor['autor']?.toString() ?? '';
          final assunto = valor['assunto']?.toString() ?? '';
          final status = valor['status']?.toString() ?? '';
          final ementa = valor['ementa']?.toString() ?? '';

          final dtReceb = AlepUtils.parseAlepDate(valor['dataRecebimento']?.toString());
          final dtEntrada = AlepUtils.parseAlepDate(valor['dataEntrada']?.toString());

          final tramites = (valor['tramites'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          final normas = (valor['normasLegais'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _HeaderCard(
                title: [tipo, if (numero.isNotEmpty) numero, if (ano.isNotEmpty) '/$ano'].join(' '),
                subtitle: [
                  if (autor.isNotEmpty) 'Autor: $autor',
                  if (status.isNotEmpty) 'Status: $status',
                  if (assunto.isNotEmpty) 'Assunto: $assunto',
                ].join(' • '),
              ),
              if (ementa.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Section(title: 'Ementa', child: Text(ementa)),
              ],
              const SizedBox(height: 12),
              _Section(
                title: 'Datas',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (dtEntrada != null) Chip(label: Text('Entrada: ${AlepUtils.formatDate(dtEntrada)}')),
                    if (dtReceb != null) Chip(label: Text('Recebimento: ${AlepUtils.formatDate(dtReceb)}')),
                  ],
                ),
              ),
              if (normas.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Section(
                  title: 'Normas legais relacionadas',
                  child: Column(
                    children: normas.map((n) {
                      final t = (n['descricaoTipoNormaLegal'] ?? n['tipo'] ?? '').toString();
                      final num = n['numero']?.toString() ?? '';
                      final anoN = n['ano']?.toString() ?? '';
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.gavel_outlined),
                        title: Text([t, num, if (anoN.isNotEmpty) '/$anoN'].where((e) => e.toString().trim().isNotEmpty).join(' ')),
                        subtitle: Text((n['ementa'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                  ),
                ),
              ],
              if (tramites.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Section(
                  title: 'Tramites',
                  child: Column(
                    children: tramites.map((t) {
                      final local = t['local']?.toString() ?? '';
                      final dt = AlepUtils.parseAlepDate(t['data']?.toString());
                      final acoes = (t['acoes'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(local, style: Theme.of(context).textTheme.titleSmall),
                              if (dt != null) Text(AlepUtils.formatDate(dt), style: Theme.of(context).textTheme.bodySmall),
                              if (acoes.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ...acoes.map((a) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('• '),
                                          Expanded(child: Text(a['descricao']?.toString() ?? '')),
                                        ],
                                      ),
                                    )),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _Section(
                title: 'Dados técnicos',
                child: _KeyValueList(map: data),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KeyValueList extends StatelessWidget {
  final Map<String, dynamic> map;
  const _KeyValueList({required this.map});

  @override
  Widget build(BuildContext context) {
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      children: entries
          .where((e) => e.value is! List && e.value is! Map)
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      e.key,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: Text(e.value?.toString() ?? ''),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const _HeaderCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              'Falha ao carregar a proposição.\n\n${error ?? ''}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
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
