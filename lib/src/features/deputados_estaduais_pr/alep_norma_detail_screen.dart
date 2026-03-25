import 'package:flutter/material.dart';

import '../../shared/alep/alep_utils.dart';
import '../../shared/alep/cached_alep_api.dart';

class AlepNormaDetailScreen extends StatefulWidget {
  final int codigo;
  const AlepNormaDetailScreen({super.key, required this.codigo});

  @override
  State<AlepNormaDetailScreen> createState() => _AlepNormaDetailScreenState();
}

class _AlepNormaDetailScreenState extends State<AlepNormaDetailScreen> {
  final _api = CachedAlepApi();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.normaLegalDetalhe(widget.codigo);
  }

  void _retry() {
    setState(() {
      _future = _api.normaLegalDetalhe(widget.codigo, forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Norma #${widget.codigo}')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return _ErrorState(error: snap.error?.toString(), onRetry: _retry);
          }

          final root = snap.data!;
          final valor = (root['valor'] is Map) ? (root['valor'] as Map).cast<String, dynamic>() : root;

          final tipo = (valor['descricaoTipoNormaLegal'] ?? valor['tipo'] ?? '').toString().trim();
          final numero = valor['numero']?.toString() ?? '';
          final ano = valor['ano']?.toString() ?? '';
          final autores = (valor['autores'] ?? valor['autor'] ?? '').toString().trim();
          final assunto = (valor['assunto'] ?? '').toString().trim();
          final ementa = (valor['ementa'] ?? '').toString().trim();
          final palavras = (valor['palavraChave'] ?? '').toString().trim();

          final dt = AlepUtils.parseAlepDate(valor['data']?.toString());

          final movimentacoes = (valor['movimentacoes'] as List?)?.whereType<Map>().toList() ?? const [];
          final proposicoes = (valor['proposicoes'] as List?)?.whereType<Map>().toList() ?? const [];

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _HeaderCard(
                tipo: tipo,
                numero: numero,
                ano: ano,
                autores: autores,
                assunto: assunto,
                data: dt,
              ),
              const SizedBox(height: 12),
              if (ementa.isNotEmpty) _Section(title: 'Ementa', child: Text(ementa)),
              if (palavras.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Section(title: 'Palavras-chave', child: Text(palavras)),
              ],
              if (movimentacoes.isNotEmpty) ...[
                const SizedBox(height: 12),
                _MovimentacoesSection(items: movimentacoes),
              ],
              if (proposicoes.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Section(
                  title: 'Proposições relacionadas',
                  child: Column(
                    children: proposicoes.map((p) {
                      final num = p['numero']?.toString() ?? '';
                      final anoP = p['ano']?.toString() ?? '';
                      final autor = (p['autor'] ?? '').toString();
                      final tipoP = (p['tipoProposicao'] ?? '').toString();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text('$tipoP $num/$anoP'.trim()),
                        subtitle: Text(autor),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _Section(
                title: 'Dados técnicos',
                child: _KeyValueList(map: root),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String tipo;
  final String numero;
  final String ano;
  final String autores;
  final String assunto;
  final DateTime? data;

  const _HeaderCard({
    required this.tipo,
    required this.numero,
    required this.ano,
    required this.autores,
    required this.assunto,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final title = [tipo, if (numero.isNotEmpty) numero, if (ano.isNotEmpty) '/$ano'].join(' ').replaceAll(' /', '/');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.trim().isEmpty ? 'Norma Legal' : title.trim(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (autores.isNotEmpty) Chip(label: Text(autores)),
                if (assunto.isNotEmpty) Chip(label: Text(assunto)),
                if (data != null) Chip(label: Text(AlepUtils.formatDate(data))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyValueList extends StatelessWidget {
  final Map<String, dynamic> map;
  const _KeyValueList({required this.map});

  @override
  Widget build(BuildContext context) {
    final entries = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final rows = entries
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
        .toList(growable: false);

    if (rows.isEmpty) {
      return Text(
        'Sem campos simples para exibir.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Column(children: rows);
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

class _MovimentacoesSection extends StatelessWidget {
  final List<Map> items;
  const _MovimentacoesSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Movimentações',
      child: Column(
        children: items.map((m) {
          final tipo = (m['tipo'] ?? '').toString();
          final conc = (m['conclusao'] ?? '').toString();
          final data = AlepUtils.parseAlepDate(m['data']?.toString());
          final diario = (m['numeroDiarioOficial'] ?? '').toString();
          final obs = (m['observacao'] ?? '').toString();
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.timeline_outlined),
            title: Text([tipo, if (conc.isNotEmpty) '• $conc'].join(' ').trim()),
            subtitle: Text(
              [
                if (data != null) AlepUtils.formatDate(data),
                if (diario.isNotEmpty) 'Diário: $diario',
                if (obs.isNotEmpty) obs,
              ].join(' • '),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String? error;
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
              'Falha ao carregar a norma legal.\n\n${error ?? ''}',
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
