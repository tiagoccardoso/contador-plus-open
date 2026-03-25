import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/senado/cached_senado_api.dart';
import '../../shared/senado/senado_models.dart';
import '../../shared/whatsapp_share.dart';

class SenadoresScreen extends StatefulWidget {
  const SenadoresScreen({super.key});

  @override
  State<SenadoresScreen> createState() => _SenadoresScreenState();
}

class _SenadoresScreenState extends State<SenadoresScreen> {
  final _api = CachedSenadoApi();
  late Future<List<SenadorResumo>> _future;
  final _search = TextEditingController();

  // Mantém a última lista filtrada para o botão de compartilhar no AppBar.
  // (Evita depender do estado interno do FutureBuilder.)
  List<SenadorResumo> _lastFiltered = const <SenadorResumo>[];

  @override
  void initState() {
    super.initState();
    _future = _api.listarSenadoresEmExercicio();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Senadores'),
        actions: [
          IconButton(
            tooltip: 'Compartilhar no WhatsApp',
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              final filtro = _search.text.trim();
              final list = _lastFiltered;

              final lines = <String>[
                'Senadores em exercício (Senado Federal)',
                if (filtro.isNotEmpty) 'Filtro: $filtro',
                if (list.isNotEmpty) 'Total exibido: ${list.length}' else 'Lista: carregando…',
                '',
                if (list.isNotEmpty) ...[
                  'Senadores:',
                  ...list.take(30).map((s) {
                    final sub = _subtitle(s);
                    final tail = (sub == '—') ? '' : ' — $sub';
                    return '• ${s.nome}$tail';
                  }),
                  if (list.length > 30) '• … e mais ${list.length - 30}',
                  '',
                ],
                'Lista oficial: https://www25.senado.leg.br/web/senadores/em-exercicio',
              ];

              final msg = [
                ...lines,
              ].join('\n');
              shareToWhatsApp(context, msg);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nome, partido ou UF',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<SenadorResumo>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorBox(
                    message: 'Falha ao carregar senadores.\n\n${snap.error}',
                    onRetry: () => setState(() => _future = _api.listarSenadoresEmExercicio(ttl: Duration.zero)),
                  );
                }

                final all = snap.data ?? const <SenadorResumo>[];
                final filtered = q.isEmpty
                    ? all
                    : all.where((s) {
                        final blob = '${s.nome} ${s.partido ?? ''} ${s.uf ?? ''}'.toLowerCase();
                        return blob.contains(q);
                      }).toList();

                // Atualiza o snapshot mais recente para o botão de compartilhar.
                _lastFiltered = filtered;

                if (filtered.isEmpty) {
                  return const Center(child: Text('Nenhum senador encontrado.'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = filtered[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (s.fotoUrl != null && s.fotoUrl!.isNotEmpty)
                            ? NetworkImage(s.fotoUrl!)
                            : null,
                        child: (s.fotoUrl == null || s.fotoUrl!.isEmpty)
                            ? const Icon(Icons.person_outline)
                            : null,
                      ),
                      title: Text(s.nome),
                      subtitle: Text(_subtitle(s)),
                      onTap: () {
                        context.go(
                          '/senadores/${s.codigo}',
                          extra: s.toExtra(),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(SenadorResumo s) {
    final parts = <String>[];
    if (s.partido != null && s.partido!.isNotEmpty) parts.add(s.partido!);
    if (s.uf != null && s.uf!.isNotEmpty) parts.add(s.uf!);
    return parts.isEmpty ? '—' : parts.join(' • ');
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
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
