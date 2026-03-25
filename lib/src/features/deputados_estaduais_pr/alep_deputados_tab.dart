import 'package:flutter/material.dart';

import '../../shared/alep/cached_alep_api.dart';

import 'alep_share_store.dart';

/// Slug simples para montar URL do perfil no site da ALEP.
/// (O site usa algo bem próximo disso; quando não bater, ainda assim o link abre uma página útil.)
String slugifyNome(String nome) {
  final s = nome.trim().toLowerCase();
  const map = {
    'á': 'a','à': 'a','â': 'a','ã': 'a','ä': 'a',
    'é': 'e','ê': 'e','è': 'e','ë': 'e',
    'í': 'i','ì': 'i','î': 'i','ï': 'i',
    'ó': 'o','ò': 'o','ô': 'o','õ': 'o','ö': 'o',
    'ú': 'u','ù': 'u','û': 'u','ü': 'u',
    'ç': 'c',
  };

  final buf = StringBuffer();
  for (final ch in s.split('')) {
    buf.write(map[ch] ?? ch);
  }
  final cleaned = buf.toString().replaceAll(RegExp(r'[^a-z0-9\s-]'), '');
  return cleaned.trim().replaceAll(RegExp(r'\s+'), '-').replaceAll(RegExp(r'-+'), '-');
}

class AlepDeputadosTab extends StatefulWidget {
  final String? selectedDeputado;
  final ValueChanged<String> onSelectDeputado;

  const AlepDeputadosTab({
    super.key,
    required this.selectedDeputado,
    required this.onSelectDeputado,
  });

  @override
  State<AlepDeputadosTab> createState() => _AlepDeputadosTabState();
}

class _AlepDeputadosTabState extends State<AlepDeputadosTab> {
  final _api = CachedAlepApi();
  final _search = TextEditingController();
  late Future<List<String>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAutores();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<String>> _loadAutores({bool forceRefresh = false}) async {
    // ⚠️ IMPORTANTE:
    // /proposicao/campos retorna "autores" e mistura parlamentares com órgãos/entidades.
    // Para a aba Deputados, usamos o Portal da Transparência (scrape) via CachedAlepApi.
    final resp = await _api.deputadosEstaduaisPr(forceRefresh: forceRefresh);
    final lista = (resp['lista'] as List? ?? const [])
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();

    lista.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return lista;
  }

  
  void _publishShare(BuildContext context, String text) {
    final store = AlepShareScope.maybeOf(context);
    if (store == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.update(AlepTabKey.deputados, text);
    });
  }

@override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: 'Buscar deputado',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar',
                      icon: const Icon(Icons.clear),
                      onPressed: () => _search.clear(),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<String>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                _publishShare(
                  context,
                  [
                    'Deputados Estaduais — PR (ALEP)',
                    if ((widget.selectedDeputado ?? '').trim().isNotEmpty) 'Selecionado: ${widget.selectedDeputado}',
                    if (q.isNotEmpty) 'Filtro: "$q"',
                    '',
                    'Carregando lista de deputados...',
                    '',
                    'Lista/Perfis: https://www.assembleia.pr.leg.br/deputados/conheca',
                    'Fonte: ALEP',
                  ].join('\n'),
                );
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                _publishShare(
                  context,
                  [
                    'Deputados Estaduais — PR (ALEP)',
                    if ((widget.selectedDeputado ?? '').trim().isNotEmpty) 'Selecionado: ${widget.selectedDeputado}',
                    if (q.isNotEmpty) 'Filtro: "$q"',
                    '',
                    'Falha ao carregar lista de deputados pela API.',
                    'Erro: ${snap.error}',
                    '',
                    'Lista/Perfis: https://www.assembleia.pr.leg.br/deputados/conheca',
                    'Fonte: ALEP',
                  ].join('\n'),
                );
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Falha ao carregar lista de deputados.\n${snap.error}'),
                  ),
                );
              }
              final all = snap.data ?? const <String>[];
              final filtered = q.isEmpty ? all : all.where((n) => n.toLowerCase().contains(q)).toList();

              final selected = (widget.selectedDeputado ?? '').trim();
              final slug = selected.isEmpty ? null : slugifyNome(selected);
              final perfilUrl = (slug == null || slug.isEmpty)
                  ? null
                  : 'https://www.assembleia.pr.leg.br/deputados/$slug';

              _publishShare(
                context,
                [
                  'Deputados Estaduais — PR (ALEP)',
                  if (selected.isNotEmpty) 'Selecionado: $selected',
                  if (q.isNotEmpty) 'Filtro: "$q"',
                  '',
                  'Total no catálogo: ${all.length}',
                  if (q.isNotEmpty) 'Encontrados: ${filtered.length}',
                  '',
                  'Lista/Perfis: https://www.assembleia.pr.leg.br/deputados/conheca',
                  if (perfilUrl != null) 'Perfil (site): $perfilUrl',
                  'Fonte: ALEP',
                ].join('\n'),
              );

              if (filtered.isEmpty) {
                return const Center(child: Text('Nenhum deputado encontrado.'));
              }

              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (context, i) {
                  final nome = filtered[i];
                  final isSelected = (widget.selectedDeputado ?? '') == nome;
                  return ListTile(
                    title: Text(nome),
                    leading: isSelected ? const Icon(Icons.check_circle_outline) : const Icon(Icons.person_outline),
                    onTap: () => widget.onSelectDeputado(nome),
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
