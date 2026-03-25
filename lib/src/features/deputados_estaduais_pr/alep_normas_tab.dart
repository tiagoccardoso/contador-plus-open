import 'package:flutter/material.dart';

import '../../shared/alep/cached_alep_api.dart';
import '../../shared/open_link.dart';

import 'alep_share_store.dart';

class AlepNormasTab extends StatefulWidget {
  final String? deputado;

  const AlepNormasTab({super.key, required this.deputado});

  @override
  State<AlepNormasTab> createState() => _AlepNormasTabState();
}

class _AlepNormasTabState extends State<AlepNormasTab> {
  final _api = CachedAlepApi();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant AlepNormasTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deputado != widget.deputado) {
      _future = _load(forceRefresh: true);
      setState(() {});
    }
  }

  Future<Map<String, dynamic>> _load({bool forceRefresh = false}) async {
    final dep = widget.deputado;
    if (dep == null || dep.trim().isEmpty) return <String, dynamic>{'lista': const <dynamic>[]};

    final body = <String, dynamic>{
      'numeroMaximoRegistro': 100,
      'autor': dep,
    };
    return _api.normaLegalFiltrar(body, forceRefresh: forceRefresh);
  }

  List<Map<String, dynamic>> _asList(Map<String, dynamic> m) {
    final v = m['lista'] ?? m['data'] ?? m['items'];
    if (v is List) return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return const [];
  }

  
  void _publishShare(BuildContext context, String text) {
    final store = AlepShareScope.maybeOf(context);
    if (store == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.update(AlepTabKey.normas, text);
    });
  }

@override
  Widget build(BuildContext context) {
    if (widget.deputado == null || widget.deputado!.trim().isEmpty) {
      _publishShare(
        context,
        [
          'Normas — PR (ALEP)',
          '',
          'Nenhum deputado selecionado.',
          'Dica: selecione um deputado na aba “Deputados”.',
          '',
          'Consultas: https://consultas.assembleia.pr.leg.br/',
          'Fonte: ALEP',
        ].join('\n'),
      );
      return const Center(child: Text('Selecione um deputado na aba “Deputados”.'));
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          _publishShare(
            context,
            [
              'Normas — PR (ALEP)',
              'Deputado: ${widget.deputado}',
              '',
              'Carregando normas...',
              '',
              'Consultas: https://consultas.assembleia.pr.leg.br/',
              'Fonte: ALEP',
            ].join('\n'),
          );
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          _publishShare(
            context,
            [
              'Normas — PR (ALEP)',
              'Deputado: ${widget.deputado}',
              '',
              'Falha ao carregar normas pela API.',
              'Erro: ${snap.error}',
              '',
              'Consultas: https://consultas.assembleia.pr.leg.br/',
              'API pública: https://webservices.assembleia.pr.leg.br/api/public',
              'Fonte: ALEP',
            ].join('\n'),
          );
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Falha ao carregar normas.\n${snap.error}'),
            ),
          );
        }

        final list = _asList(snap.data ?? const <String, dynamic>{});

        if (list.isEmpty) {
          _publishShare(
            context,
            [
              'Normas — PR (ALEP)',
              'Deputado: ${widget.deputado}',
              '',
              'Nenhuma norma encontrada (no filtro atual).',
              '',
              'Consultas: https://consultas.assembleia.pr.leg.br/',
              'Fonte: ALEP',
            ].join('\n'),
          );
          return const Center(child: Text('Nenhuma norma encontrada.'));
        }

        String oneLine(Map<String, dynamic> e) {
          final tipo = (e['descricaoTipoNormaLegal'] ?? '').toString().trim();
          final numero = (e['numero'] ?? '').toString().trim();
          final ano = (e['ano'] ?? '').toString().trim();
          final base = [
            tipo,
            if (numero.isNotEmpty && ano.isNotEmpty) '$numero/$ano' else numero,
          ].where((s) => s.trim().isNotEmpty).join(' ');
          final titulo = (e['ementa'] ?? e['assunto'] ?? '').toString().replaceAll(RegExp(r'\s+'), ' ').trim();
          final shortTitle = titulo.length <= 120 ? titulo : '${titulo.substring(0, 117)}...';
          return [base, shortTitle].where((s) => s.trim().isNotEmpty).join(' — ');
        }

        String link(Map<String, dynamic> e) {
          final codigo = e['codigo']?.toString().trim();
          if (codigo == null || codigo.isEmpty) return '';
          return 'https://consultas.assembleia.pr.leg.br/#/norma/$codigo';
        }

        final top = list.take(5).toList();

        _publishShare(
          context,
          [
            'Normas — PR (ALEP)',
            'Deputado: ${widget.deputado}',
            'Registros: ${list.length}',
            '',
            ...top.map((e) {
              final l = oneLine(e);
              final u = link(e);
              if (u.isEmpty) return '- $l';
              return '- $l\n  $u';
            }),
            if (list.length > top.length) '... (+${list.length - top.length} itens)',
            '',
            'Consultas: https://consultas.assembleia.pr.leg.br/',
            'Fonte: ALEP',
          ].join('\n'),
        );

        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (context, i) {
            final e = list[i];
            final codigo = e['codigo']?.toString();
            final titulo = (e['ementa'] ?? e['assunto'] ?? e['descricaoTipoNormaLegal'] ?? 'Norma').toString();
            final subt = [
              e['descricaoTipoNormaLegal']?.toString(),
              e['numero']?.toString(),
              e['ano']?.toString(),
              e['conclusaoMovimentacao']?.toString(),
            ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' • ');

            return ListTile(
              title: Text(titulo, maxLines: 3, overflow: TextOverflow.ellipsis),
              subtitle: subt.isEmpty ? null : Text(subt, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.open_in_new),
              onTap: codigo == null
                  ? null
                  : () {
                      final uri = Uri.parse('https://consultas.assembleia.pr.leg.br/#/norma/$codigo');
                      openExternal(uri);
                    },
            );
          },
        );
      },
    );
  }
}
